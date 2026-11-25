// lib/features/trash/presentation/trash_screen.dart
//
// Super admins: everything deleted in the last few days. Restore it, or
// delete it for good. The database purges it after the retention period.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/feedback.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/trash_repository.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _repo = TrashRepository();
  List<TrashBatch> _batches = const [];
  int _days = 3;
  bool _loading = true;
  int? _busy;
  String? _error;

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
      final results = await Future.wait([_repo.getBatches(), _repo.getRetentionDays()]);
      if (!mounted) return;
      setState(() {
        _batches = results[0] as List<TrashBatch>;
        _days = results[1] as int;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(TrashBatch b, {required bool restore}) async {
    if (!restore) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Delete "${b.label}" for good?',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete for good',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = b.batch);
    try {
      restore ? await _repo.restore(b.batch) : await _repo.deleteForGood(b.batch);
      if (!mounted) return;
      AppFeedback.success(context, restore ? '"${b.label}" restored.' : '"${b.label}" deleted for good.');
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _pickDays() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Keep deleted items for')),
            for (final d in const [1, 3, 7, 14, 30])
              ListTile(
                title: Text(d == 1 ? '1 day' : '$d days'),
                trailing: d == _days ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(c, d),
              ),
          ],
        ),
      ),
    );
    if (days == null || days == _days || !mounted) return;
    try {
      await _repo.setRetentionDays(days);
      if (!mounted) return;
      setState(() => _days = days);
      AppFeedback.success(context, 'Deleted items are now kept for $days days.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _pickDays,
            icon: const Icon(Icons.timer_outlined, size: 18),
            label: Text('Keep $_days ${_days == 1 ? 'day' : 'days'}'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading && _batches.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _batches.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing in the trash.\nDeleted items stay here for $_days days.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _batches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final b = _batches[i];
                        final purge = b.deletedAt.add(Duration(days: _days));
                        final left = purge.difference(DateTime.now());
                        final leftText = left.inHours < 1
                            ? 'deleted for good within the hour'
                            : left.inHours < 48
                                ? 'deleted for good in ${left.inHours} h'
                                : 'deleted for good in ${left.inDays} days';
                        final busy = _busy == b.batch;
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: AppRadius.card,
                            border: Border.all(color: AppColors.surface2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b.kind} · ${b.label}', style: theme.textTheme.titleSmall),
                              if (b.extraRows > 0)
                                Text(
                                  'With ${b.extraRows} linked ${b.extraRows == 1 ? 'row' : 'rows'} '
                                  '(parts, items, serials…)',
                                  style: theme.textTheme.bodySmall,
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Deleted by ${b.deletedByName ?? 'unknown'} · '
                                '${fmt.format(b.deletedAt.toLocal())} · $leftText',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: busy ? null : () => _act(b, restore: false),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                    child: const Text('Delete for good'),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  FilledButton.icon(
                                    onPressed: busy ? null : () => _act(b, restore: true),
                                    icon: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.restore_rounded, size: 18),
                                    label: const Text('Restore'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
