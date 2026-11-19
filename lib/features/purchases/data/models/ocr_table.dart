// lib/features/purchases/data/models/ocr_table.dart
//
// Rebuilds bill item rows from on-device OCR lines (text + position).
// Built for the printed Hitech (ZAB ERP) invoice layout: a description
// column with serials under each product, then Warranty / Qty / Unit Price /
// Amount columns. Anything it can't place is left for the user to fill in.

import 'dart:math' as math;

import 'bill_draft.dart';

/// One OCR line and its box on the photo.
class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;

  double get cx => (left + right) / 2;
  double get cy => (top + bottom) / 2;
  double get height => bottom - top;
}

enum _Col { warranty, qty, price, amount }

/// Item rows found in the table (empty when the layout isn't recognised), and
/// which of them need checking ("items[2]", like the AI-fill marks).
({List<ItemDraft> items, Set<String> unclear}) parseOcrItems(List<OcrLine> lines) {
  const none = (items: <ItemDraft>[], unclear: <String>{});
  if (lines.isEmpty) return none;
  final lineH = _median(lines.map((l) => l.height).toList());

  // ── Header and table bounds ──────────────────────────────────
  OcrLine? find(RegExp re) {
    for (final l in lines) {
      if (re.hasMatch(l.text)) return l;
    }
    return null;
  }

  final descHeader = find(RegExp(r'product\s*desc', caseSensitive: false));
  final amountHeader = find(RegExp(r'^\s*amount', caseSensitive: false));
  if (descHeader == null || amountHeader == null) return none;

  final headerBottom = [descHeader, amountHeader].map((l) => l.bottom).reduce(math.max);
  final footer = lines
      .where((l) => l.top > headerBottom && RegExp(r'reference|in\s*word|^total\b', caseSensitive: false).hasMatch(l.text))
      .map((l) => l.top);
  final tableBottom = footer.isEmpty ? double.infinity : footer.reduce(math.min);

  // Column centres from the header words. "Warranty Qty" or "Unit Price" may
  // come back as one line, so place each word by its share of the characters.
  final centres = <_Col, double>{};
  void place(_Col col, RegExp word) {
    for (final l in lines) {
      if (l.top > headerBottom + lineH || l.bottom < descHeader.top - 3 * lineH) continue;
      final m = word.firstMatch(l.text);
      if (m == null) continue;
      final n = l.text.length;
      centres[col] = l.left + (l.right - l.left) * ((m.start + m.end) / 2) / n;
      return;
    }
  }

  place(_Col.warranty, RegExp('warrant', caseSensitive: false));
  place(_Col.qty, RegExp(r'q\s*t\s*y', caseSensitive: false));
  place(_Col.price, RegExp(r'price|unit', caseSensitive: false));
  centres[_Col.amount] = amountHeader.cx;

  // Description column ends where the first numeric column starts.
  final firstNumX = centres.values.reduce(math.min);
  final descRight = firstNumX - 2 * lineH;

  // A tilted photo puts the right-hand headings higher or lower than the
  // left-hand one, so each side starts below its own heading.
  final table = lines.where((l) {
    final top = (l.cx > descHeader.right + 4 * lineH ? amountHeader.bottom : descHeader.bottom) - lineH * 0.3;
    return l.top >= top && l.bottom <= tableBottom + lineH * 0.3;
  }).toList();

  // ── Left side: row numbers, descriptions, serials ────────────
  final slNos = <OcrLine>[];
  final rest = <OcrLine>[];
  for (final l in table) {
    if (l.right > descRight + lineH) continue;
    if (RegExp(r'^\s*\d{1,2}\s*[.,]?\s*$').hasMatch(l.text) && l.right < descHeader.left) {
      slNos.add(l);
    } else if (RegExp(r'[A-Za-z0-9]').allMatches(l.text).length >= 2) {
      rest.add(l); // 1-character specks (punch holes read as "(") are skipped
    }
  }
  // The heading is centred, so the row-number column marks the left edge.
  final leftEdge = slNos.isEmpty ? 0.0 : slNos.map((s) => s.left).reduce(math.min) - lineH;
  final left = rest.where((l) => l.left >= leftEdge).toList()..sort((a, b) => a.top.compareTo(b.top));
  // A serial level with the next product (tilted photo) is the end of the
  // item above: serials are printed under their product.
  for (var i = 0; i + 1 < left.length; i++) {
    if ((left[i + 1].top - left[i].top).abs() < lineH * 0.5 &&
        !_isSerialLine(left[i].text) &&
        _isSerialLine(left[i + 1].text)) {
      final t = left[i];
      left[i] = left[i + 1];
      left[i + 1] = t;
    }
  }

  final items = <_Row>[];
  for (final l in left) {
    final serial = _isSerialLine(l.text);
    // The row number is sometimes read as part of the line ("11. KEYBOARD…").
    final nearSl = (!serial && _rowNo.hasMatch(l.text)) || slNos.any((s) => (s.cy - l.cy).abs() < lineH * 0.7);
    final current = items.isEmpty ? null : items.last;
    if (!serial && (current == null || nearSl || current.serialLines.isNotEmpty)) {
      items.add(_Row(l));
    } else if (current == null) {
      continue; // serials before any product: ignore
    } else if (serial) {
      current.serialLines.add(l);
    } else {
      current.descLines.add(l); // wrapped description ("Gen", "LGA1151 8thG")
    }
  }
  if (items.isEmpty) return none;

  // ── Right side: numbers by column, then by row ───────────────
  final right = table.where((l) => l.left > descRight).toList();
  final byCol = {for (final c in _Col.values) c: <OcrLine>[]};
  final words = <OcrLine>[];
  for (final l in right) {
    if (_number(l.text) != null) {
      byCol[_nearest(centres, l.cx)]!.add(l);
    } else {
      words.add(l);
    }
  }
  for (final c in byCol.values) {
    c.sort((a, b) => a.cy.compareTo(b.cy));
  }

  // Handwriting below the last printed number is not an item.
  final lastNumber = right.where((l) => _number(l.text) != null).map((l) => l.bottom).fold(0.0, math.max);
  items.removeWhere((r) => r.start.top > lastNumber + 3 * lineH && r.serialLines.isEmpty);
  if (items.isEmpty) return none;

  // A tilted photo puts the numbers higher or lower than their row. A column
  // with exactly one number per item shows by how much.
  double dy = 0;
  for (final c in const [_Col.amount, _Col.price, _Col.qty]) {
    final col = byCol[c]!;
    if (col.length == items.length) {
      dy = _median([for (var i = 0; i < col.length; i++) col[i].cy - items[i].start.cy]);
      break;
    }
  }
  int rowFor(double cy) {
    final y = cy - dy;
    var row = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].start.cy - lineH * 0.8 <= y) row = i;
    }
    return row;
  }

  for (final entry in byCol.entries) {
    final col = entry.value;
    if (col.length == items.length) {
      // One per item: match by order, which no tilt can upset.
      for (var i = 0; i < col.length; i++) {
        items[i].values[entry.key] = _number(col[i].text)!;
      }
    } else {
      for (final l in col) {
        items[rowFor(l.cy)].values.putIfAbsent(entry.key, () => _number(l.text)!);
      }
    }
  }
  for (final l in words) {
    final t = l.text.toLowerCase();
    final row = items[rowFor(l.cy)];
    if (RegExp(r'life|time').hasMatch(t)) row.lifetime = true;
    if (t.contains('month')) row.warrantyUnit = 1;
    if (t.contains('year')) row.warrantyUnit = 12;
  }

  final kept = items.where((r) => r.values.isNotEmpty || r.serialLines.isNotEmpty).toList();
  final drafts = [for (final r in kept) r.toDraft()];
  return (
    items: drafts,
    unclear: {
      for (final (i, r) in kept.indexed)
        if (r.guessed || !r.consistent) 'items[$i]',
    },
  );
}

final _rowNo = RegExp(r'^\s*\d{1,2}\s*[.,]\s+(?=[A-Za-z])');

class _Row {
  _Row(OcrLine start) : start = start, descLines = [start];
  final OcrLine start;
  final List<OcrLine> descLines;
  final List<OcrLine> serialLines = [];
  final Map<_Col, double> values = {};
  bool lifetime = false;
  int? warrantyUnit;
  bool guessed = false;
  bool consistent = true;

  ItemDraft toDraft() {
    var qty = values[_Col.qty]?.round();
    var price = values[_Col.price];
    final amount = values[_Col.amount];

    // qty × price = amount: repair whichever one OCR missed or misread.
    if (amount != null && price != null && price > 0) {
      final q = amount / price;
      if ((q - q.round()).abs() < 0.01 && q.round() > 0 && q.round() != qty) qty = q.round();
    }
    if (amount != null && qty != null && qty > 0 && (price == null || (qty * price - amount).abs() > 0.5)) {
      price = amount / qty;
    }

    consistent = qty != null && price != null && (amount == null || (qty * price - amount).abs() <= 0.5);

    var warranty = values[_Col.warranty]?.round();
    // "Year" without its number: ML Kit drops the thin "1" most often.
    if (warranty == null && warrantyUnit != null && !lifetime) {
      warranty = 1;
      guessed = true;
    }
    return ItemDraft(
      description: descLines.map((l) => l.text.trim()).join(' ').replaceFirst(_rowNo, '').replaceAll(RegExp(r'\s+'), ' '),
      qty: qty ?? 1,
      unitPrice: price ?? 0,
      lifetime: lifetime,
      warrantyMonths: lifetime || warranty == null || warranty <= 0 ? null : warranty * (warrantyUnit ?? 12),
      serials: [for (final l in serialLines) ..._splitSerials(l.text)],
    );
  }
}

/// "SL0124…, SL0124…", "A0689, A3252", "3CM4021Q4P" or a lone "2081".
bool _isSerialLine(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  final tokens = t.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  bool serialLike(String s) {
    final compact = s.replaceAll(' ', '');
    if (!RegExp(r'^[A-Za-z0-9\\/-]{3,}$').hasMatch(compact) || !RegExp(r'\d').hasMatch(compact)) return false;
    // A stray space can split a serial ("3CM4021 PT1"); several words are a
    // description ("REFILL BROTHER CYAN T300").
    final parts = s.trim().split(RegExp(r'\s+'));
    return parts.length == 1 ||
        (parts.length == 2 && RegExp(r'\d').allMatches(compact).length >= compact.length * 0.4);
  }

  if (tokens.length >= 3) return tokens.where(serialLike).length >= tokens.length - 1;
  if (tokens.length == 2) return tokens.every(serialLike);
  // One token: a serial has digits and no spaces between words.
  return serialLike(t) && !t.contains(' ') && !RegExp(r'^\d+(\.\d+)?(GHz|GB|TB|W|MB)$', caseSensitive: false).hasMatch(t);
}

List<String> _splitSerials(String text) => [
      for (final s in text.split(','))
        if (s.trim().isNotEmpty) _cleanSerial(s),
    ];

/// Fixes ML Kit's usual slips: letter O for zero after "SL", stray spaces,
/// accented letters.
String _cleanSerial(String s) {
  var t = s.trim().replaceAll(' ', '');
  const accents = {'Ş': 'S', 'ş': 's', 'İ': 'I', 'Ö': 'O', 'Ü': 'U', 'Ç': 'C'};
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  if (RegExp(r'^S[Ll][0-9Oo]').hasMatch(t)) {
    t = 'SL${t.substring(2).replaceAll(RegExp('[Oo]'), '0')}';
  } else {
    // O/I/l between digits are misread 0/1 ("2324123o42"); letters at the
    // ends belong to the serial ("RIS2576596").
    t = t
        .replaceAllMapped(RegExp(r'(?<=\d)[Oo](?=\d)'), (_) => '0')
        .replaceAllMapped(RegExp(r'(?<=\d)[lI](?=\d)'), (_) => '1');
  }
  return t;
}

/// "12,000" -> 12000, "3" -> 3, "950 Ac-" -> 950. Null when not a number.
double? _number(String text) {
  final m = RegExp(r'^\s*([0-9][0-9,oO]*(?:\.[0-9]{1,2})?)').firstMatch(text);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '').replaceAll(RegExp('[oO]'), '0'));
}

_Col _nearest(Map<_Col, double> centres, double x) =>
    centres.entries.reduce((a, b) => (a.value - x).abs() <= (b.value - x).abs() ? a : b).key;

double _median(List<double> v) {
  v.sort();
  return v.isEmpty ? 20 : v[v.length ~/ 2];
}
