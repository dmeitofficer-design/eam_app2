import 'package:eam_platform/features/purchases/data/models/purchase_bill.dart';
import 'package:eam_platform/features/purchases/data/repositories/purchases_repository.dart';
import 'package:eam_platform/features/purchases/presentation/screens/purchase_bill_screen.dart';
import 'package:eam_platform/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Shape of the PostgREST response for PurchasesRepository._billSelect.
Map<String, dynamic> billJson() => {
      'id': 'b1',
      'bill_no': '01250529153195',
      'bill_date': '2025-01-31',
      'payment_type': 'Credit',
      'sold_by': 'JAKIR',
      'total': 60500,
      'net_paid': 50500,
      'notes': 'Bill 60,500 - HDD return 10,000 = 50,500. A very long handwritten note that must wrap fine on a phone.',
      'source_page': 32,
      'purchase_vendors': {'name': 'hitech professionals'},
      'purchase_bill_items': [
        {
          'id': 'i2',
          'line_no': 2,
          'description': 'DESKTOP RAM PATRIOT 8GB DDR4 BUS-3200 SIGNATURE LINE WITH HEATSINK AND A LONG NAME',
          'qty': 2,
          'unit_price': 2500,
          'warranty_months': null,
          'lifetime_warranty': true,
          'purchase_item_serials': [
            {
              'id': 's2',
              'serial_no': '212410111200583',
              'machine_id': 'm1',
              'installed_machines': {
                'brand': 'Fujifilm',
                'model': 'FDR Smart X',
                'hospital_id': 'c1',
                'hospital_clients': {'name': 'Brac Healthcare Siddheswari Branch With A Long Name'},
              },
            },
            {'id': 's3', 'serial_no': '212410111200579', 'machine_id': null, 'installed_machines': null},
          ],
        },
        {
          'id': 'i1',
          'line_no': 1,
          'description': 'MONITOR HP 21.5 INCH LED M22F FHD IPS',
          'qty': 1,
          'unit_price': 12500,
          'warranty_months': 1,
          'lifetime_warranty': false,
          'purchase_item_serials': [
            {'id': 's1', 'serial_no': '3CM4172JKP', 'machine_id': null, 'installed_machines': null},
          ],
        },
        {
          'id': 'i3',
          'line_no': 3,
          'description': 'Setup service charge',
          'qty': 2,
          'unit_price': 2250,
          'warranty_months': null,
          'lifetime_warranty': false,
          'purchase_item_serials': <dynamic>[],
        },
      ],
    };

class _FakeRepo extends PurchasesRepository {
  // No auto-refresh: its periodic timer would outlive the test.
  _FakeRepo()
      : super(
          client: SupabaseClient(
            'http://localhost',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<List<PurchaseBill>> getBills() async => [PurchaseBill.fromJson(billJson())];

  @override
  Future<PurchaseBill> getBill(String id) async => PurchaseBill.fromJson(billJson());
}

Widget _app(Widget child) => RepositoryProvider<PurchasesRepository>(
      create: (_) => _FakeRepo(),
      child: MaterialApp(home: child),
    );

void main() {
  group('PurchaseBill.fromJson', () {
    final bill = PurchaseBill.fromJson(billJson());

    test('parses bill, sorts items by line and counts unlinked serials', () {
      expect(bill.vendor, 'hitech professionals');
      expect(bill.netPaid, 50500);
      expect(bill.items.map((i) => i.lineNo), [1, 2, 3]);
      expect(bill.serials.length, 3);
      expect(bill.unassignedCount, 2);
      final linked = bill.serials.singleWhere((s) => s.machineId != null);
      expect(linked.clientName, startsWith('Brac'));
      expect(linked.machineLabel, 'Fujifilm FDR Smart X');
    });

    test('warranty end date clamps like Postgres (31 Jan + 1 month = 28 Feb)', () {
      expect(bill.items[0].warrantyUntil, DateTime(2025, 2, 28));
      expect(bill.items[0].warrantyState, WarrantyState.expired);
      expect(bill.items[1].warrantyState, WarrantyState.lifetime);
      expect(bill.items[2].warrantyState, WarrantyState.none);
    });

    test('search text covers bill no, items, serials and notes', () {
      expect(bill.searchText, contains('3cm4172jkp'));
      expect(bill.searchText, contains('hdd return'));
      expect(bill.searchText, contains('monitor hp'));
    });
  });

  group('renders without overflow at phone width', () {
    for (final (name, screen) in [
      ('purchases list', const PurchasesScreen()),
      ('bill detail', const PurchaseBillScreen(billId: 'b1')),
    ]) {
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(screen));
        await tester.pump(); // load
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.textContaining('01250529153195'), findsWidgets);
      });
    }
  });
}
