// lib/features/machines/data/models/machine_part.dart

import 'package:equatable/equatable.dart';

class MachinePart extends Equatable {
  final String id;
  final String machineId;
  final String partName;
  final String serialNumber;
  final DateTime createdAt;

  const MachinePart({
    required this.id,
    required this.machineId,
    required this.partName,
    required this.serialNumber,
    required this.createdAt,
  });

  factory MachinePart.fromJson(Map<String, dynamic> json) => MachinePart(
        id: json['id'] as String,
        machineId: json['machine_id'] as String,
        partName: json['part_name'] as String,
        serialNumber: json['serial_number'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'part_name': partName,
        'serial_number': serialNumber,
      };

  /// Temporary local-only draft before it is saved to DB
  factory MachinePart.draft({
    required String partName,
    required String serialNumber,
  }) =>
      MachinePart(
        id: '',
        machineId: '',
        partName: partName,
        serialNumber: serialNumber,
        createdAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, machineId, partName, serialNumber];
}
