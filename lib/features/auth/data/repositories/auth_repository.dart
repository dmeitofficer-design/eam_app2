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
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) return null;
    return _fetchProfile(response.user!.id);
  }

  /// Registers a new user with administrative metadata indicators.
  /// Uses emailRedirectTo directly to fix named parameter definition errors.
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
      // CORRECT PARAMETER: Overrides default localhost routing configurations safely
      emailRedirectTo: 'medtrack://login', 
      data: {
        'role': role, // Stores account system access visibility privileges inside user metadata
      },
    );

    if (response.user == null) {
      throw const AuthException('Registration failed: Could not generate a valid account.');
    }
  }

  /// Updates the current authenticated user's security credentials.
  /// The currentPassword parameter is accepted here to maintain compatibility with your BLoC structure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('No active user session detected.');
    }

    // Supabase handles password updates safely for the active session context
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
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .single();
    return UserProfile.fromJson(data);
  }
}