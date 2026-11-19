// lib/features/purchases/presentation/screens/add_bill_page.dart
//
// The Add bill form. Manual, OCR and AI-fill all end here; nothing is
// saved until the user checks it and taps Save.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/models/bill_draft.dart';
import '../../data/repositories/purchases_repository.dart';
import '../widgets/purchase_widgets.dart';

/// What a scan produced: the draft, and the raw OCR text to copy from.
class BillPrefill {
  const BillPrefill({required this.draft, this.rawText});
  final BillDraft draft;
  final String? rawText;
}

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key, this.prefill, this.sourceLabel = 'Manual'});

  /// Null for manual entry.
  final Future<BillPrefill>? prefill;
  final String sourceLabel;

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

/// Warranty choices; -1 = lifetime, 0 = none, otherwise months.
const _warrantyOptions = [0, 6, 12, 24, 36, 60, -1];
String _warrantyLabel(int v) => switch (v) {
      -1 => 'Lifetime',
      0 => 'No warranty',
      _ when v % 12 == 0 => '${v ~/ 12} year${v == 12 ? '' : 's'}',
      _ => '$v months',
    };

class _ItemRow {
  _ItemRow([ItemDraft? d])
      : description = TextEditingController(text: d?.description ?? ''),
        qty = TextEditingController(text: '${d?.qty ?? 1}'),
        price = TextEditingController(text: d == null || d.unitPrice == 0 ? '' : _plain(d.unitPrice)),
        serials = TextEditingController(text: d?.serials.join('\n') ?? ''),
        warranty = d == null ? 0 : (d.lifetime ? -1 : d.warrantyMonths ?? 0);

  final TextEditingController description, qty, price, serials;
  int warranty;

  int get qtyValue => int.tryParse(qty.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.replaceAll(',', '').trim()) ?? 0;
  List<String> get serialList =>
      [for (final s in serials.text.split(RegExp(r'[\n,]'))) if (s.trim().isNotEmpty) s.trim()];

  ItemDraft toDraft() => ItemDraft(
        description: description.text,
        qty: qtyValue,
        unitPrice: priceValue,
        warrantyMonths: warranty > 0 ? warranty : null,
        lifetime: warranty == -1,
        serials: serialList,
      );

  void dispose() {
    description.dispose();
    qty.dispose();
    price.dispose();
    serials.dispose();
  }
}

String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _AddBillPageState extends State<AddBillPage> {
  final _vendor = TextEditingController();
  final _billNo = TextEditingController();
  final _soldBy = TextEditingController();
  final _total = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  String? _payment;
  final List<_ItemRow> _items = [];
  Set<String> _unclear = {};
  String? _rawText;

  bool _loading = false;
  String? _prefillError;
  bool _saving = false;
  String? _formError;
  List<String> _vendors = const [];

  @override
  void initState() {
    super.initState();
    _total.addListener(() => setState(() {}));
    unawaited(_loadVendors());
    final prefill = widget.prefill;
    if (prefill == null) {
      _addItem();
    } else {
      _loading = true;
      unawaited(prefill.then(_apply, onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _prefillError = ErrorFormatter.format(e);
          _addItem();
        });
      },),);
    }
  }

  Future<void> _loadVendors() async {
    try {
      final names = await context.read<PurchasesRepository>().getVendorNames();
      if (mounted) setState(() => _vendors = names);
    } catch (_) {
      // Only a convenience for the vendor field; typing still works.
    }
  }

  void _apply(BillPrefill p) {
    if (!mounted) return;
    final d = p.draft;
    setState(() {
      _loading = false;
      _vendor.text = d.vendor;
      _billNo.text = d.billNo;
      _soldBy.text = d.soldBy;
      _notes.text = d.notes;
      _total.text = d.total == null ? '' : _plain(d.total!);
      _date = d.billDate;
      _payment = d.paymentType;
      _unclear = d.unclear;
      _rawText = p.rawText;
      for (final i in d.items) {
        _addItem(i);
      }
      if (_items.isEmpty) _addItem();
    });
    unawaited(HapticFeedback.lightImpact());
  }

  void _addItem([ItemDraft? d]) {
    final row = _ItemRow(d);
    for (final c in [row.qty, row.price, row.serials]) {
      c.addListener(() => setState(() {}));
    }
    _items.add(row);
  }

  @override
  void dispose() {
    for (final c in [_vendor, _billNo, _soldBy, _total, _notes]) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  double get _linesTotal => _items.fold(0, (s, i) => s + i.qtyValue * i.priceValue);
  double? get _printedTotal => double.tryParse(_total.text.replaceAll(',', '').trim());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _validate() {
    if (_vendor.text.trim().isEmpty) return 'Enter the vendor.';
    if (_billNo.text.trim().isEmpty) return 'Enter the bill number.';
    if (_date == null) return 'Pick the bill date.';
    final filled = _items.where((i) => i.description.text.trim().isNotEmpty).toList();
    if (filled.isEmpty) return 'Add at least one item.';
    for (final (n, i) in filled.indexed) {
      if (i.qtyValue < 1) return 'Item ${n + 1}: quantity must be 1 or more.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    setState(() => _formError = error);
    if (error != null) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    final printed = _printedTotal;
    if (printed != null && (printed - _linesTotal).abs() > 0.5) {
      final go = await _confirmMismatch(printed);
      if (go != true || !mounted) return;
    }

    final draft = BillDraft(
      vendor: _vendor.text,
      billNo: _billNo.text,
      billDate: _date,
      paymentType: _payment,
      soldBy: _soldBy.text,
      total: printed,
      notes: _notes.text,
      items: [for (final i in _items) if (i.description.text.trim().isNotEmpty) i.toDraft()],
    );

    setState(() => _saving = true);
    try {
      final id = await context.read<PurchasesRepository>().createBill(draft);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      AppFeedback.success(context, 'Bill ${draft.billNo.trim()} saved.');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _formError = ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmMismatch(double printed) => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.surface1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Totals don\'t match', style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The lines add up to ${formatTaka(_linesTotal)}, but the bill says ${formatTaka(printed)}. '
                  'A price or quantity may be wrong. The printed total is what will be saved.',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Go back and check'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Save anyway'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  /// Helper text for a field the AI marked as unclear.
  String? _check(String field) => _unclear.contains(field) ? 'Check this — the AI wasn\'t sure' : null;
  bool _itemUnclear(int i) => _unclear.any((f) => f.startsWith('items[$i]'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add bill'),
            Text(widget.sourceLabel, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text('Reading the bill…', style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_prefillError != null)
                        _Banner(
                          color: AppColors.error,
                          text: 'Couldn\'t read the bill: $_prefillError\nYou can still type it in below.',
                        ),
                      if (_unclear.isNotEmpty)
                        const _Banner(
                          color: AppColors.warning,
                          text: 'Filled by AI. Fields marked "Check this" were hard to read. Check every field before saving.',
                        )
                      else if (widget.prefill != null && _prefillError == null)
                        _Banner(
                          color: AppColors.accent,
                          text: _rawText != null
                              ? 'Bill no, date and total were filled where found. Copy the rest from the text below.'
                              : 'Filled by AI. Check every field before saving.',
                        ),
                      if (_rawText != null) _OcrTextPanel(text: _rawText!),
                      _Section(
                        title: 'BILL',
                        children: [
                          TextField(
                            controller: _vendor,
                            decoration: InputDecoration(
                              labelText: 'Vendor *',
                              helperText: _check('vendor'),
                              suffixIcon: _vendors.isEmpty
                                  ? null
                                  : PopupMenuButton<String>(
                                      tooltip: 'Pick a known vendor',
                                      icon: const Icon(Icons.arrow_drop_down_rounded),
                                      onSelected: (v) => setState(() => _vendor.text = v),
                                      itemBuilder: (_) => [for (final v in _vendors) PopupMenuItem(value: v, child: Text(v))],
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _billNo,
                                  decoration: InputDecoration(labelText: 'Bill no *', helperText: _check('bill_no')),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Date *',
                                      helperText: _check('bill_date'),
                                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                    ),
                                    child: Text(_date == null ? '' : DateFormat('d MMM yyyy').format(_date!)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _payment,
                                  decoration: const InputDecoration(labelText: 'Payment'),
                                  items: const [
                                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                  ],
                                  onChanged: (v) => setState(() => _payment = v),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(controller: _soldBy, decoration: const InputDecoration(labelText: 'Sold by')),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _notes,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Notes (purpose, client, cheque…)',
                              helperText: _check('notes'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final (n, row) in _items.indexed) ...[
                        _ItemEditor(
                          index: n,
                          row: row,
                          unclear: _itemUnclear(n),
                          onWarranty: (v) => setState(() => row.warranty = v),
                          onRemove: _items.length == 1
                              ? null
                              : () => setState(() {
                                    _items.removeAt(n).dispose();
                                  }),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => setState(_addItem),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add item'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), shape: const StadiumBorder()),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _TotalsBox(
                        linesTotal: _linesTotal,
                        printed: _printedTotal,
                        controller: _total,
                        helper: _check('total'),
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_formError!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save bill'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52), shape: const StadiumBorder()),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.index,
    required this.row,
    required this.unclear,
    required this.onWarranty,
    this.onRemove,
  });

  final int index;
  final _ItemRow row;
  final bool unclear;
  final ValueChanged<int> onWarranty;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serials = row.serialList.length;
    final mismatch = serials > 0 && serials != row.qtyValue;
    // Keep an unusual value the AI found (e.g. 72 months); Lifetime stays last.
    final options = {..._warrantyOptions, row.warranty}.toList()
      ..sort((a, b) => a == b ? 0 : (a < 0 ? 1 : (b < 0 ? -1 : a.compareTo(b))));

    return _Section(
      title: 'ITEM ${index + 1}',
      warning: unclear ? 'Check this item — the AI wasn\'t sure' : null,
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove item',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              onPressed: onRemove,
            ),
      children: [
        TextField(
          controller: row.description,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: row.qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: row.price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit price (Tk)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          initialValue: row.warranty,
          decoration: const InputDecoration(labelText: 'Warranty'),
          items: [for (final v in options) DropdownMenuItem(value: v, child: Text(_warrantyLabel(v)))],
          onChanged: (v) => onWarranty(v ?? 0),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: row.serials,
          minLines: 1,
          maxLines: 6,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Serial numbers (one per line)',
            helperText: serials == 0 ? 'Leave empty if the bill shows none' : '$serials serial${serials == 1 ? '' : 's'}',
            errorText: mismatch ? '$serials serials but qty is ${row.qtyValue}' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '= ${formatTaka(row.qtyValue * row.priceValue)}',
            style: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _TotalsBox extends StatelessWidget {
  const _TotalsBox({required this.linesTotal, required this.printed, required this.controller, this.helper});
  final double linesTotal;
  final double? printed;
  final TextEditingController controller;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = printed == null || (printed! - linesTotal).abs() <= 0.5;
    final color = printed == null ? AppColors.textSecondary : (matches ? AppColors.success : AppColors.error);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Lines add up to', style: theme.textTheme.bodyMedium)),
              Text(formatTaka(linesTotal), style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Total printed on the bill',
              helperText: helper ?? 'Optional: type it to check the lines',
            ),
          ),
          if (printed != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(matches ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: color),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    matches
                        ? 'Matches the printed total'
                        : 'Off by ${formatTaka((printed! - linesTotal).abs())} — check prices and quantities',
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OcrTextPanel extends StatelessWidget {
  const _OcrTextPanel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _Section(
        title: 'TEXT FOUND ON THE BILL',
        trailing: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) AppFeedback.info(context, 'Copied all text.');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy all'),
        ),
        children: [
          Text('Select any part to copy it into the form.', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: SelectableText(
                text.trim().isEmpty ? '(No text found. Try a sharper photo.)' : text,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing, this.warning});
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: warning != null ? AppColors.warning : AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: AppColors.textTertiary),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (warning != null)
            Text(warning!, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.warning)),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}
