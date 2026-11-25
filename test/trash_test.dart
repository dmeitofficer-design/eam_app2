import 'package:eam_platform/features/purchases/data/models/bill_draft.dart';
import 'package:eam_platform/features/purchases/data/models/purchase_bill.dart';
import 'package:eam_platform/features/trash/data/trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trash groups rows deleted together under the top row', () {
    final batches = TrashBatch.group([
      {'batch': 7, 'table_name': 'installed_machines', 'label': 'GE Logiq', 'is_top': true,
       'deleted_at': '2026-11-24T10:00:00Z', 'deleted_by_name': 'Mehedi'},
      {'batch': 7, 'table_name': 'machine_parts', 'label': 'Probe', 'is_top': false,
       'deleted_at': '2026-11-24T10:00:00Z', 'deleted_by_name': 'Mehedi'},
      {'batch': 9, 'table_name': 'purchase_bills', 'label': 'DMEB074 · bill 12', 'is_top': true,
       'deleted_at': '2026-11-25T10:00:00Z', 'deleted_by_name': null},
    ]);
    expect(batches.map((b) => b.batch), [9, 7]); // newest first
    expect(batches[1].kind, 'Machine');
    expect(batches[1].extraRows, 1);
    expect(batches[0].kind, 'Purchase bill');
  });

  test('BillDraft.fromBill copies items and serials for editing', () {
    final bill = PurchaseBill.fromJson({
      'id': 'b1', 'bill_no': '12', 'dme_no': 'DMEB074', 'bill_date': '2026-11-23',
      'total': 202500, 'purchase_vendors': {'name': 'hitech professionals'},
      'created_by_name': 'Mehedi Hasan', 'created_at': '2026-11-23T05:00:00Z',
      'purchase_bill_items': [
        {'id': 'i1', 'line_no': 1, 'description': 'Monitor', 'qty': 2, 'unit_price': 14500,
         'warranty_months': 36, 'lifetime_warranty': false,
         'purchase_item_serials': [{'id': 's1', 'serial_no': 'SN1'}, {'id': 's2', 'serial_no': 'SN2'}]},
      ],
    });
    expect(bill.createdByName, 'Mehedi Hasan');
    final d = BillDraft.fromBill(bill);
    expect(d.vendor, 'hitech professionals');
    expect(d.items.single.serials, ['SN1', 'SN2']);
    expect(d.toJson()['bill_date'], '2026-11-23');
  });
}
