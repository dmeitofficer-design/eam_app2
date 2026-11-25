// lib/features/purchases/data/models/bill_draft.dart
//
// An unsaved bill: what the Add bill form edits. Filled empty (manual),
// from on-device OCR text (header fields only), or from the AI reply.

import 'purchase_bill.dart';

class BillDraft {
  BillDraft({
    this.vendor = '',
    this.billNo = '',
    this.billDate,
    this.paymentType,
    this.soldBy = '',
    this.total,
    this.notes = '',
    List<ItemDraft>? items,
    Set<String>? unclear,
  })  : items = items ?? [],
        unclear = unclear ?? {};

  String vendor;
  String billNo;
  DateTime? billDate;
  String? paymentType; // 'Credit' / 'Cash'
  String soldBy;
  double? total; // printed total, checked against the lines
  String notes;
  final List<ItemDraft> items;

  /// Field names the AI marked as hard to read ("bill_no", "items[2].serials"…).
  final Set<String> unclear;

  double get linesTotal => items.fold(0, (s, i) => s + i.qty * i.unitPrice);

  /// Body for create_purchase_bill (migration 012).
  Map<String, dynamic> toJson() => {
        'vendor': vendor.trim(),
        'bill_no': billNo.trim(),
        'bill_date': billDate == null
            ? null
            : '${billDate!.year.toString().padLeft(4, '0')}-'
                '${billDate!.month.toString().padLeft(2, '0')}-'
                '${billDate!.day.toString().padLeft(2, '0')}',
        'payment_type': paymentType,
        'sold_by': soldBy.trim(),
        'total': total ?? linesTotal,
        'notes': notes.trim(),
        'items': [for (final i in items) i.toJson()],
      };

  /// An existing bill, for the Edit bill form.
  factory BillDraft.fromBill(PurchaseBill b) => BillDraft(
        vendor: b.vendor,
        billNo: b.billNo,
        billDate: b.billDate,
        paymentType: b.paymentType,
        soldBy: b.soldBy ?? '',
        total: b.total,
        notes: b.notes ?? '',
        items: [
          for (final i in b.items)
            ItemDraft(
              description: i.description,
              qty: i.qty,
              unitPrice: i.unitPrice,
              warrantyMonths: i.warrantyMonths,
              lifetime: i.lifetimeWarranty,
              serials: [for (final s in i.serials) s.serialNo],
            ),
        ],
      );

  /// Reads the scan-bill reply. Tolerant: the model may leave fields out or
  /// send numbers as strings, so anything unreadable stays empty.
  factory BillDraft.fromAiJson(Map<String, dynamic> json) {
    String str(Object? v) => v == null ? '' : v.toString().trim();
    return BillDraft(
      vendor: str(json['vendor']),
      billNo: str(json['bill_no']),
      billDate: DateTime.tryParse(str(json['bill_date'])),
      paymentType: _payment(str(json['payment_type'])),
      soldBy: str(json['sold_by']),
      total: _num(json['total']),
      notes: str(json['notes']),
      items: [
        for (final e in (json['items'] as List?) ?? const [])
          if (e is Map)
            ItemDraft(
              description: str(e['description']),
              qty: _num(e['qty'])?.round() ?? 1,
              unitPrice: _num(e['unit_price']) ?? 0,
              warrantyMonths: _num(e['warranty_months'])?.round(),
              lifetime: e['lifetime_warranty'] == true,
              serials: [
                for (final s in (e['serials'] as List?) ?? const [])
                  if (str(s).isNotEmpty) str(s),
              ],
            ),
      ],
      unclear: {for (final f in (json['unclear_fields'] as List?) ?? const []) f.toString()},
    );
  }

  /// Header fields found in raw OCR text. Items are left for the user:
  /// OCR loses the table layout, so guessed lines would be wrong too often.
  factory BillDraft.fromOcrText(String text) {
    final lower = text.toLowerCase();
    String? first(RegExp re) => re.firstMatch(text)?.group(1)?.trim();

    final vendor = lower.contains('hitech')
        ? 'hitech professionals'
        : lower.contains('integra')
            ? 'Integra Computers & Electronics'
            : '';
    final totalText = first(RegExp(r'Total\s*(?:Tk\.?)?\s*:?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false));

    return BillDraft(
      vendor: vendor,
      billNo: first(RegExp(r'(?:Bill|Invoice)\s*No\.?\s*[:.]?\s*([A-Z0-9-]{4,})', caseSensitive: false)) ??
          first(RegExp(r'\bNo\.?\s*[:.]?\s*(\d{4,})', caseSensitive: false)) ??
          '',
      billDate: _ocrDate(text),
      paymentType: lower.contains('credit') ? 'Credit' : (lower.contains('cash') ? 'Cash' : null),
      soldBy: first(RegExp(r'Sold\s*by\s*:?\s*([A-Za-z][A-Za-z .]{1,30})', caseSensitive: false))
              ?.split(RegExp(r'\s{2,}|\n')).first ??
          '',
      total: totalText == null ? null : _num(totalText.replaceAll(',', '')),
    );
  }
}

class ItemDraft {
  ItemDraft({
    this.description = '',
    this.qty = 1,
    this.unitPrice = 0,
    this.warrantyMonths,
    this.lifetime = false,
    List<String>? serials,
  }) : serials = serials ?? [];

  String description;
  int qty;
  double unitPrice;
  int? warrantyMonths; // null = no warranty
  bool lifetime;
  List<String> serials;

  Map<String, dynamic> toJson() => {
        'description': description.trim(),
        'qty': qty,
        'unit_price': unitPrice,
        'warranty_months': lifetime ? null : warrantyMonths,
        'lifetime_warranty': lifetime,
        'serials': [for (final s in serials) if (s.trim().isNotEmpty) s.trim()],
      };
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v == null) return null;
  return double.tryParse(v.toString().replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), ''));
}

String? _payment(String v) {
  final l = v.toLowerCase();
  if (l.startsWith('cred')) return 'Credit';
  if (l.startsWith('cash')) return 'Cash';
  return null;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// "25 - May - 2024" (Hitech) or "05/09/24", "27.04.26" (handwritten memos).
DateTime? _ocrDate(String text) {
  final named = RegExp(r'(\d{1,2})\s*[-/ ]\s*([A-Za-z]{3,9})\s*[-/ ]\s*(\d{4})').firstMatch(text);
  if (named != null) {
    final m = _months[named.group(2)!.substring(0, 3).toLowerCase()];
    if (m != null) return DateTime(int.parse(named.group(3)!), m, int.parse(named.group(1)!));
  }
  final numeric = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b').firstMatch(text);
  if (numeric != null) {
    final d = int.parse(numeric.group(1)!), m = int.parse(numeric.group(2)!);
    var y = int.parse(numeric.group(3)!);
    if (y < 100) y += 2000;
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
  }
  return null;
}
