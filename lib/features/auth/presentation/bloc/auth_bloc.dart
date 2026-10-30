// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../../core/utils/error_formatter.dart'; // 🌟 Added ErrorFormatter import
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

// ── Events ──────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String platform;

  const AuthLoginRequested({
    required this.email, 
    required this.password,
    required this.platform,
  });

  @override
  List<Object?> get props => [email, password, platform];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String role;
  final String adminEmail;
  final String adminPassword;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.role,
    required this.adminEmail,
    required this.adminPassword,
  });

  @override
  List<Object?> get props => [email, password, role, adminEmail, adminPassword];
}

class AuthLogoutRequested extends AuthEvent {}

/// Re-checks with the server that the current session has not been revoked.
class AuthSessionCheckRequested extends AuthEvent {}

class _AuthStateChanged extends AuthEvent {
  final sb.AuthState authState;
  const _AuthStateChanged(this.authState);
  @override
  List<Object?> get props => [authState];
}

// ── States ───────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserProfile profile;
  const AuthAuthenticated(this.profile);
  @override
  List<Object?> get props => [profile];
}

class AuthUnauthenticated extends AuthState {}

class AuthRegisterSuccess extends AuthState {
  const AuthRegisterSuccess();
  @override
  List<Object?> get props => [];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
      : _repo = authRepository,
        super(AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionCheckRequested>(_onSessionCheckRequested);
    on<_AuthStateChanged>(_onAuthStateChanged);

    _authSub = _repo.authStateChanges.listen(
      (state) => add(_AuthStateChanged(state)),
    );

    // Sessions terminated from another device stay usable until the access
    // token expires, so poll the auth server to log out promptly.
    _sessionCheckTimer = Timer.periodic(
      _sessionCheckInterval,
      (_) => add(AuthSessionCheckRequested()),
    );
  }

  static const _sessionCheckInterval = Duration(minutes: 1);

  final AuthRepository _repo;
  late final StreamSubscription _authSub;
  late final Timer _sessionCheckTimer;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final profile = await _repo.getProfile();
      if (profile != null) {
        emit(AuthAuthenticated(profile));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (_repo.isSessionRevoked(e)) await _repo.signOutLocally();
      // Gracefully fall back to login on startup failure/offline launch
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSessionCheckRequested(
    AuthSessionCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) return;
    try {
      await _repo.validateSession();
    } catch (e) {
      // Offline or server hiccup: keep the user logged in and retry later.
      if (!_repo.isSessionRevoked(e)) return;
      await _repo.signOutLocally();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final profile = await _repo.signIn(
        email: event.email,
        password: event.password,
        platform: event.platform, 
      );
      if (profile != null) {
        emit(AuthAuthenticated(profile));
      } else {
        emit(const AuthError('Login failed. Check your credentials.'));
      }
    } on sb.AuthException catch (e) {
      // 🌟 Formats Supabase Auth Exceptions safely
      emit(AuthError(ErrorFormatter.format(e)));
    } catch (e) {
      // 🌟 Intercepts SocketException / ClientException / Timeout
      emit(AuthError(ErrorFormatter.format(e)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _repo.registerWithAdminApproval(
        email: event.email,
        password: event.password,
        role: event.role,
        adminEmail: event.adminEmail,
        adminPassword: event.adminPassword,
      );
      emit(const AuthRegisterSuccess());
    } on sb.AuthException catch (e) {
      emit(AuthError(ErrorFormatter.format(e)));
    } catch (e) {
      emit(AuthError(ErrorFormatter.format(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repo.signOut();
    } catch (_) {
      // Even if offline during logout call, reset local state safely
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthStateChanged(
    _AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.authState.event == sb.AuthChangeEvent.signedOut) {
      emit(AuthUnauthenticated());
    } else if (event.authState.event == sb.AuthChangeEvent.signedIn ||
        (event.authState.event == sb.AuthChangeEvent.tokenRefreshed &&
            state is AuthUnauthenticated)) {
      // tokenRefreshed: a background refresh finished after startup had
      // already given up on the session, so restore the logged-in state.
      final userId = event.authState.session?.user.id;
      if (userId == null) {
        emit(AuthUnauthenticated());
        return;
      }
      try {
        final profile = await _repo.getProfile();
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    }
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    _sessionCheckTimer.cancel();
    return super.close();
  }
}