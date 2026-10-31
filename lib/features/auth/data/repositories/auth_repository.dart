// lib/features/auth/data/repositories/auth_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../../../../core/constants/app_constants.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<UserProfile?> signIn({
    required String email,
    required String password,
    required String platform,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) return null;

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'source_platform': platform,
        },
      ),
    );

    return _fetchProfile(response.user!.id);
  }

  // ==========================================
  // PASSWORD RESET (email code)
  // ==========================================

  /// Emails a one-time recovery code. The Supabase "Reset Password" email
  /// template must include {{ .Token }} for the code to appear.
  Future<void> sendPasswordResetCode(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Signs the user in with the emailed code, then sets [newPassword].
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Saves the signed-in user's display name.
  Future<UserProfile> updateFullName(String fullName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('No active user session detected.');
    }
    await _client
        .from(AppConstants.tableProfiles)
        .update({'full_name': fullName.trim()})
        .eq('id', user.id);
    return _fetchProfile(user.id);
  }

  /// Changes password after re-authenticating the user with currentPassword
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('No active user session detected.');
    }

    // 1. Validate current password by attempting re-authentication
    try {
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
    } on AuthException {
      throw const AuthException('Incorrect current password. Please try again.');
    } catch (e) {
      throw AuthException('Failed to verify current password: ${e.toString()}');
    }

    // 2. Proceed with updating the password only if re-authentication succeeded
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserProfile?> getProfile() async {
    var session = _client.auth.currentSession;

    if (session == null) {
      return null;
    }

    // On a cold start Supabase restores the stored session immediately but
    // refreshes an expired access token in the background. Wait for a fresh
    // token here instead of treating the user as logged out.
    if (session.isExpired) {
      final response = await _client.auth.refreshSession();
      session = response.session;
      if (session == null) return null;
    }

    // Confirm the session still exists on the server (it may have been
    // terminated from another device).
    await validateSession();

    return _fetchProfile(session.user.id);
  }

  /// Asks the auth server whether the current session is still valid.
  /// Throws an [AuthException] if it was revoked or expired.
  Future<void> validateSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw const AuthException('No active user session detected.');
    }
    await _client.auth.getUser(session.accessToken);
  }

  /// True when [e] means the session no longer exists on the server,
  /// as opposed to a temporary network failure.
  bool isSessionRevoked(Object e) {
    if (e is! AuthException || e is AuthRetryableFetchException) return false;
    const revokedCodes = {
      'session_not_found',
      'session_expired',
      'refresh_token_not_found',
      'refresh_token_already_used',
      'user_not_found',
      'bad_jwt',
    };
    return revokedCodes.contains(e.code) ||
        e.statusCode == '401' ||
        e.statusCode == '403';
  }

  /// Clears the session stored on this device only.
  Future<void> signOutLocally() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The server-side session is already gone; local state is cleared anyway.
    }
  }

  Future<UserProfile> _fetchProfile(String userId) async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .single();
    return UserProfile.fromJson(data);
  }

  // ==========================================
  // SESSION MANAGEMENT
  // ==========================================

  Future<void> logOutOtherDevices() async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }
    try {
      await _client.auth.signOut(scope: SignOutScope.others);
    } catch (e) {
      throw AuthException('Failed to terminate other sessions: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchActiveSessions() async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }
    try {
      final data = await _client
          .from('active_user_sessions')
          .select('session_id, login_time, last_active');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw AuthException('Failed to retrieve active devices: ${e.toString()}');
    }
  }

  Future<void> removeSession(String sessionId) async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }
    try {
      await _client.rpc('terminate_session', params: {
        'target_session_id': sessionId,
      },);
    } catch (e) {
      throw AuthException('Failed to evict targeted device session: ${e.toString()}');
    }
  }
}