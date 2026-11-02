// lib/features/clients/data/repositories/clients_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hospital_client.dart';
import '../../../../core/constants/app_constants.dart';

class ClientsRepository {
  ClientsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetch all clients with optional search + filters
  Future<List<HospitalClient>> getClients({
    String? searchQuery,
    DivisionType? division,
    FacilityType? facilityType,
  }) async {
    final query = _client
        .from(AppConstants.tableHospitalClients)
        .select()
        .order('name', ascending: true);

    // Note: Supabase Flutter SDK builds queries via chaining;
    // we conditionally apply filters below.
    final List<dynamic> data;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Full-text search on name, or ilike on phone/address
      data = await _client
          .from(AppConstants.tableHospitalClients)
          .select()
          .or(
            'name.ilike.%$searchQuery%,'
            'contact_person_phone.ilike.%$searchQuery%,'
            'address.ilike.%$searchQuery%',
          )
          .order('name', ascending: true);
    } else if (division != null && facilityType != null) {
      data = await _client
          .from(AppConstants.tableHospitalClients)
          .select()
          .eq('division', division.label)
          .eq('facility_type', facilityType.label)
          .order('name', ascending: true);
    } else if (division != null) {
      data = await _client
          .from(AppConstants.tableHospitalClients)
          .select()
          .eq('division', division.label)
          .order('name', ascending: true);
    } else if (facilityType != null) {
      data = await _client
          .from(AppConstants.tableHospitalClients)
          .select()
          .eq('facility_type', facilityType.label)
          .order('name', ascending: true);
    } else {
      data = await query;
    }

    return data.map((e) => HospitalClient.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch single client by ID
  Future<HospitalClient> getClientById(String id) async {
    final data = await _client
        .from(AppConstants.tableHospitalClients)
        .select()
        .eq('id', id)
        .single();
    return HospitalClient.fromJson(data);
  }

  Future<HospitalClient> createClient(HospitalClient client) async {
    final data = await _client
        .from(AppConstants.tableHospitalClients)
        .insert(client.toJson())
        .select()
        .single();
    return HospitalClient.fromJson(data);
  }

  Future<HospitalClient> updateClient(HospitalClient client) async {
    final data = await _client
        .from(AppConstants.tableHospitalClients)
        .update(client.toJson())
        .eq('id', client.id)
        .select()
        .single();
    return HospitalClient.fromJson(data);
  }

  /// Installed machines per client (total and with expired warranty),
  /// counting only machines the caller can see (approved ones, plus their
  /// own submissions / everything for admins).
  Future<Map<String, ({int total, int expired})>> getMachineStats() async {
    const page = 1000; // PostgREST's default row limit
    final stats = <String, ({int total, int expired})>{};
    final now = DateTime.now();
    for (var from = 0;; from += page) {
      final rows = await _client
          .from(AppConstants.viewInstalledMachines)
          .select('hospital_id, installation_date, warranty_period')
          .range(from, from + page - 1);
      for (final row in rows as List<dynamic>) {
        final m = row as Map<String, dynamic>;
        final id = m['hospital_id'] as String;
        final installed = DateTime.parse(m['installation_date'] as String);
        final months = m['warranty_period'] as int;
        // Same rule as InstalledMachine.warrantyExpiryDate.
        final expiry = DateTime(
          installed.year + (installed.month + months - 1) ~/ 12,
          (installed.month + months - 1) % 12 + 1,
          installed.day,
        );
        final prev = stats[id] ?? (total: 0, expired: 0);
        stats[id] = (
          total: prev.total + 1,
          expired: prev.expired + (now.isBefore(expiry) ? 0 : 1),
        );
      }
      if (rows.length < page) return stats;
    }
  }

  Future<void> deleteClient(String id) async {
    await _client
        .from(AppConstants.tableHospitalClients)
        .delete()
        .eq('id', id);
  }
}
