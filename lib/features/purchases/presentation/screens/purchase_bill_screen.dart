// lib/features/purchases/presentation/screens/purchase_bill_screen.dart
//
// One vendor bill: items, warranty, serials, and linking serials to
// the client machines they went into.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../shared/widgets/updated_by_label.dart';
import '../../../approvals/data/repositories/approvals_repository.dart';
import '../../../approvals/presentation/delete_or_request.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/bill_draft.dart';
import '../../data/models/purchase_bill.dart';
import '../../data/repositories/purchases_repository.dart';
import '../widgets/purchase_widgets.dart';
import 'add_bill_page.dart';

class PurchaseBillScreen extends StatefulWidget {
  const PurchaseBillScreen({super.key, required this.billId, this.initial});
  final String billId;

  /// Already-loaded bill from the list, so the page opens instantly.
  final PurchaseBill? initial;

  @override
  State<PurchaseBillScreen> createState() => _PurchaseBillScreenState();
}

class _PurchaseBillScreenState extends State<PurchaseBillScreen> {
  late PurchaseBill? _bill = widget.initial;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bill = await context.read<PurchasesRepository>().getBill(widget.billId);
      if (mounted) {
        setState(() {
        _bill = bill;
        _error = null;
      });
      }
    } catch (e) {
      if (!mounted) return;
      if (_bill == null) {
        setState(() => _error = e.toString());
      } else {
        AppFeedback.error(context, ErrorFormatter.format(e));
      }
    }
  }

  Future<void> _link(List<PurchaseSerial> serials, {required String title, bool allowUnlink = false}) async {
    final pick = await showMachinePicker(context, title: title, allowUnlink: allowUnlink);
    if (pick == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<PurchasesRepository>().assignSerials(
            serials.map((s) => s.id).toList(),
            pick.machineId,
          );
      await _load();
      if (!mounted) return;
      final n = serials.length == 1 ? serials.single.serialNo : '${serials.length} parts';
      AppFeedback.success(context, pick.machineId == null ? 'Unlinked $n.' : 'Linked $n to ${pick.label}.');
    } catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.mediumImpact());
        AppFeedback.error(context, ErrorFormatter.format(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit() async {
    final bill = _bill;
    if (bill == null) return;
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AddBillPage(
          editBillId: bill.id,
          sourceLabel: bill.displayNo,
          prefill: Future.value(BillPrefill(draft: BillDraft.fromBill(bill))),
        ),
      ),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _delete() async {
    final bill = _bill;
    if (bill == null) return;
    final deleted = await deleteOrRequest(
      context,
      target: DeletionTarget.purchaseBill,
      id: bill.id,
      label: bill.displayNo,
      link: '/purchases/${bill.id}',
      consequence: 'This deletes ${bill.displayNo} with its items and serials. '
          'Parts linked to machines are unlinked.',
      deleteNow: () => context.read<PurchasesRepository>().deleteBill(bill.id),
    );
    if (deleted && mounted) {
      AppFeedback.success(context, '${bill.displayNo} moved to the Trash.');
      context.pop();
    }
  }

  /// Multi-set bills: tick one set's parts (prefilled), then pick its machine.
  Future<void> _linkSet() async {
    final bill = _bill!;
    final chosen = await showModalBottomSheet<List<PurchaseSerial>>(
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
        builder: (_, scroll) => _SetPicker(bill: bill, scroll: scroll),
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    await _link(chosen, title: 'Link this set (${chosen.length} parts) to…');
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final unlinked = bill?.serials.where((s) => s.machineId == null).toList() ?? const [];
    final auth = context.watch<AuthBloc>().state;
    final profile = auth is AuthAuthenticated ? auth.profile : null;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: Text(bill == null ? 'Bill' : bill.displayNo, overflow: TextOverflow.ellipsis),
        actions: [
          if (bill != null && (profile?.canManagePurchases ?? false))
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit bill',
              onPressed: _saving ? null : _edit,
            ),
          // Super admins delete; admins send a deletion request.
          if (bill != null && (profile?.isAdmin ?? false))
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              tooltip: 'Delete bill',
              color: AppColors.error,
              onPressed: _saving ? null : _delete,
            ),
        ],
        bottom: _saving
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _error != null
          ? ErrorStateWidget(rawError: _error!, onRetry: () {
              setState(() => _error = null);
              _load();
            },)
          : bill == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface1,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SummaryCard(bill: bill),
                            if (unlinked.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : bill.setCount > 1
                                        ? _linkSet
                                        : () => _link(unlinked, title: 'Link ${unlinked.length} unlinked parts to…'),
                                icon: const Icon(Icons.link_rounded, size: 18),
                                label: Text(
                                  bill.setCount > 1
                                      ? 'Link one set to a machine (${bill.setCount} sets on this bill)'
                                      : 'Link all ${unlinked.length} unlinked parts to a machine',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            _ItemsCard(
                              bill: bill,
                              enabled: !_saving,
                              onLink: (s) => _link(
                                [s],
                                title: 'Link ${s.serialNo} to…',
                                allowUnlink: s.machineId != null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.bill});
  final PurchaseBill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(label, style: theme.textTheme.bodySmall)),
              Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary))),
            ],
          ),
        );

    return _Card(
      header: 'BILL',
      children: [
        Text(formatTaka(bill.total), style: theme.textTheme.headlineMedium),
        if (bill.netPaid != null)
          Text('Paid ${formatTaka(bill.netPaid!)} after returns/discount',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),),
        const SizedBox(height: AppSpacing.md),
        row('Vendor', bill.vendor),
        if (bill.dmeNo != null) row('Bill ID', bill.dmeNo!),
        row('Seller bill no', bill.billNo),
        row('Date', formatBillDate(bill.billDate)),
        if (bill.paymentType != null) row('Payment', bill.paymentType!),
        if (bill.soldBy != null) row('Sold by', bill.soldBy!),
        if (bill.sourcePage != null) row('Scan', 'Page ${bill.sourcePage} of the bills PDF'),
        if (bill.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(bill.notes!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        UpdatedByLabel(name: bill.createdByName, at: bill.createdAt, prefix: 'Added by'),
        if (bill.updatedByName != null && bill.updatedAt != null &&
            bill.createdAt != null && bill.updatedAt!.difference(bill.createdAt!).inSeconds > 5)
          UpdatedByLabel(name: bill.updatedByName, at: bill.updatedAt, prefix: 'Edited by'),
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.bill, required this.enabled, required this.onLink});
  final PurchaseBill bill;
  final bool enabled;
  final ValueChanged<PurchaseSerial> onLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: AppColors.textPrimary);

    return _Card(
      header: 'ITEMS (${bill.items.length})',
      children: [
        for (final (i, item) in bill.items.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Divider(height: 1)),
          Text(item.description, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.qty} × ${formatTaka(item.unitPrice)}  =  ${formatTaka(item.amount)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: WarrantyPill(item: item)),
            ],
          ),
          if (item.serials.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('No serial on the bill', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary)),
            ),
          for (final s in item.serials)
            InkWell(
              onTap: enabled ? () => onLink(s) : null,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      s.machineId == null ? Icons.link_off_rounded : Icons.link_rounded,
                      size: 16,
                      color: s.machineId == null ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(s.serialNo, style: mono),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: s.machineId == null
                          ? Text('Not linked — tap to link',
                              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,)
                          : GestureDetector(
                              onTap: s.clientId == null
                                  ? null
                                  : () => context.push('/clients/${s.clientId}/machine/${s.machineId}'),
                              child: Text(
                                '${s.clientName ?? 'Machine'} · ${s.machineLabel ?? ''}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.accent,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.accent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                    Icon(Icons.edit_rounded, size: 14, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Checklist of the bill's unlinked serials, one set ticked to start with.
class _SetPicker extends StatefulWidget {
  const _SetPicker({required this.bill, required this.scroll});
  final PurchaseBill bill;
  final ScrollController scroll;

  @override
  State<_SetPicker> createState() => _SetPickerState();
}

class _SetPickerState extends State<_SetPicker> {
  late final Set<String> _ticked = widget.bill.nextSet().map((s) => s.id).toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: AppColors.textPrimary);
    final items = [
      for (final i in widget.bill.items)
        (item: i, open: i.serials.where((s) => s.machineId == null).toList()),
    ].where((e) => e.open.isNotEmpty).toList();
    final chosen = [for (final e in items) ...e.open.where((s) => _ticked.contains(s.id))];
    final sets = widget.bill.setCount;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: AppColors.surface3, borderRadius: AppRadius.chip),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Text('Parts for one machine',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: Text(
            'One of $sets sets is ticked. Change the ticks if you know which serials went into this PC.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            children: [
              for (final e in items) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Text(
                    '${e.item.description}  ·  ${e.item.qty % sets == 0 ? '${e.item.qty ~/ sets} per set' : 'extra item'}',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final s in e.open)
                  CheckboxListTile(
                    dense: true,
                    value: _ticked.contains(s.id),
                    title: Text(s.serialNo, style: mono),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (v!) {
                          _ticked.add(s.id);
                        } else {
                          _ticked.remove(s.id);
                        }
                      });
                    },
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: chosen.isEmpty ? null : () => Navigator.pop(context, chosen),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('Next: choose the machine (${chosen.length} parts)'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.header, required this.children});
  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
