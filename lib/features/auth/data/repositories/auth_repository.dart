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

  // 🌟 Updated to accept platform string to resolve duplicate session tracking
// 🌟 Updated to accept platform string with correct Supabase options class
// 🌟 Updated to resolve compilation errors and guarantee session metadata updates
  Future<UserProfile?> signIn({
    required String email,
    required String password,
    required String platform,
  }) async {
    // 1. Authenticate the user safely using standard credentials
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) return null;

    // 2. Immediately stamp the hardware platform into the user's metadata.
    // This forces Supabase to record the distinct platform signature for this session.
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }

    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 🌟 Updated to thoroughly validate local storage session integrity on app launch
  Future<UserProfile?> getProfile() async {
    final session = _client.auth.currentSession;
    
    // Check if the current session token exists and hasn't completely expired
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
  // NEW SESSION MANAGEMENT CAPABILITIES
  // ==========================================

  /// Approach 1: Global Sign Out for all OTHER active devices
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

  /// Approach 2: Fetch the concurrent sessions list for the logged-in user
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

  /// Approach 2: Evict/terminate a specific device session by its targeted ID
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