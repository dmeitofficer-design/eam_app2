// lib/features/dashboard/data/models/dashboard_analytics.dart

import 'package:equatable/equatable.dart';

/// A newly added client, for the Total Clients card.
class LatestClient extends Equatable {
  const LatestClient({required this.id, required this.name, required this.division});
  final String id;
  final String name;
  final String division;

  @override
  List<Object?> get props => [id, name, division];
}

/// A recent installation, for the Installed Machines card.
class LatestInstall extends Equatable {
  const LatestInstall({
    required this.machineId,
    required this.clientId,
    required this.title,
    required this.clientName,
  });
  final String machineId;
  final String clientId;

  /// Brand and model, e.g. "Genoray Oscar Prime".
  final String title;
  final String clientName;

  @override
  List<Object?> get props => [machineId, clientId, title, clientName];
}

class DashboardAnalytics extends Equatable {
  final int totalClients;
  final int activeBrands;
  final int totalDivisions;
  final int availableEngineers;
  final int totalMachines;

  /// Client counts per facility type, in display order (label, count).
  final List<(String, int)> clientsByType;
  final int districtsCovered;
  final int inWarranty;
  final int outOfWarranty;
  final List<LatestClient> latestClients;
  final List<LatestInstall> latestInstalls;

  const DashboardAnalytics({
    required this.totalClients,
    required this.activeBrands,
    required this.totalDivisions,
    required this.availableEngineers,
    required this.totalMachines,
    this.clientsByType = const [],
    this.districtsCovered = 0,
    this.inWarranty = 0,
    this.outOfWarranty = 0,
    this.latestClients = const [],
    this.latestInstalls = const [],
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
        clientsByType,
        districtsCovered,
        inWarranty,
        outOfWarranty,
        latestClients,
        latestInstalls,
      ];
}
