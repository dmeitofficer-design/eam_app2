// lib/features/approvals/data/models/deletion_request.dart

import 'package:equatable/equatable.dart';

/// An admin's request to delete a record, decided by a super admin.
class DeletionRequest extends Equatable {
  final String id;
  final String targetTable;
  final String targetId;
  final String targetLabel;
  final String? targetLink;
  final String? reason;
  final String status; // pending | approved | rejected
  final String? requestedBy;
  final String? requestedByName;
  final String? reviewedByName;
  final String? reviewNote;
  final DateTime createdAt;

  const DeletionRequest({
    required this.id,
    required this.targetTable,
    required this.targetId,
    required this.targetLabel,
    this.targetLink,
    this.reason,
    required this.status,
    this.requestedBy,
    this.requestedByName,
    this.reviewedByName,
    this.reviewNote,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  String get kindLabel => switch (targetTable) {
        'hospital_clients' => 'Client',
        'installed_machines' => 'Machine',
        'machine_config' => 'Config option',
        'engineers' => 'Engineer',
        _ => 'Record',
      };

  factory DeletionRequest.fromJson(Map<String, dynamic> json) => DeletionRequest(
        id: json['id'] as String,
        targetTable: json['target_table'] as String,
        targetId: json['target_id'] as String,
        targetLabel: json['target_label'] as String,
        targetLink: json['target_link'] as String?,
        reason: json['reason'] as String?,
        status: json['status'] as String,
        requestedBy: json['requested_by'] as String?,
        requestedByName: json['requested_by_name'] as String?,
        reviewedByName: json['reviewed_by_name'] as String?,
        reviewNote: json['review_note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, status];
}
