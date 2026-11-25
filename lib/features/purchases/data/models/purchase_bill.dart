// lib/features/purchases/data/models/purchase_bill.dart
//
// Vendor bills for the PCs and parts sent with client machines
// (tables from migration 010). Admin-only data.

enum WarrantyState { active, expired, lifetime, none }

class PurchaseBill {
  PurchaseBill({
    required this.id,
    required this.vendor,
    required this.billNo,
    required this.billDate,
    required this.total,
    required this.items,
    this.paymentType,
    this.soldBy,
    this.netPaid,
    this.notes,
    this.sourcePage,
    this.dmeNo,
    this.createdByName,
    this.createdAt,
    this.updatedByName,
    this.updatedAt,
  });

  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedByName;
  final DateTime? updatedAt;

  final String id;

  /// Our own bill ID (DMEB001…), assigned by the database (migration 015).
  final String? dmeNo;

  /// The seller's bill number, as printed.
  final String vendor;
  final String billNo;
  final DateTime billDate;
  final String? paymentType;
  final String? soldBy;
  final double total;

  /// Only set when returns/discounts changed what was paid.
  final double? netPaid;

  /// Handwritten notes: purpose, client, cheque.
  final String? notes;

  /// Page in the scanned bills PDF.
  final int? sourcePage;
  final List<PurchaseItem> items;

  Iterable<PurchaseSerial> get serials => items.expand((i) => i.serials);
  int get unassignedCount => serials.where((s) => s.machineId == null).length;

  /// How many PC sets the bill covers, one set per client machine: the
  /// largest quantity that more than half of the serial-tracked items divide
  /// into evenly (6 monitors, 6 boards, 12 RAM, 1 extra mouse → 6 sets).
  int get setCount {
    final qtys = [for (final i in items) if (i.serials.isNotEmpty) i.qty];
    final candidates = qtys.toSet().toList()..sort((a, b) => b.compareTo(a));
    for (final n in candidates) {
      if (n > 1 && qtys.where((q) => q % n == 0).length * 2 > qtys.length) return n;
    }
    return 1;
  }

  /// The unlinked serials of one set: qty / setCount from each item that
  /// splits evenly (2 of 12 RAM). Items that don't split (a single extra
  /// mouse on a 6-set bill) are left out for the user to link on their own.
  List<PurchaseSerial> nextSet() {
    final sets = setCount;
    return [
      for (final i in items)
        if (i.qty % sets == 0)
          ...i.serials.where((s) => s.machineId == null).take(i.qty ~/ sets),
    ];
  }

  /// Our ID when assigned, else the seller's number.
  String get displayNo => dmeNo ?? billNo;

  /// Numeric part of [dmeNo] for sorting (DMEB1000 after DMEB999).
  int get dmeSeq => int.tryParse(dmeNo?.replaceAll(RegExp(r'\D'), '') ?? '') ?? 0;

  /// Lowercased text the purchases search matches against.
  late final String searchText = [
    dmeNo ?? '',
    billNo,
    vendor,
    notes ?? '',
    for (final i in items) ...[i.description, for (final s in i.serials) s.serialNo],
  ].join(' ').toLowerCase();

  factory PurchaseBill.fromJson(Map<String, dynamic> json) {
    final billDate = DateTime.parse(json['bill_date'] as String);
    final items = ((json['purchase_bill_items'] as List?) ?? [])
        .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>, billDate))
        .toList()
      ..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    return PurchaseBill(
      id: json['id'] as String,
      vendor: (json['purchase_vendors'] as Map?)?['name'] as String? ?? '',
      billNo: json['bill_no'] as String,
      dmeNo: json['dme_no'] as String?,
      billDate: billDate,
      paymentType: json['payment_type'] as String?,
      soldBy: json['sold_by'] as String?,
      total: (json['total'] as num).toDouble(),
      netPaid: (json['net_paid'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      sourcePage: json['source_page'] as int?,
      items: items,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedByName: json['updated_by_name'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.lineNo,
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.billDate,
    required this.serials,
    this.warrantyMonths,
    this.lifetimeWarranty = false,
  });

  final String id;
  final int lineNo;
  final String description;
  final int qty;
  final double unitPrice;
  final DateTime billDate;
  final int? warrantyMonths;
  final bool lifetimeWarranty;
  final List<PurchaseSerial> serials;

  double get amount => qty * unitPrice;

  // Same rule as the purchase_warranty_status view: Postgres clamps
  // 31 Jan + 1 month to 28/29 Feb, Dart's DateTime would roll into March.
  DateTime? get warrantyUntil {
    if (lifetimeWarranty || warrantyMonths == null) return null;
    final lastDay = DateTime(billDate.year, billDate.month + warrantyMonths! + 1, 0).day;
    return DateTime(billDate.year, billDate.month + warrantyMonths!,
        billDate.day < lastDay ? billDate.day : lastDay,);
  }

  WarrantyState get warrantyState {
    if (lifetimeWarranty) return WarrantyState.lifetime;
    final until = warrantyUntil;
    if (until == null) return WarrantyState.none;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return until.isBefore(today) ? WarrantyState.expired : WarrantyState.active;
  }

  factory PurchaseItem.fromJson(Map<String, dynamic> json, DateTime billDate) {
    return PurchaseItem(
      id: json['id'] as String,
      lineNo: json['line_no'] as int,
      description: json['description'] as String,
      qty: json['qty'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      billDate: billDate,
      warrantyMonths: json['warranty_months'] as int?,
      lifetimeWarranty: json['lifetime_warranty'] as bool? ?? false,
      serials: ((json['purchase_item_serials'] as List?) ?? [])
          .map((e) => PurchaseSerial.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.serialNo.compareTo(b.serialNo)),
    );
  }
}

class PurchaseSerial {
  const PurchaseSerial({
    required this.id,
    required this.serialNo,
    this.machineId,
    this.machineLabel,
    this.clientId,
    this.clientName,
  });

  final String id;
  final String serialNo;
  final String? machineId;

  /// "Brand Model" of the linked machine, when loaded.
  final String? machineLabel;
  final String? clientId;
  final String? clientName;

  factory PurchaseSerial.fromJson(Map<String, dynamic> json) {
    final machine = json['installed_machines_view'] as Map<String, dynamic>?;
    final client = machine?['hospital_clients'] as Map<String, dynamic>?;
    return PurchaseSerial(
      id: json['id'] as String,
      serialNo: json['serial_no'] as String,
      machineId: json['machine_id'] as String?,
      machineLabel: machine == null ? null : '${machine['brand']} ${machine['model']}',
      clientId: machine?['hospital_id'] as String?,
      clientName: client?['name'] as String?,
    );
  }
}

/// A purchased part linked to a machine, as shown on the machine page.
class MachinePurchasedPart {
  const MachinePurchasedPart({required this.serial, required this.item, required this.billId, required this.billNo});

  final PurchaseSerial serial;
  final PurchaseItem item;
  final String billId;
  final String billNo;

  factory MachinePurchasedPart.fromJson(Map<String, dynamic> json) {
    final itemJson = json['purchase_bill_items'] as Map<String, dynamic>;
    final billJson = itemJson['purchase_bills'] as Map<String, dynamic>;
    return MachinePurchasedPart(
      serial: PurchaseSerial.fromJson(json),
      item: PurchaseItem.fromJson(itemJson, DateTime.parse(billJson['bill_date'] as String)),
      billId: billJson['id'] as String,
      billNo: billJson['dme_no'] as String? ?? billJson['bill_no'] as String,
    );
  }
}

/// Sort orders for the purchases list.
enum BillSort {
  newest('Newest first'),
  oldest('Oldest first'),
  idHigh('Bill ID (newest)'),
  idLow('Bill ID (oldest)'),
  totalHigh('Amount: high to low'),
  totalLow('Amount: low to high'),
  vendor('Vendor A-Z');

  const BillSort(this.label);
  final String label;

  int compare(PurchaseBill a, PurchaseBill b) => switch (this) {
        BillSort.newest => b.billDate.compareTo(a.billDate) != 0
            ? b.billDate.compareTo(a.billDate)
            : b.dmeSeq.compareTo(a.dmeSeq),
        BillSort.oldest => a.billDate.compareTo(b.billDate) != 0
            ? a.billDate.compareTo(b.billDate)
            : a.dmeSeq.compareTo(b.dmeSeq),
        BillSort.idHigh => b.dmeSeq.compareTo(a.dmeSeq),
        BillSort.idLow => a.dmeSeq.compareTo(b.dmeSeq),
        BillSort.totalHigh => b.total.compareTo(a.total),
        BillSort.totalLow => a.total.compareTo(b.total),
        BillSort.vendor => a.vendor.toLowerCase().compareTo(b.vendor.toLowerCase()) != 0
            ? a.vendor.toLowerCase().compareTo(b.vendor.toLowerCase())
            : b.billDate.compareTo(a.billDate),
      };
}
