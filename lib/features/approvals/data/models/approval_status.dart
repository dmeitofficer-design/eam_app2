// lib/features/approvals/data/models/approval_status.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Review state of a client or machine submitted by a data entry operator.
enum ApprovalStatus {
  pending('pending', 'Pending approval', AppColors.warning),
  approved('approved', 'Approved', AppColors.success),
  rejected('rejected', 'Rejected', AppColors.error);

  const ApprovalStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static ApprovalStatus fromString(String? value) => ApprovalStatus.values
      .firstWhere((e) => e.value == value, orElse: () => ApprovalStatus.approved);
}
