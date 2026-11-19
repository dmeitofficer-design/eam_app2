// lib/features/purchases/presentation/widgets/purchase_widgets.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../clients/data/models/hospital_client.dart';
import '../../../clients/data/repositories/clients_repository.dart';
import '../../../machines/data/models/installed_machine.dart';
import '../../../machines/data/repositories/machines_repository.dart';
import '../../data/models/purchase_bill.dart';

final _taka = NumberFormat.decimalPattern('en_IN');
final _date = DateFormat('d MMM yyyy');

/// "Tk 1,10,500" (lakh grouping, as on the bills).
String formatTaka(num v) => 'Tk ${_taka.format(v)}';
String formatBillDate(DateTime d) => _date.format(d);

/// Warranty status of a bill line: "Until 26 Sep 2029", "Expired", "Lifetime", "No warranty".
class WarrantyPill extends StatelessWidget {
  const WarrantyPill({super.key, required this.item});
  final PurchaseItem item;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (item.warrantyState) {
      WarrantyState.active => ('Until ${formatBillDate(item.warrantyUntil!)}', AppColors.success),
      WarrantyState.expired => ('Expired ${formatBillDate(item.warrantyUntil!)}', AppColors.error),
      WarrantyState.lifetime => ('Lifetime warranty', AppColors.success),
      WarrantyState.none => ('No warranty', AppColors.textTertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// What the machine picker returns: a machine, or "unlink" (machine == null).
typedef MachinePick = ({String? machineId, String? label});

/// Bottom sheet: pick a client, then one of its machines.
/// Returns null when dismissed. [allowUnlink] adds an "Unlink" action.
Future<MachinePick?> showMachinePicker(
  BuildContext context, {
  required String title,
  bool allowUnlink = false,
}) {
  return showModalBottomSheet<MachinePick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (sheetContext, scroll) => _MachinePicker(
        title: title,
        allowUnlink: allowUnlink,
        scroll: scroll,
        clients: context.read<ClientsRepository>(),
        machines: context.read<MachinesRepository>(),
      ),
    ),
  );
}

class _MachinePicker extends StatefulWidget {
  const _MachinePicker({
    required this.title,
    required this.allowUnlink,
    required this.scroll,
    required this.clients,
    required this.machines,
  });

  final String title;
  final bool allowUnlink;
  final ScrollController scroll;
  final ClientsRepository clients;
  final MachinesRepository machines;

  @override
  State<_MachinePicker> createState() => _MachinePickerState();
}

class _MachinePickerState extends State<_MachinePicker> {
  List<HospitalClient>? _clients;
  HospitalClient? _client;
  List<InstalledMachine>? _machineList;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _error = null);
    try {
      final clients = await widget.clients.getClients();
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorFormatter.format(e));
    }
  }

  Future<void> _openClient(HospitalClient client) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _client = client;
      _machineList = null;
      _error = null;
    });
    try {
      final machines = await widget.machines.getMachinesByHospital(client.id);
      if (mounted && _client == client) setState(() => _machineList = machines);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorFormatter.format(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = _client;
    final q = _query.trim().toLowerCase();
    final clients = (_clients ?? [])
        .where((c) => q.isEmpty || '${c.name} ${c.district}'.toLowerCase().contains(q))
        .toList();

    Widget body;
    if (_error != null) {
      body = Center(child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)));
    } else if (client == null && _clients == null || client != null && _machineList == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (client == null) {
      body = clients.isEmpty
          ? Center(child: Text('No clients match "$_query".', style: theme.textTheme.bodyMedium))
          : ListView.builder(
              controller: widget.scroll,
              itemCount: clients.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.local_hospital_rounded),
                title: Text(clients[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [clients[i].district, clients[i].division.label].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openClient(clients[i]),
              ),
            );
    } else if (_machineList!.isEmpty) {
      body = Center(child: Text('${client.name} has no machines yet.', style: theme.textTheme.bodyMedium));
    } else {
      body = ListView.builder(
        controller: widget.scroll,
        itemCount: _machineList!.length,
        itemBuilder: (_, i) {
          final m = _machineList![i];
          return ListTile(
            leading: const Icon(Icons.precision_manufacturing_rounded),
            title: Text('${m.brand} ${m.model}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [m.machineType.label, if (m.serialNumber?.isNotEmpty ?? false) 'S/N ${m.serialNumber}',
                'Installed ${formatBillDate(m.installationDate)}',].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop<MachinePick>(context,
                  (machineId: m.id, label: '${client.name} · ${m.brand} ${m.model}'),);
            },
          );
        },
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: AppColors.surface3, borderRadius: AppRadius.chip),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            children: [
              if (client != null)
                IconButton(
                  tooltip: 'Back to clients',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() {
                    _client = null;
                    _error = null;
                  }),
                )
              else
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  client?.name ?? widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.allowUnlink && client == null)
                TextButton.icon(
                  onPressed: () => Navigator.pop<MachinePick>(context, (machineId: null, label: null)),
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Unlink'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: Text(
            client == null ? 'Choose the client, then the machine.' : 'Choose the machine.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (client == null && _clients != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search clients…',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(child: body),
      ],
    );
  }
}
