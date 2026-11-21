// lib/features/purchases/presentation/screens/purchases_screen.dart
//
// Admin / accountant list of vendor bills (PCs and parts sent with machines).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../data/models/purchase_bill.dart';
import '../../data/repositories/purchases_repository.dart';
import '../widgets/purchase_widgets.dart';
import 'add_bill_flow.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _searchCtrl = TextEditingController();
  List<PurchaseBill>? _bills;
  String? _error;
  String _query = '';
  bool _unassignedOnly = false;
  BillSort _sort = BillSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Keeps the current list on screen while refreshing.
  Future<void> _load() async {
    try {
      final bills = await context.read<PurchasesRepository>().getBills();
      if (mounted) {
        setState(() {
          _bills = bills;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_bills == null) {
        setState(() => _error = e.toString());
      } else {
        AppFeedback.error(context, ErrorFormatter.format(e));
      }
    }
  }

  /// Manual / OCR / AI-fill, then open the saved bill to link its parts.
  Future<void> _addBill() async {
    final id = await startAddBill(context);
    if (id == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await context.push('/purchases/$id');
    if (mounted) unawaited(_load());
  }

  Future<void> _open(PurchaseBill bill) async {
    unawaited(HapticFeedback.selectionClick());
    await context.push('/purchases/${bill.id}', extra: bill);
    if (mounted) unawaited(_load()); // links may have changed
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;
    final hPad = isDesktop ? AppSpacing.xl : AppSpacing.md;
    final bills = _bills;
    final q = _query.trim().toLowerCase();
    final shown = (bills ?? [])
        .where((b) => (!_unassignedOnly || b.unassignedCount > 0) && (q.isEmpty || b.searchText.contains(q)))
        .toList()
      ..sort(_sort.compare);
    final unassigned = (bills ?? []).fold<int>(0, (n, b) => n + b.unassignedCount);
    final total = (bills ?? []).fold<double>(0, (n, b) => n + b.total);

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, isDesktop ? AppSpacing.xl : AppSpacing.md, hPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Purchases', style: theme.textTheme.headlineLarge)),
                      ElevatedButton.icon(
                        onPressed: _addBill,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add bill'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    bills == null
                        ? 'Vendor bills for PCs and parts'
                        : '${bills.length} bills  ·  ${formatTaka(total)}  ·  $unassigned parts not linked',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search DMEB ID, bill no, item, serial, notes…',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: AppColors.textTertiary,
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Wrap: on narrow phones the sort button drops below the chip.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('Has unlinked parts'),
                        selected: _unassignedOnly,
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _unassignedOnly = v);
                        },
                      ),
                      PopupMenuButton<BillSort>(
                        tooltip: 'Sort by',
                        initialValue: _sort,
                        color: AppColors.surface2,
                        onSelected: (s) {
                          HapticFeedback.selectionClick();
                          setState(() => _sort = s);
                        },
                        itemBuilder: (_) => [
                          for (final s in BillSort.values)
                            CheckedPopupMenuItem(value: s, checked: s == _sort, child: Text(s.label)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort_rounded, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _sort.label,
                                  style: theme.textTheme.labelMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? ErrorStateWidget(
                      rawError: _error!,
                      onRetry: () {
                        setState(() => _error = null);
                        unawaited(_load());
                      },
                    )
                  : bills == null
                      ? const _ShimmerList()
                      : RefreshIndicator(
                          color: AppColors.accent,
                          backgroundColor: AppColors.surface1,
                          onRefresh: _load,
                          child: shown.isEmpty
                              ? CustomScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.surface3),
                                            const SizedBox(height: AppSpacing.sm),
                                            Text(
                                              bills.isEmpty ? 'No purchase bills yet.' : 'No bills match.',
                                              style:
                                                  theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, AppSpacing.md),
                                  itemCount: shown.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                  itemBuilder: (_, i) => _BillCard(bill: shown[i], onTap: () => _open(shown[i])),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});
  final PurchaseBill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = bill.notes?.split('\n').first;
    final summary = (note != null && note.isNotEmpty) ? note : bill.items.take(2).map((i) => i.description).join(', ');
    final unassigned = bill.unassignedCount;

    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.surface2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  children: [
                    Text('${bill.billDate.day}', style: theme.textTheme.titleMedium?.copyWith(height: 1.1)),
                    Text(
                      DateFormat('MMM yy').format(bill.billDate),
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bill.displayNo}  ·  ${bill.vendor}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bill ${bill.billNo}  ·  $summary',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatTaka(bill.total), style: theme.textTheme.titleSmall),
                  Text(
                    bill.serials.isEmpty
                        ? 'no serials'
                        : unassigned == 0
                            ? 'all linked'
                            : '$unassigned unlinked',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: bill.serials.isEmpty
                          ? AppColors.textTertiary
                          : unassigned == 0
                              ? AppColors.success
                              : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface1,
      highlightColor: AppColors.surface2,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => Container(
          height: 76,
          decoration: BoxDecoration(color: AppColors.surface1, borderRadius: AppRadius.card),
        ),
      ),
    );
  }
}
