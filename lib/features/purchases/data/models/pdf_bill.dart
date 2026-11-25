// lib/features/purchases/data/models/pdf_bill.dart
//
// Fills a bill from the seller's own PDF, on the device. Built for the
// ZAB ERP invoice (Hitech professionals): exact text with positions, so
// columns are found from the header words (Qty / Unit Price / Amount /
// Warranty) and each item from its Qty number. Anything that doesn't add
// up is marked "Check this".

import 'dart:convert';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'bill_draft.dart';

class PdfWord {
  const PdfWord(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;
  double get cx => (left + right) / 2;

  Map<String, dynamic> toJson() => {'t': text, 'l': left, 'u': top, 'r': right, 'b': bottom};
  factory PdfWord.fromJson(Map<String, dynamic> j) => PdfWord(j['t'] as String,
      (j['l'] as num).toDouble(), (j['u'] as num).toDouble(), (j['r'] as num).toDouble(), (j['b'] as num).toDouble());
}

/// Crystal Reports writes "/Parent null" on the root page node, which makes
/// the PDF library fail. Same-length spaces keep every byte offset valid.
Uint8List patchPdfForReading(Uint8List bytes) {
  final s = latin1.decode(bytes);
  return s.contains('/Parent null')
      ? latin1.encode(s.replaceAll('/Parent null', ' ' * '/Parent null'.length))
      : bytes;
}

/// Every word on every page; later pages sit below earlier ones.
List<PdfWord> readPdfWords(Uint8List bytes) {
  final doc = PdfDocument(inputBytes: patchPdfForReading(bytes));
  try {
    final words = <PdfWord>[];
    final extractor = PdfTextExtractor(doc);
    for (var p = 0; p < doc.pages.count; p++) {
      final offset = p * 10000.0;
      for (final line in extractor.extractTextLines(startPageIndex: p, endPageIndex: p)) {
        for (final w in line.wordCollection) {
          if (w.text.trim().isEmpty) continue;
          final b = w.bounds;
          words.add(PdfWord(w.text.trim(), b.left, b.top + offset, b.right, b.bottom + offset));
        }
      }
    }
    return words;
  } finally {
    doc.dispose();
  }
}

/// The PDF's text in reading order, shown under the form to copy from.
String pdfText(List<PdfWord> words) => _lines(words).map((l) => l.map((w) => w.text).join(' ')).join('\n');

double? _num(String s) {
  final t = s.replaceAll(',', '');
  return RegExp(r'^\d+(\.\d+)?$').hasMatch(t) ? double.parse(t) : null;
}

List<List<PdfWord>> _lines(List<PdfWord> words, {double tol = 3}) {
  final sorted = [...words]..sort((a, b) => a.top.compareTo(b.top));
  final lines = <List<PdfWord>>[];
  for (final w in sorted) {
    if (lines.isNotEmpty && (w.top - lines.last.first.top).abs() <= tol) {
      lines.last.add(w);
    } else {
      lines.add([w]);
    }
  }
  for (final l in lines) {
    l.sort((a, b) => a.left.compareTo(b.left));
  }
  return lines;
}

const _months = {
  'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
  'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
};

/// Header fields and item rows. Items stay empty when the layout isn't
/// recognised; the caller then shows the text to copy from.
BillDraft parsePdfBill(List<PdfWord> words) {
  String low(PdfWord w) => w.text.toLowerCase();
  bool sameRow(PdfWord a, PdfWord b, [double tol = 4]) => (a.top - b.top).abs() <= tol;

  PdfWord? word(bool Function(PdfWord) test) {
    for (final w in words) {
      if (test(w)) return w;
    }
    return null;
  }

  // "Bill No : 0126…" → the words right of the label on its row.
  String? labelled(String first, [String? second]) {
    for (final w in words.where((w) => low(w) == first)) {
      var end = w;
      if (second != null) {
        final next = word((x) => low(x) == second && sameRow(x, w, 2) && x.left > w.left && x.left - w.right < 12);
        if (next == null) continue;
        end = next;
      }
      final value = words
          .where((x) => sameRow(x, w) && x.left > end.right && x.text != ':')
          .toList()
        ..sort((a, b) => a.left.compareTo(b.left));
      final text = value.map((x) => x.text).join(' ').trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  final draft = BillDraft(
    vendor: words.any((w) => low(w).contains('hitech')) ? 'hitech professionals' : (_lines(words).firstOrNull?.map((w) => w.text).join(' ') ?? ''),
    billNo: labelled('bill', 'no') ?? '',
    soldBy: labelled('sold', 'by') ?? '',
  );
  final pay = labelled('payment')?.toLowerCase() ?? '';
  draft.paymentType = pay.contains('credit') ? 'Credit' : pay.contains('cash') ? 'Cash' : null;
  final date = RegExp(r'(\d{1,2})\s*-\s*([A-Za-z]+)\s*-\s*(\d{4})').firstMatch(labelled('date') ?? '');
  final month = date == null ? null : _months[date.group(2)!.toLowerCase()];
  if (date != null && month != null) {
    draft.billDate = DateTime(int.parse(date.group(3)!), month, int.parse(date.group(1)!));
  }

  final totalWord = word((w) => low(w) == 'total');
  if (totalWord != null) {
    final nums = [
      for (final w in words)
        if (sameRow(w, totalWord, 6) && w.left > totalWord.left) _num(w.text),
    ].whereType<double>();
    if (nums.isNotEmpty) draft.total = nums.reduce((a, b) => a > b ? a : b);
  }

  // ── Table ──────────────────────────────────────────────────
  final qtyH = word((w) => low(w) == 'qty');
  if (qtyH == null) return draft;
  // Only header words near "Qty": "Warranty" also appears in the notes.
  PdfWord? header(bool Function(String) test) =>
      word((w) => test(low(w)) && (w.top - qtyH.top).abs() <= 15);
  final descH = header((t) => t.startsWith('description'));
  final priceH = header((t) => t == 'price');
  final amountH = header((t) => t == 'amount');
  final warrH = header((t) => t == 'warranty');
  if (descH == null || amountH == null) return draft;

  final top = descH.bottom;
  final bottom = totalWord?.top ?? double.infinity;
  final descRight = (warrH?.left ?? qtyH.left) - 2;
  bool inCol(PdfWord w, PdfWord h, double pad) => w.cx >= h.left - pad && w.cx <= h.right + pad;

  // One item per number in the Qty column.
  final qtys = words
      .where((w) => w.top > top && w.top < bottom && inCol(w, qtyH, 8) && RegExp(r'^\d+$').hasMatch(w.text))
      .toList()
    ..sort((a, b) => a.top.compareTo(b.top));
  final anchors = <PdfWord>[];
  for (final w in qtys) {
    if (anchors.isEmpty || !sameRow(anchors.last, w)) anchors.add(w);
  }
  final slH = header((t) => t == 'sl.' || t == 'sl');
  final descLeft = (slH?.right ?? 0) + 5; // right of the Sl. No column

  for (final (n, a) in anchors.indexed) {
    final regionTop = a.top - 3;
    final regionBottom = n + 1 < anchors.length ? anchors[n + 1].top - 3 : bottom;
    final region = words.where((w) => w.top >= regionTop && w.top < regionBottom).toList();
    double? at(PdfWord? h, double pad) {
      if (h == null) return null;
      for (final w in region) {
        if (sameRow(w, a) && inCol(w, h, pad)) {
          final v = _num(w.text);
          if (v != null) return v;
        }
      }
      return null;
    }

    final qty = int.parse(a.text);
    final amount = at(amountH, 15);
    final price = at(priceH, 15) ?? (amount != null && qty > 0 ? amount / qty : null);
    final warrN = at(warrH, 6);
    final unitWord = warrH == null
        ? null
        : region.where((w) => inCol(w, warrH, 10) && RegExp(r'^(year|month|day|life)', caseSensitive: false).hasMatch(w.text)).firstOrNull;
    final unit = unitWord?.text.toLowerCase() ?? '';

    // Description first, then serials (from the warranty-unit row, the
    // first comma, or a lone code with digits).
    final lines = _lines(region.where((w) => w.left >= descLeft && w.right <= descRight).toList());
    final desc = <String>[];
    final serialText = <String>[];
    var serials = false;
    for (final (i, l) in lines.indexed) {
      final text = l.map((w) => w.text).join(' ');
      serials = serials ||
          (unitWord != null && l.first.top >= unitWord.top - 2) ||
          text.contains(',') ||
          (i > 0 && l.length == 1 && text.length >= 6 && RegExp(r'\d').hasMatch(text));
      (serials ? serialText : desc).add(text);
    }

    final item = ItemDraft(
      description: desc.join(' ').trim(),
      qty: qty,
      unitPrice: price ?? 0,
      lifetime: unit.startsWith('life'),
      warrantyMonths: warrN == null || unit.startsWith('life')
          ? null
          : unit.startsWith('year')
              ? (warrN * 12).round()
              : unit.startsWith('day')
                  ? (warrN / 30).round()
                  : warrN.round(),
      serials: [
        for (final s in serialText.join(' ').split(','))
          if (s.trim().isNotEmpty) s.trim(),
      ],
    );
    final ok = item.description.isNotEmpty &&
        price != null &&
        (amount == null || (qty * price - amount).abs() < 1) &&
        (item.serials.isEmpty || item.serials.length == qty);
    if (!ok) draft.unclear.add('items[${draft.items.length}]');
    draft.items.add(item);
  }
  return draft;
}
