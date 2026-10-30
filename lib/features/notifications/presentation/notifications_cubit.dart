// lib/features/notifications/presentation/notifications_cubit.dart

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../approvals/data/repositories/approvals_repository.dart';
import '../../auth/data/models/user_profile.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/notifications_repository.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
    this.awaitingReview = 0,
  });

  final List<AppNotification> items;

  /// Submissions / deletion requests waiting for this admin (0 otherwise).
  final int awaitingReview;

  int get unread => items.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [items, awaitingReview];
}

/// Polls the inbox while someone is signed in, so badges stay current
/// without a realtime connection.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationsRepository repository,
    required ApprovalsRepository approvals,
    required AuthBloc authBloc,
  })  : _repo = repository,
        _approvals = approvals,
        super(const NotificationsState()) {
    _onAuth(authBloc.state);
    _authSub = authBloc.stream.listen(_onAuth);
  }

  static const _pollInterval = Duration(seconds: 30);

  final NotificationsRepository _repo;
  final ApprovalsRepository _approvals;
  late final StreamSubscription<AuthState> _authSub;
  Timer? _timer;
  UserProfile? _profile;

  void _onAuth(AuthState auth) {
    final profile = auth is AuthAuthenticated ? auth.profile : null;
    if (profile?.id == _profile?.id && profile?.role == _profile?.role) return;
    _profile = profile;
    _timer?.cancel();
    if (profile == null) {
      emit(const NotificationsState());
      return;
    }
    refresh();
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final items = await _repo.fetchRecent();
      final awaiting = profile.isAdmin
          ? await _approvals.countAwaitingReview(superAdmin: profile.isSuperAdmin)
          : 0;
      if (!isClosed && _profile?.id == profile.id) {
        emit(NotificationsState(items: items, awaitingReview: awaiting));
      }
    } catch (_) {
      // Offline or signed out mid-request: keep what we have, retry next tick.
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    emit(NotificationsState(
      items: [
        for (final item in state.items)
          item.id == n.id
              ? AppNotification(
                  id: item.id,
                  title: item.title,
                  body: item.body,
                  link: item.link,
                  isRead: true,
                  createdAt: item.createdAt,
                )
              : item,
      ],
      awaitingReview: state.awaitingReview,
    ));
    try {
      await _repo.markRead(n.id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    await refresh();
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    await refresh();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _authSub.cancel();
    return super.close();
  }
}
