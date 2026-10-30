// lib/features/approvals/data/repositories/approvals_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../clients/data/models/hospital_client.dart';
import '../../../machines/data/models/installed_machine.dart';
import '../models/approval_status.dart';
import '../models/deletion_request.dart';

/// A pending machine together with the name of the client it belongs to.
class PendingMachine {
  const PendingMachine(this.machine, this.clientName);
  final InstalledMachine machine;
  final String clientName;
}

/// Tables a deletion request can target (must match the database check).
enum DeletionTarget {
  client('hospital_clients'),
  machine('installed_machines'),
  config('machine_config'),
  engineer('engineers');

  const DeletionTarget(this.table);
  final String table;
}

class ApprovalsRepository {
  ApprovalsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _deletionRequests = 'deletion_requests';

  // ── Submissions (clients + machines) ───────────────────────

  Future<List<HospitalClient>> fetchPendingClients() async {
    final data = await _client
        .from(AppConstants.tableHospitalClients)
        .select()
        .eq('approval_status', ApprovalStatus.pending.value)
        .order('created_at', ascending: true);
    return (data as List<dynamic>)
        .map((e) => HospitalClient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PendingMachine>> fetchPendingMachines() async {
    final data = await _client
        .from(AppConstants.viewInstalledMachines)
        .select()
        .eq('approval_status', ApprovalStatus.pending.value)
        .order('created_at', ascending: true);
    final machines = (data as List<dynamic>)
        .map((e) => InstalledMachine.fromJson(e as Map<String, dynamic>))
        .toList();
    if (machines.isEmpty) return const [];

    final clientIds = machines.map((m) => m.hospitalId).toSet().toList();
    final clients = await _client
        .from(AppConstants.tableHospitalClients)
        .select('id, name')
        .inFilter('id', clientIds);
    final names = {
      for (final c in clients as List<dynamic>)
        (c as Map<String, dynamic>)['id'] as String: c['name'] as String,
    };
    return machines
        .map((m) => PendingMachine(m, names[m.hospitalId] ?? 'Unknown client'))
        .toList();
  }

  Future<void> reviewClient(String id, {required bool approve, String? reason}) =>
      _review(AppConstants.tableHospitalClients, id, approve: approve, reason: reason);

  Future<void> reviewMachine(String id, {required bool approve, String? reason}) =>
      _review(AppConstants.tableInstalledMachines, id, approve: approve, reason: reason);

  Future<void> _review(String table, String id, {required bool approve, String? reason}) async {
    final updated = await _client
        .from(table)
        .update({
          'approval_status': approve ? ApprovalStatus.approved.value : ApprovalStatus.rejected.value,
          'rejection_reason': approve ? null : _blankToNull(reason),
        })
        .eq('id', id)
        .eq('approval_status', ApprovalStatus.pending.value)
        .select('id');
    if ((updated as List<dynamic>).isEmpty) {
      throw const AppException('This submission was already reviewed.');
    }
  }

  // ── Deletion requests ──────────────────────────────────────

  /// Pending requests for super admins; the caller's own requests otherwise
  /// (the database decides which rows are visible).
  Future<List<DeletionRequest>> fetchDeletionRequests() async {
    final data = await _client
        .from(_deletionRequests)
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List<dynamic>)
        .map((e) => DeletionRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> requestDeletion({
    required DeletionTarget target,
    required String id,
    required String label,
    String? link,
    String? reason,
  }) async {
    try {
      await _client.from(_deletionRequests).insert({
        'target_table': target.table,
        'target_id': id,
        'target_label': label,
        'target_link': link,
        'reason': _blankToNull(reason),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppException('A deletion request for this is already waiting for approval.');
      }
      rethrow;
    }
  }

  Future<void> reviewDeletion(String requestId, {required bool approve, String? note}) async {
    await _client.rpc('review_deletion_request', params: {
      'request_id': requestId,
      'approve': approve,
      'note': _blankToNull(note),
    });
  }

  Future<void> cancelDeletionRequest(String requestId) async {
    await _client.from(_deletionRequests).delete().eq('id', requestId);
  }

  /// Items waiting for the caller to act on, for the nav badge.
  Future<int> countAwaitingReview({required bool superAdmin}) async {
    final results = await Future.wait([
      _client
          .from(AppConstants.tableHospitalClients)
          .select('id')
          .eq('approval_status', ApprovalStatus.pending.value),
      _client
          .from(AppConstants.viewInstalledMachines)
          .select('id')
          .eq('approval_status', ApprovalStatus.pending.value),
      if (superAdmin)
        _client.from(_deletionRequests).select('id').eq('status', 'pending'),
    ]);
    return results.fold<int>(0, (sum, rows) => sum + (rows as List<dynamic>).length);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
