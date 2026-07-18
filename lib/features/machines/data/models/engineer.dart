// lib/features/machines/data/models/engineer.dart

import 'package:equatable/equatable.dart';



// lib/features/machines/data/models/engineer.dart

class Engineer extends Equatable {
  final String id;
  final String? machineId; 
  final String name;
  final String? phone; // Matches 'phone' column from your SQL
  final bool isAvailable; // Matches 'is_available' boolean from your SQL
  final DateTime createdAt;

  const Engineer({
    required this.id,
    this.machineId,        
    required this.name,
    this.phone,
    required this.isAvailable,
    required this.createdAt,
  });

  // UI Helper to easily display status as text
  String get statusLabel => isAvailable ? 'Available' : 'On Assignment';

  @override
  List<Object?> get props => [
        id,
        machineId,
        name,
        phone,
        isAvailable,
        createdAt,
      ];

  factory Engineer.fromJson(Map<String, dynamic> json) {
    return Engineer(
      id: json['id'] as String,
      machineId: json['machine_id'] as String?, 
      name: json['name'] as String,
      phone: json['phone'] as String?,
      isAvailable: json['is_available'] as bool? ?? true, // Safely fallback to true
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'machine_id': machineId, 
      'name': name,
      'phone': phone,
      'is_available': isAvailable, // Directly sends a boolean to PostgreSQL
      'created_at': createdAt.toIso8601String(),
    };
  }

  Engineer copyWith({
    String? id,
    String? machineId,
    String? name,
    String? phone,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return Engineer(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}