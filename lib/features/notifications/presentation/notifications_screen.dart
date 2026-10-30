// lib/features/notifications/presentation/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/feedback.dart';
import '../data/notifications_repository.dart';
import 'notifications_cubit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().refresh();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    }
  }

  void _open(AppNotification n) {
    final cubit = context.read<NotificationsCubit>();
    cubit.markRead(n);
    final link = n.link;
    if (link != null && link.isNotEmpty) context.push(link);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) => PopupMenuButton<String>(
              enabled: state.items.isNotEmpty,
              onSelected: (value) {
                if (value == 'read') _guard(cubit.markAllRead);
                if (value == 'clear') _guard(cubit.clearAll);
              },
              itemBuilder: (_) => [
                if (state.unread > 0)
                  const PopupMenuItem(value: 'read', child: Text('Mark all as read')),
                const PopupMenuItem(value: 'clear', child: Text('Clear all')),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: cubit.refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  const Center(child: Text("You're all caught up.")),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _NotificationTile(
                notification: state.items[i],
                onTap: () => _open(state.items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;
    final muted = theme.colorScheme.onSurface.withOpacity(0.5);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        n.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
        color: n.isRead ? muted : AppColors.accent,
      ),
      title: Text(
        n.title,
        style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.body != null && n.body!.isNotEmpty) Text(n.body!),
          Text(
            DateFormat('d MMM, h:mm a').format(n.createdAt.toLocal()),
            style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10),
          ),
        ],
      ),
      trailing: n.link != null ? const Icon(Icons.chevron_right_rounded) : null,
    );
  }
}

/// Bell with unread count; opens the notifications screen.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (p, c) => p.unread != c.unread,
      builder: (context, state) => IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
        icon: Badge(
          isLabelVisible: state.unread > 0,
          label: Text(state.unread > 99 ? '99+' : '${state.unread}'),
          child: Icon(Icons.notifications_rounded, color: color),
        ),
      ),
    );
  }
}
