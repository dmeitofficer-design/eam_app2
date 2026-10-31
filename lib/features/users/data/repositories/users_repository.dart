// lib/features/users/data/repositories/users_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/error_formatter.dart';

/// User administration. Creating, banning and deleting accounts needs the
/// service-role key, so those go through the `manage-users` Edge Function.
class UsersRepository {
  UsersRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _function = 'manage-users';

  Future<List<UserProfile>> fetchUsers() async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select('id, full_name, email, role, is_banned, created_at')
        .order('full_name', ascending: true);
    return (data as List<dynamic>)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createUser({
    required String fullName,
    required String email,
    required String password,
    required AppRole role,
  }) =>
      _invoke({
        'action': 'create',
        'full_name': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'role': role.value,
      });

  Future<void> setBanned(String userId, bool banned) =>
      _invoke({'action': banned ? 'ban' : 'unban', 'user_id': userId});

  Future<void> deleteUser(String userId) =>
      _invoke({'action': 'delete', 'user_id': userId});

  /// Name and role edits; the database checks the caller may make them.
  Future<void> updateUser(String userId, {String? fullName, AppRole? role}) async {
    await _client.from(AppConstants.tableProfiles).update({
      if (fullName != null) 'full_name': fullName.trim(),
      if (role != null) 'role': role.value,
    }).eq('id', userId);
  }

  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(_function, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw AppException(data['error'].toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'Request failed (${e.status}).');
      throw AppException(message);
    }
  }
}
