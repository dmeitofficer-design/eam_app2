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
import '../../data/models/purchase_bill.dart';
import '../../data/repositories/purchases_repository.dart';
import '../widgets/purchase_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final unlinked = bill?.serials.where((s) => s.machineId == null).toList() ?? const [];

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: Text(bill == null ? 'Bill' : 'Bill ${bill.billNo}', overflow: TextOverflow.ellipsis),
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
                                    : () => _link(unlinked, title: 'Link ${unlinked.length} unlinked parts to…'),
                                icon: const Icon(Icons.link_rounded, size: 18),
                                label: Text('Link all ${unlinked.length} unlinked parts to a machine'),
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
        row('Bill no', bill.billNo),
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
