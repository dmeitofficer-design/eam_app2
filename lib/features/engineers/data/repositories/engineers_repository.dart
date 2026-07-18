// lib/features/engineers/data/repositories/engineers_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../machines/data/models/engineer.dart';
import '../../../../core/constants/app_constants.dart';

class EngineersRepository {
  EngineersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// All engineers across all machines (for global directory view)
  Future<List<Engineer>> getAllEngineers() async {
    final data = await _client
        .from(AppConstants.tableEngineers)
        .select()
        .order('name', ascending: true);
    return (data as List<dynamic>)
        .map((e) => Engineer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches engineers currently selected/assigned to the installed machine.
Future<List<Engineer>> getEngineersByMachine(String machineId) async {
  try {
    final machineData = await _client
        .from('installed_machines')
        .select('assigned_engineer_id, installation_engineer_id')
        .eq('id', machineId)
        .maybeSingle();

    if (machineData == null) return [];

    // DEBUG: Print what the database actually returned
    print('DATABASE RETURNED: $machineData');

    final List<String> engineerIds = [
      machineData['assigned_engineer_id'],
      machineData['installation_engineer_id'],
    ].whereType<String>().toSet().toList();

    // DEBUG: See if the IDs are being passed into the list correctly
    print('FILTERED ENGINEER IDS: $engineerIds');

    if (engineerIds.isEmpty) return [];

    final engineersData = await _client
        .from(AppConstants.tableEngineers)
        .select()
        .inFilter('id', engineerIds); 

    // DEBUG: Check if Supabase found an engineer with that ID
    print('ENGINEERS FETCHED FROM TABLE: $engineersData');

    return (engineersData as List<dynamic>)
        .map((e) => Engineer.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('CRITICAL ERROR: $e');
    return [];
  }
}
  Future<Engineer> createEngineer(Engineer engineer) async {
    // Exclude the non-existent machine_id key from our toJson map to avoid DB issues
    final jsonMap = engineer.toJson();
    jsonMap.remove('machine_id');

    final data = await _client
        .from(AppConstants.tableEngineers)
        .insert(jsonMap)
        .select()
        .single();
    return Engineer.fromJson(data);
  }

  Future<Engineer> updateEngineer(Engineer engineer) async {
    // Exclude the non-existent machine_id key from our toJson map to avoid DB issues
    final jsonMap = engineer.toJson();
    jsonMap.remove('machine_id');

    final data = await _client
        .from(AppConstants.tableEngineers)
        .update(jsonMap)
        .eq('id', engineer.id)
        .select()
        .single();
    return Engineer.fromJson(data);
  }

  /// Updates status based on the boolean column in the database
  Future<Engineer> updateEngineerStatus(
    String engineerId,
    bool isAvailable, 
  ) async {
    final data = await _client
        .from(AppConstants.tableEngineers)
        .update({'is_available': isAvailable}) 
        .eq('id', engineerId)
        .select()
        .single();
    return Engineer.fromJson(data);
  }

  Future<void> deleteEngineer(String id) async {
    await _client.from(AppConstants.tableEngineers).delete().eq('id', id);
  }
}

