// lib/features/config/data/repositories/config_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/machine_config.dart';

class ConfigRepository {
  ConfigRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'machine_config';

  Future<List<MachineConfig>> getByType(String configType) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('config_type', configType)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List<dynamic>)
        .map((e) => MachineConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getValues(String configType) async {
    final items = await getByType(configType);
    return items.map((e) => e.value).toList();
  }

  /// Returns all three lists in one trip
  Future<({List<String> genres, List<String> brands, List<String> machineTypes})>
      getAllOptions() async {
    final data = await _client
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final all = (data as List<dynamic>)
        .map((e) => MachineConfig.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      genres: all
          .where((e) => e.configType == 'genre')
          .map((e) => e.value)
          .toList(),
      brands: all
          .where((e) => e.configType == 'brand')
          .map((e) => e.value)
          .toList(),
      machineTypes: all
          .where((e) => e.configType == 'machine_type')
          .map((e) => e.value)
          .toList(),
    );
  }

  Future<MachineConfig> addOption({
    required String configType,
    required String value,
  }) async {
    // Get current max sort_order
    final existing = await getByType(configType);
    final nextOrder =
        existing.isEmpty ? 1 : existing.last.sortOrder + 1;

    final data = await _client
        .from(_table)
        .insert({
          'config_type': configType,
          'value': value,
          'sort_order': nextOrder,
          'is_active': true,
        })
        .select()
        .single();
    return MachineConfig.fromJson(data);
  }

  Future<void> deleteOption(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<MachineConfig> toggleOption(
      String id, bool isActive) async {
    final data = await _client
        .from(_table)
        .update({'is_active': isActive})
        .eq('id', id)
        .select()
        .single();
    return MachineConfig.fromJson(data);
  }
}
