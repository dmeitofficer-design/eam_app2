import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eam_platform/features/purchases/data/models/pdf_bill.dart';
import 'package:flutter_test/flutter_test.dart';

// Word boxes from a real Hitech (ZAB ERP / Crystal Reports) PDF bill, 23 Nov 2026.
List<PdfWord> _words() => [
      for (final j in jsonDecode(File('test/fixtures/zab_pdf_words.json').readAsStringSync()) as List)
        PdfWord.fromJson(j as Map<String, dynamic>),
    ];

void main() {
  test('reads the header of a ZAB ERP PDF bill', () {
    final d = parsePdfBill(_words());
    expect(d.vendor, 'hitech professionals');
    expect(d.billNo, '01261123172142');
    expect(d.billDate, DateTime(2026, 11, 23));
    expect(d.paymentType, 'Credit');
    expect(d.soldBy, 'JAKIR');
    expect(d.total, 202500);
  });

  test('reads every item with qty, price, warranty and serials', () {
    final d = parsePdfBill(_words());
    expect(d.items, hasLength(11));
    expect(d.unclear, isEmpty);
    expect(d.linesTotal, d.total);

    final monitor = d.items.first;
    expect(monitor.description, 'MONITOR HP 21.5 INCH LED M22F FHD IPS');
    expect((monitor.qty, monitor.unitPrice, monitor.warrantyMonths), (5, 14500, 36));
    expect(monitor.serials, ['3CM5350FHD', '3CM53808TD', '3CM55000GV', '3CM55000J4', '3CM60102JW']);

    // Description on two lines, then serials.
    expect(d.items[2].description, 'DESKTOP HDD INTERNAL SEAGATE 1 TB SATA-7200RPM BARRACUDA');
    expect(d.items[5].warrantyMonths, 1); // "1 Month"
    expect(d.items[6].serials, hasLength(10));
    // No warranty printed; free item.
    expect(d.items[10].warrantyMonths, isNull);
    expect(d.items[10].unitPrice, 0);
    for (final i in d.items) {
      expect(i.serials, hasLength(i.qty), reason: i.description);
    }
  });

  test('another layout gives no items, only what it can find', () {
    final d = parsePdfBill(const [PdfWord('Invoice', 10, 10, 50, 20)]);
    expect(d.items, isEmpty);
  });

  test('the "/Parent null" patch keeps the file length', () {
    final bytes = Uint8List.fromList(latin1.encode('<< /Count 1 /Parent null /Type /Pages >>'));
    final patched = patchPdfForReading(bytes);
    expect(patched.length, bytes.length);
    expect(latin1.decode(patched), isNot(contains('null')));
  });
}
