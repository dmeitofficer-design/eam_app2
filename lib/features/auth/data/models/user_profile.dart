import 'package:equatable/equatable.dart';

enum AppRole { superAdmin, admin, user }

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

  /// True for both admin and superAdmin (grants UI access to management pages)
  bool get isAdmin => role == AppRole.admin || role == AppRole.superAdmin;

  /// True ONLY for superAdmin (used to gate delete actions)
  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get canDelete => role == AppRole.superAdmin;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String?;
    AppRole parsedRole;

    switch (roleStr?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        parsedRole = AppRole.superAdmin;
        break;
      case 'admin':
        parsedRole = AppRole.admin;
        break;
      default:
        parsedRole = AppRole.user;
    }

    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      role: parsedRole,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, fullName, role];
}