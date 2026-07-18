// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
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
  const AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

// Added missing Registration Event to handle signup details from the form
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

// Added missing Registration Success State to safely trigger UI view toggle
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
    on<AuthRegisterRequested>(_onRegisterRequested); // Registered the new event handler
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<_AuthStateChanged>(_onAuthStateChanged);

    // Listen to Supabase auth state stream
    _authSub = _repo.authStateChanges.listen(
      (state) => add(_AuthStateChanged(state)),
    );
  }

  final AuthRepository _repo;
  late final StreamSubscription _authSub;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
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

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final profile = await _repo.signIn(
        email: event.email,
        password: event.password,
      );
      if (profile != null) {
        emit(AuthAuthenticated(profile));
      } else {
        emit(const AuthError('Login failed. Check your credentials.'));
      }
    } on sb.AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Unexpected error: ${e.toString()}'));
    }
  }

  // Implemented Registration Request Handler
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // NOTE: Make sure your AuthRepository implementation matches this method call signature.
      // If your repository uses different naming (e.g. register, signUp), change this line below:
      await _repo.registerWithAdminApproval(
        email: event.email,
        password: event.password,
        role: event.role,
        adminEmail: event.adminEmail,
        adminPassword: event.adminPassword,
      );

      // Alternatively, if testing direct Supabase communication bypassing the repo:
      // await sb.Supabase.instance.client.auth.signUp(email: event.email, password: event.password);

      emit(const AuthRegisterSuccess());
    } on sb.AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Registration unexpected error: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthStateChanged(
    _AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.authState.event == sb.AuthChangeEvent.signedOut) {
      emit(AuthUnauthenticated());
    } else if (event.authState.event == sb.AuthChangeEvent.signedIn) {
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
    return super.close();
  }
}