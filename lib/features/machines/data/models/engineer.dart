// lib/features/machines/data/models/engineer.dart

import 'package:equatable/equatable.dart';

class Engineer extends Equatable {
  final String id;
  final String? machineId;      // Optional; only used when assigning via a machine form
  final String name;
  final String? designation;    // e.g. "Senior Field Engineer"
  final String? phone;
  final bool isAvailable;       // Available for assignment vs currently on duty
  final bool isActive;          // Current employee vs left the company / inactive
  final DateTime createdAt;

  const Engineer({
    required this.id,
    this.machineId,
    required this.name,
    this.designation,
    this.phone,
    this.isAvailable = true,
    this.isActive = true,
    required this.createdAt,
  });

  /// Compatibility label used by list views showing availability.
  String get statusLabel => isAvailable ? 'Available' : 'On Assignment';

  factory Engineer.fromJson(Map<String, dynamic> json) => Engineer(
        id: json['id'] as String,
        machineId: json['machine_id'] as String?,
        name: json['name'] as String,
        designation: json['designation'] as String?,
        phone: json['phone'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        if (machineId != null) 'machine_id': machineId,
        'name': name,
        'designation': designation,
        if (phone != null) 'phone': phone,
        'is_available': isAvailable,
        'is_active': isActive,
      };

  /// CopyWith helper function to safely modify instances inside the repositories
  Engineer copyWith({
    String? id,
    String? machineId,
    String? name,
    String? designation,
    String? phone,
    bool? isAvailable,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Engineer(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, machineId, name, designation, phone, isAvailable, isActive, createdAt];
}