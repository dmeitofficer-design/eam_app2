// lib/features/dashboard/data/repositories/dashboard_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/dashboard_analytics.dart';

class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Facility types as the Total Clients card lists them. The first four
  /// always show; the rest only when there are some.
  static const _types = [
    ('Hospital', 'Hospitals'),
    ('Government Hospital', 'Govt Hospitals'),
    ('Diagnostic Center', 'Diagnostic Center'),
    ('Clinic', 'Clinical Center'),
    ('Medical Checkup Center', 'Checkup Center'),
    ('reseller', 'Reseller'),
  ];

  Future<DashboardAnalytics> getAnalytics() async {
    final results = await Future.wait<Object>([
      Future.value(_client.from('dashboard_analytics').select().single()),
      _all(AppConstants.tableHospitalClients, 'id, name, district, division, facility_type, created_at, approval_status'),
      _all(
        AppConstants.viewInstalledMachines,
        'id, hospital_id, brand, model, installation_date, warranty_period, created_at, approval_status',
      ),
    ]);
    final base = DashboardAnalytics.fromJson(results[0] as Map<String, dynamic>);
    bool approved(Map<String, dynamic> r) => (r['approval_status'] as String? ?? 'approved') == 'approved';
    final clients = (results[1] as List<Map<String, dynamic>>).where(approved).toList();
    final machines = (results[2] as List<Map<String, dynamic>>).where(approved).toList();

    // Clients: per type, divisions, districts, newest two.
    final perType = <String, int>{};
    for (final c in clients) {
      final t = (c['facility_type'] as String? ?? '').toLowerCase();
      perType[t] = (perType[t] ?? 0) + 1;
    }
    final byType = <(String, int)>[];
    for (var i = 0; i < _types.length; i++) {
      final count = perType[_types[i].$1.toLowerCase()] ?? 0;
      if (i < 4 || count > 0) byType.add((_types[i].$2, count));
    }
    final divisions = clients.map((c) => c['division']).toSet().length;
    final districts = clients
        .map((c) => (c['district'] as String? ?? '').trim().toLowerCase())
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;
    final names = {for (final c in clients) c['id'] as String: c['name'] as String? ?? ''};
    clients.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

    // Machines: warranty split, newest two installations.
    final now = DateTime.now();
    var inWarranty = 0;
    for (final m in machines) {
      final installed = DateTime.parse(m['installation_date'] as String);
      final months = (m['warranty_period'] as num).toInt();
      // Same rule as InstalledMachine.warrantyExpiryDate.
      final expiry = DateTime(
        installed.year + (installed.month + months - 1) ~/ 12,
        (installed.month + months - 1) % 12 + 1,
        installed.day,
      );
      if (now.isBefore(expiry)) inWarranty++;
    }
    machines.sort((a, b) {
      final byDate = (b['installation_date'] as String).compareTo(a['installation_date'] as String);
      return byDate != 0 ? byDate : (b['created_at'] as String).compareTo(a['created_at'] as String);
    });

    return DashboardAnalytics(
      totalClients: clients.length,
      activeBrands: base.activeBrands,
      totalDivisions: divisions,
      availableEngineers: base.availableEngineers,
      totalMachines: machines.length,
      clientsByType: byType,
      districtsCovered: districts,
      inWarranty: inWarranty,
      outOfWarranty: machines.length - inWarranty,
      latestClients: [
        for (final c in clients.take(2))
          LatestClient(id: c['id'] as String, name: c['name'] as String? ?? '', division: c['division'] as String? ?? ''),
      ],
      latestInstalls: [
        for (final m in machines.take(2))
          LatestInstall(
            machineId: m['id'] as String,
            clientId: m['hospital_id'] as String,
            title: '${m['brand'] ?? ''} ${m['model'] ?? ''}'.trim(),
            clientName: names[m['hospital_id']] ?? '',
          ),
      ],
    );
  }

  /// Every row of [table] (PostgREST returns at most 1000 per request).
  Future<List<Map<String, dynamic>>> _all(String table, String columns) async {
    const page = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      final batch = await _client.from(table).select(columns).order('id').range(from, from + page - 1);
      rows.addAll((batch as List<dynamic>).cast<Map<String, dynamic>>());
      if (batch.length < page) return rows;
    }
  }
}
