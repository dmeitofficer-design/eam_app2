import 'package:eam_platform/features/purchases/data/models/bill_draft.dart';
import 'package:eam_platform/features/purchases/data/repositories/purchases_repository.dart';
import 'package:eam_platform/features/purchases/presentation/screens/add_bill_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Roughly what ML Kit returns for page 1 of the bills PDF.
const _hitechOcr = '''
hitech professionals
Computer Hardware & Software Sales and Service
Shop# SGR 1 & 8 (GF),BCS Computer City,IDB Bhaban,Dhaka -1207. Mob:
INVOICE / BILL
To:
DIGITAL MACHINERY EQUIPMENT
Date : 25 - May - 2024
Bill No : 01240525140889
Payment : Credit
Sold by : JAKIR
Verify Status : Open
MONITOR SEEN 43" LED TV MONITOR FHD GS32N SMART 1 23,000 23,000
SL01240500209240
Total 24,500.00
IN WORD :TAKA TWENTY-FOUR THOUSAND FIVE HUNDRED Only
''';

// Integra cash memo (page 11): handwritten number and date.
const _integraOcr = '''
Integra COMPUTERS & ELECTRONICS
No. 7911 Hi-Tech Date: 05/09/24
Int Cable 1pcs 1200 1200
Total Tk. 1200
''';

class _FakeRepo extends PurchasesRepository {
  _FakeRepo()
      : super(
          client: SupabaseClient(
            'http://localhost',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  BillDraft? saved;

  @override
  Future<List<String>> getVendorNames() async => ['hitech professionals'];

  @override
  Future<String> createBill(BillDraft draft) async {
    saved = draft;
    return 'new-id';
  }
}

void main() {
  group('BillDraft.fromOcrText', () {
    test('Hitech printed bill: header fields', () {
      final d = BillDraft.fromOcrText(_hitechOcr);
      expect(d.vendor, 'hitech professionals');
      expect(d.billNo, '01240525140889');
      expect(d.billDate, DateTime(2024, 5, 25));
      expect(d.paymentType, 'Credit');
      expect(d.soldBy, 'JAKIR');
      expect(d.total, 24500);
      expect(d.items, isEmpty); // items are copied by hand from the text panel
    });

    test('Integra cash memo: number, dd/mm/yy date, total', () {
      final d = BillDraft.fromOcrText(_integraOcr);
      expect(d.vendor, 'Integra Computers & Electronics');
      expect(d.billNo, '7911');
      expect(d.billDate, DateTime(2024, 9, 5));
      expect(d.total, 1200);
    });

    test('unreadable text leaves everything empty', () {
      final d = BillDraft.fromOcrText('blurry nothing here');
      expect([d.vendor, d.billNo, d.soldBy], everyElement(''));
      expect(d.billDate, isNull);
      expect(d.total, isNull);
    });
  });

  group('BillDraft.fromAiJson', () {
    test('tolerates strings for numbers, blank serials and missing fields', () {
      final d = BillDraft.fromAiJson({
        'vendor': 'hitech professionals',
        'bill_no': '01260926170309',
        'bill_date': '2026-09-26',
        'payment_type': 'credit',
        'total': '81,400',
        'items': [
          {
            'description': 'MONITOR HP 21.5',
            'qty': '2',
            'unit_price': 14500,
            'warranty_months': 36,
            'serials': ['3CM5350F8V', ' ', '3CM5350FGP'],
          },
          {'description': 'RAM', 'qty': 4, 'unit_price': 950, 'lifetime_warranty': true},
        ],
        'unclear_fields': ['items[1].unit_price'],
      });
      expect(d.billDate, DateTime(2026, 9, 26));
      expect(d.paymentType, 'Credit');
      expect(d.total, 81400);
      expect(d.items[0].qty, 2);
      expect(d.items[0].serials, ['3CM5350F8V', '3CM5350FGP']);
      expect(d.items[1].lifetime, isTrue);
      expect(d.unclear, {'items[1].unit_price'});
      expect(d.linesTotal, 2 * 14500 + 4 * 950);
    });

    test('toJson matches create_purchase_bill', () {
      final json = BillDraft(
        vendor: ' Shop ',
        billNo: 'A1',
        billDate: DateTime(2026, 1, 5),
        items: [ItemDraft(description: 'X', qty: 2, unitPrice: 10, warrantyMonths: 12, serials: ['S1', ''])],
      ).toJson();
      expect(json['vendor'], 'Shop');
      expect(json['bill_date'], '2026-01-05');
      expect(json['total'], 20); // no printed total -> sum of lines
      expect((json['items'] as List).single, {
        'description': 'X',
        'qty': 2,
        'unit_price': 10.0,
        'warranty_months': 12,
        'lifetime_warranty': false,
        'serials': ['S1'],
      });
    });
  });

  group('AddBillPage', () {
    Future<_FakeRepo> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo();
      await tester.pumpWidget(RepositoryProvider<PurchasesRepository>.value(
        value: repo,
        child: MaterialApp(home: page),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('OCR prefill: header filled, text panel shown, no overflow', (tester) async {
      await pump(
        tester,
        AddBillPage(
          prefill: Future.value(BillPrefill(draft: BillDraft.fromOcrText(_hitechOcr), rawText: _hitechOcr)),
          sourceLabel: 'Scan (OCR)',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('TEXT FOUND ON THE BILL'), findsOneWidget);
      expect(find.text('01240525140889'), findsWidgets);
      expect(find.text('Copy all'), findsOneWidget);
    });

    testWidgets('AI prefill: unclear item flagged, totals mismatch shown', (tester) async {
      await pump(
        tester,
        AddBillPage(
          prefill: Future.value(BillPrefill(
            draft: BillDraft.fromAiJson({
              'vendor': 'hitech professionals',
              'bill_no': 'B1',
              'bill_date': '2026-09-26',
              'total': 1000,
              'items': [
                {'description': 'RAM', 'qty': 2, 'unit_price': 450, 'serials': ['R1']},
              ],
              'unclear_fields': ['items[0].unit_price'],
            }),
          )),
          sourceLabel: 'AI-fill (Gemini)',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Check this item'), findsOneWidget);
      expect(find.textContaining('Off by Tk 100'), findsOneWidget);
      expect(find.text('1 serials but qty is 2'), findsOneWidget);
    });

    testWidgets('manual: Save needs vendor, bill no and date', (tester) async {
      final repo = await pump(tester, const AddBillPage());
      await tester.ensureVisible(find.text('Save bill'));
      await tester.tap(find.text('Save bill'));
      await tester.pump();
      expect(find.text('Enter the vendor.'), findsOneWidget);
      expect(repo.saved, isNull);
    });
  });
}
