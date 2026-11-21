import 'dart:io';

import 'package:eam_platform/features/purchases/data/models/ocr_table.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real ML Kit output from a Galaxy S25 (pages 20 and 79 of the bills PDF),
/// one line per row: "left,top,right,bottom|text".
List<OcrLine> fixture(String name) => [
      for (final row in File('test/fixtures/$name').readAsLinesSync())
        if (row.contains('|'))
          () {
            final i = row.indexOf('|');
            final b = row.substring(0, i).split(',').map(double.parse).toList();
            return OcrLine(row.substring(i + 1), b[0], b[1], b[2], b[3]);
          }(),
    ];

void main() {
  test('page 20: 10 items with qty, price, warranty and serials', () {
    final r = parseOcrItems(fixture('ocr_p20.txt'));
    expect(r.items.length, 10);

    final monitor = r.items[0];
    expect(monitor.description, 'MONITOR HP 21.5 INCH LED M22F FHD IPS');
    expect((monitor.qty, monitor.unitPrice, monitor.warrantyMonths), (6, 12000, 36));
    // "3CM4021 PT1" (stray space) is joined back together.
    expect(monitor.serials, containsAll(['3CM3451VX1', '3CM4021PT1', '3CM4050LYK']));

    // Row "2." was not read by ML Kit; the item is still found.
    expect(r.items[1].description, startsWith('MOTHERBOARD'));

    // Wrapped description joined; no warranty printed.
    final cpu = r.items[4];
    expect(cpu.description, endsWith('4th Gen'));
    expect((cpu.qty, cpu.unitPrice, cpu.warrantyMonths), (6, 2300, null));

    // "SLO1241000221116" -> SL0…, and 12 RAM sticks for 6 PCs.
    expect(r.items[6].serials, contains('SL01241000221116'));
    expect((r.items[7].qty, r.items[7].unitPrice), (12, 600));
    expect(r.items[7].serials.length, 12);
  });

  test('page 79: tilted photo, numbers still land on their own rows', () {
    final r = parseOcrItems(fixture('ocr_p79.txt'));
    expect(r.items.length, 10);
    expect([for (final i in r.items) i.unitPrice], [14500, 9200, 5300, 3500, 2500, 2400, 950, 750, 450, 200]);
    expect(r.items[6].qty, 2); // RAM: 2 × 950
    expect(r.items[6].serials, ['RIS26800515', 'RIS26800538']); // letters kept
  });

  test('no table: nothing found', () {
    final r = parseOcrItems([const OcrLine('blurry', 0, 0, 100, 20)]);
    expect(r.items, isEmpty);
  });
}
