// lib/features/approvals/presentation/screens/approvals_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../clients/data/models/hospital_client.dart';
import '../../../clients/presentation/bloc/clients_bloc.dart';
import '../../../notifications/presentation/notifications_cubit.dart';
import '../../data/models/deletion_request.dart';
import '../../data/repositories/approvals_repository.dart';
import '../delete_or_request.dart';

/// Admins review data entry submissions here; super admins also decide
/// deletion requests. Admins see the status of their own requests.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  List<HospitalClient> _clients = const [];
  List<PendingMachine> _machines = const [];
  List<DeletionRequest> _deletions = const [];
  bool _loading = true;
  Object? _error;
  final Set<String> _busy = {};

  ApprovalsRepository get _repo => context.read<ApprovalsRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchPendingClients(),
        _repo.fetchPendingMachines(),
        _repo.fetchDeletionRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _clients = results[0] as List<HospitalClient>;
        _machines = results[1] as List<PendingMachine>;
        _deletions = results[2] as List<DeletionRequest>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs a review action for the item [key], then reloads everything.
  Future<void> _run(String key, Future<void> Function() action, String done) async {
    setState(() => _busy.add(key));
    try {
      await action();
      if (!mounted) return;
      AppFeedback.success(context, done);
      context.read<NotificationsCubit>().refresh();
      context.read<ClientsBloc>().add(const ClientsFetchRequested(forceRefresh: true));
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<String?> _askRejectReason() => askForText(
        context,
        title: 'Reject submission',
        message: 'The submitter will see your reason.',
        hint: 'Reason (optional)',
        confirmLabel: 'Reject',
        destructive: true,
      );

  Future<void> _reviewClient(HospitalClient c, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askRejectReason();
      if (reason == null) return;
    }
    await _run(
      c.id,
      () => _repo.reviewClient(c.id, approve: approve, reason: reason),
      approve ? '${c.name} approved.' : '${c.name} rejected.',
    );
  }

  Future<void> _reviewMachine(PendingMachine p, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askRejectReason();
      if (reason == null) return;
    }
    final m = p.machine;
    await _run(
      m.id,
      () => _repo.reviewMachine(m.id, approve: approve, reason: reason),
      approve ? '${m.brand} ${m.model} approved.' : '${m.brand} ${m.model} rejected.',
    );
  }

  Future<void> _reviewDeletion(DeletionRequest r, bool approve) async {
    final String? note;
    if (approve) {
      note = await askForText(
        context,
        title: 'Delete ${r.targetLabel}?',
        message: 'This permanently deletes the ${r.kindLabel.toLowerCase()}.',
        hint: 'Note for ${r.requestedByName ?? 'the admin'} (optional)',
        confirmLabel: 'Delete',
        destructive: true,
      );
    } else {
      note = await askForText(
        context,
        title: 'Keep ${r.targetLabel}?',
        message: 'The deletion request will be rejected.',
        hint: 'Reason (optional)',
        confirmLabel: 'Reject Request',
      );
    }
    if (note == null) return;
    await _run(
      r.id,
      () => _repo.reviewDeletion(r.id, approve: approve, note: note),
      approve ? '${r.targetLabel} deleted.' : 'Deletion request rejected.',
    );
  }

  Future<void> _cancelDeletion(DeletionRequest r) =>
      _run(r.id, () => _repo.cancelDeletionRequest(r.id), 'Request cancelled.');

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return const SizedBox.shrink();
    final me = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(me),
    );
  }

  Widget _buildBody(UserProfile me) {
    if (_loading && _clients.isEmpty && _machines.isEmpty && _deletions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ErrorFormatter.format(_error), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pendingDeletions = _deletions.where((r) => r.isPending).toList();
    final toReview = me.isSuperAdmin ? pendingDeletions : const <DeletionRequest>[];
    final mine = _deletions.where((r) => r.requestedBy == me.id).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionTitle('New submissions', count: _clients.length + _machines.length),
          if (_clients.isEmpty && _machines.isEmpty)
            const _EmptyNote('Nothing waiting for approval.'),
          for (final c in _clients)
            _ReviewCard(
              icon: Icons.local_hospital_rounded,
              kind: 'Client',
              title: c.name,
              subtitle: [
                if (c.district.isNotEmpty) c.district,
                c.division.label,
                c.facilityType.label,
              ].join(' · '),
              by: c.updatedByName,
              at: c.createdAt,
              busy: _busy.contains(c.id),
              onView: () => context.push('/clients/${c.id}'),
              approveLabel: 'Approve',
              onApprove: () => _reviewClient(c, true),
              onReject: () => _reviewClient(c, false),
            ),
          for (final p in _machines)
            _ReviewCard(
              icon: Icons.precision_manufacturing_rounded,
              kind: 'Machine',
              title: '${p.machine.brand} ${p.machine.model}',
              subtitle: '${p.machine.machineType.label} at ${p.clientName}',
              by: p.machine.updatedByName,
              at: p.machine.createdAt,
              busy: _busy.contains(p.machine.id),
              onView: () => context.push('/clients/${p.machine.hospitalId}/machine/${p.machine.id}'),
              approveLabel: 'Approve',
              onApprove: () => _reviewMachine(p, true),
              onReject: () => _reviewMachine(p, false),
            ),

          if (me.isSuperAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('Deletion requests', count: toReview.length),
            if (toReview.isEmpty) const _EmptyNote('No deletion requests waiting.'),
            for (final r in toReview)
              _ReviewCard(
                icon: Icons.delete_outline_rounded,
                kind: '${r.kindLabel} deletion',
                title: r.targetLabel,
                subtitle: (r.reason?.isNotEmpty ?? false) ? 'Reason: ${r.reason}' : null,
                by: r.requestedByName,
                at: r.createdAt,
                busy: _busy.contains(r.id),
                onView: r.targetLink == null ? null : () => context.push(r.targetLink!),
                approveLabel: 'Delete',
                approveIsDestructive: true,
                onApprove: () => _reviewDeletion(r, true),
                onReject: () => _reviewDeletion(r, false),
              ),
          ],

          if (!me.isSuperAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('My deletion requests', count: mine.where((r) => r.isPending).length),
            if (mine.isEmpty) const _EmptyNote('You have not requested any deletions.'),
            for (final r in mine) _MyRequestTile(request: r, onCancel: () => _cancelDeletion(r)),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Badge(label: Text('$count'), backgroundColor: AppColors.warning),
          ],
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.kind,
    required this.title,
    this.subtitle,
    this.by,
    required this.at,
    required this.busy,
    this.onView,
    required this.approveLabel,
    this.approveIsDestructive = false,
    required this.onApprove,
    required this.onReject,
  });

  final IconData icon;
  final String kind;
  final String title;
  final String? subtitle;
  final String? by;
  final DateTime at;
  final bool busy;
  final VoidCallback? onView;
  final String approveLabel;
  final bool approveIsDestructive;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final approveColor = approveIsDestructive ? AppColors.error : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1)),
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (by != null) 'By ${firstNameOf(by)}',
                          DateFormat('d MMM yyyy, h:mm a').format(at.toLocal()),
                        ].join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.end,
              children: [
                if (onView != null)
                  TextButton(onPressed: busy ? null : onView, child: const Text('View')),
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: approveColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(approveLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request, required this.onCancel});
  final DeletionRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final (label, color) = switch (r.status) {
      'approved' => ('Deleted', AppColors.success),
      'rejected' => ('Rejected', AppColors.error),
      _ => ('Waiting', AppColors.warning),
    };
    final note = (r.reviewNote?.isNotEmpty ?? false) ? ' — ${r.reviewNote}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        title: Text('${r.kindLabel}: ${r.targetLabel}'),
        subtitle: Text(
          r.isPending
              ? 'Requested ${DateFormat('d MMM yyyy').format(r.createdAt.toLocal())}'
              : '$label by ${firstNameOf(r.reviewedByName)}$note',
        ),
        trailing: r.isPending
            ? TextButton(onPressed: onCancel, child: const Text('Cancel'))
            : Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
