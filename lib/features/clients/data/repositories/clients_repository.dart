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

  Future<void> deleteClient(String id) async {
    await _client
        .from(AppConstants.tableHospitalClients)
        .delete()
        .eq('id', id);
  }
}
