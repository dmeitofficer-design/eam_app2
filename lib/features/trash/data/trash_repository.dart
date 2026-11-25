// lib/features/trash/data/trash_repository.dart
//
// Deleted records kept for a few days (migration 017). Super admins only.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Rows deleted together (a machine with its parts, a bill with its
/// items): restored or deleted for good as one.
class TrashBatch {
  TrashBatch({
    required this.batch,
    required this.kind,
    required this.label,
    required this.deletedAt,
    required this.deletedByName,
    required this.extraRows,
  });

  final int batch;
  final String kind;
  final String label;
  final DateTime deletedAt;
  final String? deletedByName;

  /// Parts, items, serials… that went with it.
  final int extraRows;

  /// Top rows first, so a client deleted with its machines shows the client.
  static List<TrashBatch> group(List<Map<String, dynamic>> rows) {
    final byBatch = <int, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      byBatch.putIfAbsent((r['batch'] as num).toInt(), () => []).add(r);
    }
    final out = [
      for (final MapEntry(key: batch, value: list) in byBatch.entries)
        () {
          final tops = list.where((r) => r['is_top'] == true).toList();
          final main = tops.isNotEmpty ? tops.first : list.first;
          return TrashBatch(
            batch: batch,
            kind: kindLabel(main['table_name'] as String),
            label: tops.length > 1
                ? '${main['label']} + ${tops.length - 1} more'
                : main['label'] as String,
            deletedAt: DateTime.parse(main['deleted_at'] as String),
            deletedByName: main['deleted_by_name'] as String?,
            extraRows: list.length - 1,
          );
        }(),
    ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return out;
  }

  static String kindLabel(String table) => switch (table) {
        'hospital_clients' => 'Client',
        'installed_machines' => 'Machine',
        'engineers' => 'Engineer',
        'machine_config' => 'Config option',
        'purchase_bills' => 'Purchase bill',
        _ => 'Record',
      };
}

class TrashRepository {
  TrashRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TrashBatch>> getBatches() async {
    final data = await _client
        .from('trash')
        .select('batch, table_name, label, is_top, deleted_at, deleted_by_name')
        .order('id');
    return TrashBatch.group((data as List).cast<Map<String, dynamic>>());
  }

  Future<int> getRetentionDays() async {
    final row = await _client
        .from('app_settings')
        .select('value')
        .eq('key', 'trash_retention_days')
        .maybeSingle();
    return (row?['value'] as num?)?.toInt() ?? 3;
  }

  Future<void> setRetentionDays(int days) =>
      _client.rpc('set_trash_retention_days', params: {'days': days});

  Future<void> restore(int batch) => _client.rpc('restore_trash', params: {'p_batch': batch});

  Future<void> deleteForGood(int batch) =>
      _client.rpc('delete_trash_batch', params: {'p_batch': batch});
}
