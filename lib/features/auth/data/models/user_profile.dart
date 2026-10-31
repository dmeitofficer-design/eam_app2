import 'package:equatable/equatable.dart';

/// Ordered lowest → highest access.
enum AppRole {
  viewer('user', 'Viewer'),
  dataEntry('data_entry', 'Data Entry'),
  admin('admin', 'Admin'),
  superAdmin('super_admin', 'Super Admin');

  const AppRole(this.value, this.label);

  /// Value stored in the database `app_role` enum.
  final String value;
  final String label;

  static AppRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return AppRole.superAdmin;
      case 'admin':
        return AppRole.admin;
      case 'data_entry':
        return AppRole.dataEntry;
      default:
        return AppRole.viewer;
    }
  }

  bool operator >=(AppRole other) => index >= other.index;
}

class UserProfile extends Equatable {
  final String id;
  final String? fullName;
  final String? email;
  final AppRole role;
  final bool isBanned;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    this.email,
    required this.role,
    this.isBanned = false,
    required this.createdAt,
  });

  /// Admin or super admin: management pages, approvals, full machine details.
  bool get isAdmin => role >= AppRole.admin;

  /// True ONLY for superAdmin (used to gate delete actions)
  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get canDelete => role == AppRole.superAdmin;

  /// May add clients and machines (data entry's need approval).
  bool get canSubmit => role >= AppRole.dataEntry;

  /// Submissions from this user wait for an admin's approval.
  bool get needsApproval => role == AppRole.dataEntry;

  /// Technical machine config (PC, network, licenses, invoice) is admin-only.
  bool get canSeeMachineDetails => isAdmin;

  bool get hasName => fullName != null && fullName!.trim().isNotEmpty;

  /// Name for display, falling back to the email.
  String get displayName => hasName ? fullName!.trim() : (email ?? 'User');

  /// Roles this user may assign when creating or editing other users.
  List<AppRole> get assignableRoles => switch (role) {
        AppRole.superAdmin => const [AppRole.viewer, AppRole.dataEntry, AppRole.admin],
        AppRole.admin => const [AppRole.viewer, AppRole.dataEntry],
        _ => const [],
      };

  /// Whether this user may edit [other] (name/role) from User Management.
  bool canManage(UserProfile other) =>
      other.id != id && (isSuperAdmin || (isAdmin && role.index > other.role.index));

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      role: AppRole.fromString(json['role'] as String?),
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  UserProfile copyWith({String? fullName, AppRole? role, bool? isBanned}) =>
      UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email,
        role: role ?? this.role,
        isBanned: isBanned ?? this.isBanned,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, fullName, email, role, isBanned];
}

/// First word of a person's name, for compact "updated by" labels.
String firstNameOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final first = trimmed.split(RegExp(r'\s+')).first;
  // Emails stored as a fallback name: show the part before '@'.
  return first.split('@').first;
}
