// lib/features/config/data/models/machine_config.dart

import 'package:equatable/equatable.dart';

class MachineConfig extends Equatable {
  final String id;
  final String configType; // 'genre' | 'brand' | 'machine_type'
  final String value;
  final int sortOrder;
  final bool isActive;

  const MachineConfig({
    required this.id,
    required this.configType,
    required this.value,
    required this.sortOrder,
    required this.isActive,
  });

  factory MachineConfig.fromJson(Map<String, dynamic> json) => MachineConfig(
        id: json['id'] as String,
        configType: json['config_type'] as String,
        value: json['value'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'config_type': configType,
        'value': value,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [id, configType, value];
}
