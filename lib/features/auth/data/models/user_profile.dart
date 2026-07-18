// lib/features/auth/data/models/user_profile.dart

import 'package:equatable/equatable.dart';

enum AppRole { admin, user }

class UserProfile extends Equatable {
  final String id;
  final String? fullName;
  final AppRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == AppRole.admin;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] == 'admin' ? AppRole.admin : AppRole.user,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, fullName, role];
}
