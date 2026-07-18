// lib/features/dashboard/data/models/dashboard_analytics.dart

import 'package:equatable/equatable.dart';

class DashboardAnalytics extends Equatable {
  final int totalClients;
  final int activeBrands;
  final int totalDivisions;
  final int availableEngineers;
  final int totalMachines;

  const DashboardAnalytics({
    required this.totalClients,
    required this.activeBrands,
    required this.totalDivisions,
    required this.availableEngineers,
    required this.totalMachines,
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) =>
      DashboardAnalytics(
        totalClients: (json['total_clients'] as num?)?.toInt() ?? 0,
        activeBrands: (json['active_brands'] as num?)?.toInt() ?? 0,
        totalDivisions: (json['total_divisions'] as num?)?.toInt() ?? 0,
        availableEngineers: (json['available_engineers'] as num?)?.toInt() ?? 0,
        totalMachines: (json['total_machines'] as num?)?.toInt() ?? 0,
      );

  factory DashboardAnalytics.empty() => const DashboardAnalytics(
        totalClients: 0,
        activeBrands: 0,
        totalDivisions: 0,
        availableEngineers: 0,
        totalMachines: 0,
      );

  @override
  List<Object?> get props => [
        totalClients,
        activeBrands,
        totalDivisions,
        availableEngineers,
        totalMachines,
      ];
}
