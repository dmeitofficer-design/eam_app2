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

  Future<void> registerWithAdminApproval({
    required String email,
    required String password,
    required String role,
    required String adminEmail,
    required String adminPassword,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'medtrack://login', 
      data: {
        'role': role, 
      },
    );

    if (response.user == null) {
      throw const AuthException('Registration failed: Could not generate a valid account.');
    }
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
    final session = _client.auth.currentSession;
    
    if (session == null || session.isExpired) {
      return null;
    }
    
    return _fetchProfile(session.user.id);
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
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
      throw AuthException("Failed to terminate other sessions: ${e.toString()}");
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
      throw AuthException("Failed to retrieve active devices: ${e.toString()}");
    }
  }

  Future<void> removeSession(String sessionId) async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }
    try {
      await _client.rpc('terminate_session', params: {
        'target_session_id': sessionId,
      });
    } catch (e) {
      throw AuthException("Failed to evict targeted device session: ${e.toString()}");
    }
  }
}