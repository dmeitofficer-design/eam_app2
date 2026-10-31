// lib/features/notifications/data/notifications_repository.dart

import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notification. Rows are created by database triggers.
class AppNotification extends Equatable {
  final String id;
  final String title;
  final String? body;

  /// App route to open when tapped, e.g. `/approvals` or `/clients/<id>`.
  final String? link;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.link,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        link: json['link'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, isRead];
}

class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'notifications';

  Future<List<AppNotification>> fetchRecent({int limit = 50}) async {
    final data = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from(_table).update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(_table)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> clearAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from(_table).delete().eq('user_id', userId);
  }
}
