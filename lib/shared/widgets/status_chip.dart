// lib/shared/widgets/status_chip.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  /// Warranty lifecycle preset
  factory StatusChip.warranty({
    required bool isActive,
    required bool expiringSoon,
    required int monthsLeft,
  }) {
    if (!isActive) {
      return const StatusChip(label: 'Expired', color: AppColors.error);
    }
    if (expiringSoon) {
      return StatusChip(
        label: '${monthsLeft}m — Expiring Soon',
        color: AppColors.warning,
      );
    }
    return StatusChip(
      label: '${monthsLeft}m Left',
      color: AppColors.success,
    );
  }

  /// Engineer status preset
  factory StatusChip.engineerStatus(String statusLabel) {
    final Color color;
    switch (statusLabel.toLowerCase()) {
      case 'available':
        color = AppColors.success;
        break;
      case 'on assignment':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.textTertiary;
    }
    return StatusChip(label: statusLabel, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.chip,
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
