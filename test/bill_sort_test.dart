import 'package:eam_platform/features/purchases/data/models/purchase_bill.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseBill _bill(String? dme, String date, double total, String vendor) => PurchaseBill.fromJson({
      'id': dme ?? date,
      'dme_no': dme,
      'bill_no': 'X',
      'bill_date': date,
      'total': total,
      'purchase_vendors': {'name': vendor},
    });

List<String?> _ids(List<PurchaseBill> bills, BillSort s) => ([...bills]..sort(s.compare)).map((b) => b.dmeNo).toList();

void main() {
  final bills = [
    _bill('DMEB002', '2025-01-10', 500, 'Integra'),
    _bill('DMEB1000', '2025-03-01', 100, 'hitech'),
    _bill('DMEB999', '2024-12-01', 900, 'Alpha'),
  ];

  test('bill ID sorts by number, not text (DMEB1000 after DMEB999)', () {
    expect(_ids(bills, BillSort.idLow), ['DMEB002', 'DMEB999', 'DMEB1000']);
    expect(_ids(bills, BillSort.idHigh), ['DMEB1000', 'DMEB999', 'DMEB002']);
  });

  test('date, amount and vendor sorts', () {
    expect(_ids(bills, BillSort.newest), ['DMEB1000', 'DMEB002', 'DMEB999']);
    expect(_ids(bills, BillSort.oldest), ['DMEB999', 'DMEB002', 'DMEB1000']);
    expect(_ids(bills, BillSort.totalHigh), ['DMEB999', 'DMEB002', 'DMEB1000']);
    expect(_ids(bills, BillSort.totalLow), ['DMEB1000', 'DMEB002', 'DMEB999']);
    expect(_ids(bills, BillSort.vendor), ['DMEB999', 'DMEB1000', 'DMEB002']);
  });

  test('bill ID is searchable and shown, seller number kept', () {
    final b = bills.first;
    expect(b.displayNo, 'DMEB002');
    expect(b.billNo, 'X');
    expect(b.searchText, contains('dmeb002'));
  });
}
