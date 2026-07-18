// lib/features/machines/data/models/engineer.dart

import 'package:equatable/equatable.dart';

enum EngineerStatus {
  available('Available'),
  onAssignment('On Assignment'),
  onLeave('On Leave');

  const EngineerStatus(this.label);
  final String label;

  static EngineerStatus fromString(String value) =>
      EngineerStatus.values.firstWhere(
        (e) => e.label.toLowerCase() == value.toLowerCase() || 
               e.name.toLowerCase() == value.toLowerCase(),
        orElse: () => EngineerStatus.available,
      );
}

class Engineer extends Equatable {
  final String id;
  final String? machineId;      // Made optional to match form sheets
  final String name;
  final String? designation;    // Made optional for flexible registration
  final String? phone;          // Restored missing field used by views
  final EngineerStatus status;
  final DateTime createdAt;

  const Engineer({
    required this.id,
    this.machineId,
    required this.name,
    this.designation,
    this.phone,
    this.status = EngineerStatus.available,
    required this.createdAt,
  });

  /// Helper utility for boolean layout adjustments in views
  bool get isAvailable => status == EngineerStatus.available;

  /// Compatibility layer helper property for engineers list views
  String get statusLabel => status.label;

  factory Engineer.fromJson(Map<String, dynamic> json) => Engineer(
        id: json['id'] as String,
        machineId: json['machine_id'] as String?,
        name: json['name'] as String,
        designation: json['designation'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] != null 
            ? EngineerStatus.fromString(json['status'] as String)
            : EngineerStatus.available,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        if (machineId != null) 'machine_id': machineId,
        'name': name,
        if (designation != null) 'designation': designation,
        if (phone != null) 'phone': phone,
        'status': status.name, // Matches clean Postgres DB text conventions
      };

  /// CopyWith helper function to safely modify instances inside the repositories
  Engineer copyWith({
    String? id,
    String? machineId,
    String? name,
    String? designation,
    String? phone,
    EngineerStatus? status,
    DateTime? createdAt,
  }) {
    return Engineer(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, machineId, name, designation, phone, status, createdAt];
}