// lib/features/approvals/presentation/approval_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/feedback.dart';
import '../../notifications/presentation/notifications_cubit.dart';
import '../data/models/approval_status.dart';
import 'delete_or_request.dart';

/// Small chip for list cards. Approved items show nothing.
class ApprovalChip extends StatelessWidget {
  const ApprovalChip({super.key, required this.status});
  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ApprovalStatus.approved) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status == ApprovalStatus.pending ? 'Pending' : status.label,
        style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Banner on a detail screen for an unapproved client or machine.
/// Admins get Approve / Reject buttons.
class ApprovalBanner extends StatefulWidget {
  const ApprovalBanner({
    super.key,
    required this.status,
    this.rejectionReason,
    this.submittedBy,
    required this.canReview,
    required this.review,
    required this.onReviewed,
  });

  final ApprovalStatus status;
  final String? rejectionReason;
  final String? submittedBy;
  final bool canReview;

  /// Performs the review in the database.
  final Future<void> Function({required bool approve, String? reason}) review;

  /// Called after a successful review, e.g. to reload the screen.
  final VoidCallback onReviewed;

  @override
  State<ApprovalBanner> createState() => _ApprovalBannerState();
}

class _ApprovalBannerState extends State<ApprovalBanner> {
  bool _busy = false;

  Future<void> _act(bool approve) async {
    String? reason;
    if (!approve) {
      reason = await askForText(
        context,
        title: 'Reject submission',
        message: 'The submitter will see your reason.',
        hint: 'Reason (optional)',
        confirmLabel: 'Reject',
        destructive: true,
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.review(approve: approve, reason: reason);
      if (!mounted) return;
      AppFeedback.success(context, approve ? 'Approved.' : 'Rejected.');
      context.read<NotificationsCubit>().refresh();
      widget.onReviewed();
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (status == ApprovalStatus.approved) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final details = [
      if (widget.submittedBy != null) 'Submitted by ${widget.submittedBy}',
      if (status == ApprovalStatus.pending && !widget.canReview)
        'Only you and admins can see this until it is approved.',
      if (status == ApprovalStatus.rejected &&
          (widget.rejectionReason?.isNotEmpty ?? false))
        'Reason: ${widget.rejectionReason}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: AppRadius.card,
        border: Border.all(color: status.color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == ApprovalStatus.pending
                    ? Icons.hourglass_top_rounded
                    : Icons.block_rounded,
                color: status.color,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                status.label,
                style: theme.textTheme.titleSmall?.copyWith(color: status.color),
              ),
            ],
          ),
          for (final line in details) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(line, style: theme.textTheme.bodySmall),
          ],
          if (widget.canReview && status == ApprovalStatus.pending) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _act(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _act(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
