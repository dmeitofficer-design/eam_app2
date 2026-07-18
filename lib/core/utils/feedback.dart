// lib/core/utils/feedback.dart
//
// Centralised helpers so every screen shows consistent snackbars/toasts
// without duplicating ScaffoldMessenger calls.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppColors.success, Icons.check_circle_rounded);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppColors.error, Icons.error_rounded);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppColors.accent, Icons.info_rounded);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, AppColors.warning, Icons.warning_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color accent,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
            side: BorderSide(color: accent.withOpacity(0.3)),
          ),
        ),
      );
  }
}
