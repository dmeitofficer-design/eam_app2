// lib/features/approvals/presentation/delete_or_request.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/feedback.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/repositories/approvals_repository.dart';

/// Delete flow shared by every screen:
/// - super admin: confirm, then [deleteNow]
/// - submitter withdrawing their own unapproved item ([ownSubmission]):
///   confirm, then [deleteNow]
/// - admin: ask for an optional reason and send a deletion request
///
/// Returns true only when the record was actually deleted.
Future<bool> deleteOrRequest(
  BuildContext context, {
  required DeletionTarget target,
  required String id,
  required String label,
  String? link,
  bool ownSubmission = false,
  String? consequence,
  required Future<void> Function() deleteNow,
}) async {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) return false;
  final profile = auth.profile;

  if (profile.canDelete || ownSubmission) {
    final ok = await ConfirmDialog.show(
      context,
      title: ownSubmission && !profile.canDelete ? 'Withdraw submission?' : 'Delete $label?',
      message: consequence ?? 'This cannot be undone.',
      confirmLabel: ownSubmission && !profile.canDelete ? 'Withdraw' : 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    try {
      await deleteNow();
      return true;
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, ErrorFormatter.format(e));
      return false;
    }
  }

  if (!profile.isAdmin) return false;

  final reason = await askForText(
    context,
    title: 'Request deletion',
    message: 'A super admin must approve deleting "$label".',
    hint: 'Reason (optional)',
    confirmLabel: 'Send Request',
  );
  if (reason == null || !context.mounted) return false;
  try {
    await context.read<ApprovalsRepository>().requestDeletion(
          target: target,
          id: id,
          label: label,
          link: link,
          reason: reason,
        );
    if (context.mounted) {
      AppFeedback.success(context, 'Sent to a super admin for approval.');
    }
  } catch (e) {
    if (context.mounted) AppFeedback.error(context, ErrorFormatter.format(e));
  }
  return false;
}

/// Dialog with one optional text field. Returns null when cancelled,
/// otherwise the (possibly empty) text.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String message,
  required String hint,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String hint;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(hintText: widget.hint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: widget.destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                )
              : ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
