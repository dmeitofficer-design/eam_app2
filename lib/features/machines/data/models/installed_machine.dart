import 'package:equatable/equatable.dart';
import 'engineer.dart';
import 'machine_part.dart';

enum MachineType {
  xRay('X-ray'),
  ultrasonogram('Ultrasonogram'),
  fpd('FPD'),
  printer('Printer'),
  opg('OPG');

  const MachineType(this.label);
  final String label;

  static MachineType fromString(String value) =>
      MachineType.values.firstWhere(
        (e) => e.label.toLowerCase() == value.toLowerCase(),
        orElse: () => MachineType.xRay,
      );
}

class InstalledMachine extends Equatable {
  final String id;
  final String hospitalId;
  final MachineType machineType;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? installationEngineerName;
  final String? installationEngineerId; // Added for relational engineer tracking[cite: 3]
  final DateTime installationDate;
  final int warrantyPeriod; // months
  final String? invoiceUrl;
  final String? notes;
  final DateTime createdAt;

  // PC Configuration Features
  final String? pcCpu;
  final String? pcRam;
  final String? pcStorage;
  final String? pcOs;
  final String? pcMobo; // Added for motherboard configuration
  final int? pcLanPorts; // Added for network configuration ports count

  // Network Configuration (Dynamic array support)
  final List<String> assignedIps;

  // ── CONDITIONAL FIELD SYSTEM SPECIFICATIONS ──────────────────
  // Printer Specific
  final String? printerAe;
  final String? printerIp1;
  final String? printerIp2;
  final String? printerPort;
  final String? printerPcVersion;
  final String? printerMbVersion;
  final String? printerImagerVersion;

  // X-ray Specific
  final String? xrayConsoleSl;
  final String? xrayTubeSl;
  final String? xrayGeneratorSl;

  // FPD Specific
  final String? fpdAcqId;
  final String? fpdSoftware;
  final String? fpdVersion;
  final String? fpdModule;
  final String? fpdLicense;
  final String? fpdLicenseType; // Added for license categorization (e.g., Permanent, Demo)
  final String? fpdDongleSerial; // Added for physical dongle tracking

  // Scalability Property: Dynamic Extra Parameters
  final Map<String, String> customMetadata;

  final List<Engineer> engineers;
  final List<MachinePart> parts;

  const InstalledMachine({
    required this.id,
    required this.hospitalId,
    required this.machineType,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.installationEngineerName,
    this.installationEngineerId, // Added
    required this.installationDate,
    required this.warrantyPeriod,
    this.invoiceUrl,
    this.notes,
    required this.createdAt,
    this.pcCpu,
    this.pcRam,
    this.pcStorage,
    this.pcOs,
    this.pcMobo, // Added
    this.pcLanPorts, // Added
    this.assignedIps = const [],
    this.printerAe,
    this.printerIp1,
    this.printerIp2,
    this.printerPort,
    this.printerPcVersion,
    this.printerMbVersion,
    this.printerImagerVersion,
    this.xrayConsoleSl,
    this.xrayTubeSl,
    this.xrayGeneratorSl,
    this.fpdAcqId,
    this.fpdSoftware,
    this.fpdVersion,
    this.fpdModule,
    this.fpdLicense,
    this.fpdLicenseType, // Added
    this.fpdDongleSerial, // Added
    this.customMetadata = const {},
    this.engineers = const [],
    this.parts = const [],
  });

  DateTime get warrantyExpiryDate => DateTime(
        installationDate.year,
        installationDate.month + warrantyPeriod,
        installationDate.day,
      );

  int get warrantyLeftMonths {
    final now = DateTime.now();
    if (now.isAfter(warrantyExpiryDate)) return 0;
    final diff = warrantyExpiryDate.difference(now);
    return (diff.inDays / 30.44).floor();
  }

  double get warrantyProgressFraction {
    final total = warrantyPeriod;
    if (total <= 0) return 1.0;
    final elapsed = warrantyPeriod - warrantyLeftMonths;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  bool get isWarrantyActive => warrantyLeftMonths > 0;
  bool get isWarrantyExpiringSoon =>
      warrantyLeftMonths > 0 && warrantyLeftMonths <= 3;

factory InstalledMachine.fromJson(Map<String, dynamic> json) {
  // FIX: Handle nested engineers from the junction table
  final junctionData = json['machine_engineers'] as List<dynamic>? ?? [];
  
  // Each item in junctionData is a map like: {'engineers': {...}}
  final engineers = junctionData
      .map((item) => Engineer.fromJson(item['engineers'] as Map<String, dynamic>))
      .toList();
    
  final partsJson = json['machine_parts'] as List<dynamic>? ?? [];
  final ipsJson = json['assigned_ips'] as List<dynamic>? ?? [];
  
  // Parse scalable meta block safely
  final metaJson = json['custom_metadata'] as Map<String, dynamic>? ?? {};
  final parsedMeta = metaJson.map((k, v) => MapEntry(k, v.toString()));

  return InstalledMachine(
    id: json['id'] as String,
    hospitalId: json['hospital_id'] as String,
    machineType: MachineType.fromString(json['machine_type'] as String),
    brand: json['brand'] as String,
    model: json['model'] as String,
    serialNumber: json['serial_number'] as String?,
    installationEngineerName: json['installation_engineer_name'] as String?,
    installationEngineerId: json['installation_engineer_id'] as String?, 
    installationDate: DateTime.parse(json['installation_date'] as String),
    warrantyPeriod: json['warranty_period'] as int,
    invoiceUrl: json['invoice_url'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    
    pcCpu: json['pc_cpu'] as String?,
    pcRam: json['pc_ram'] as String?,
    pcStorage: json['pc_storage'] as String?,
    pcOs: json['pc_os'] as String?,
    pcMobo: json['pc_mobo'] as String?, 
    pcLanPorts: json['pc_lan_ports'] as int?, 
    assignedIps: ipsJson.map((e) => e.toString()).toList(),

    printerAe: json['printer_ae'] as String?,
    printerIp1: json['printer_ip1'] as String?,
    printerIp2: json['printer_ip2'] as String?,
    printerPort: json['printer_port'] as String?,
    printerPcVersion: json['printer_pc_version'] as String?,
    printerMbVersion: json['printer_mb_version'] as String?,
    printerImagerVersion: json['printer_imager_version'] as String?,

    xrayConsoleSl: json['xray_console_sl'] as String?,
    xrayTubeSl: json['xray_tube_sl'] as String?,
    xrayGeneratorSl: json['xray_generator_sl'] as String?,

    fpdAcqId: json['fpd_acq_id'] as String?,
    fpdSoftware: json['fpd_software'] as String?,
    fpdVersion: json['fpd_version'] as String?,
    fpdModule: json['fpd_module'] as String?,
    fpdLicense: json['fpd_license'] as String?,
    fpdLicenseType: json['fpd_license_type'] as String?, 
    fpdDongleSerial: json['fpd_dongle_serial'] as String?, 
    
    customMetadata: parsedMeta,

    engineers: engineers, // Correctly mapped list of engineers
    parts: partsJson
        .map((e) => MachinePart.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
  Map<String, dynamic> toJson() => {
        'hospital_id': hospitalId,
        'machine_type': machineType.label,
        'brand': brand,
        'model': model,
        'serial_number': serialNumber,
       // 'installation_engineer_name': installationEngineerName,
        'installation_engineer_id': installationEngineerId, // Added
        'installation_date': installationDate.toIso8601String().split('T').first,
        'warranty_period': warrantyPeriod,
        'invoice_url': invoiceUrl,
        'notes': notes,
        
        'pc_cpu': pcCpu,
        'pc_ram': pcRam,
        'pc_storage': pcStorage,
        'pc_os': pcOs,
        'pc_mobo': pcMobo, // Added
        'pc_lan_ports': pcLanPorts, // Added
        'assigned_ips': assignedIps.where((ip) => ip.trim().isNotEmpty).toList(),

        // Serialize Conditional Parameters Map
        'printer_ae': printerAe,
        'printer_ip1': printerIp1,
        'printer_ip2': printerIp2,
        'printer_port': printerPort,
        'printer_pc_version': printerPcVersion,
        'printer_mb_version': printerMbVersion,
        'printer_imager_version': printerImagerVersion,

        'xray_console_sl': xrayConsoleSl,
        'xray_tube_sl': xrayTubeSl,
        'xray_generator_sl': xrayGeneratorSl,

        'fpd_acq_id': fpdAcqId,
        'fpd_software': fpdSoftware,
        'fpd_version': fpdVersion,
        'fpd_module': fpdModule,
        'fpd_license': fpdLicense,
        'fpd_license_type': fpdLicenseType, // Added
        'fpd_dongle_serial': fpdDongleSerial, // Added

        'custom_metadata': customMetadata,
      };

  InstalledMachine copyWith({
    String? id,
    String? hospitalId,
    MachineType? machineType,
    String? brand,
    String? model,
    String? serialNumber,
    String? installationEngineerName,
    String? installationEngineerId, // Added
    DateTime? installationDate,
    int? warrantyPeriod,
    String? invoiceUrl,
    String? notes,
    DateTime? createdAt,
    String? pcCpu,
    String? pcRam,
    String? pcStorage,
    String? pcOs,
    String? pcMobo, // Added
    int? pcLanPorts, // Added
    List<String>? assignedIps,
    String? printerAe,
    String? printerIp1,
    String? printerIp2,
    String? printerPort,
    String? printerPcVersion,
    String? printerMbVersion,
    String? printerImagerVersion,
    String? xrayConsoleSl,
    String? xrayTubeSl,
    String? xrayGeneratorSl,
    String? fpdAcqId,
    String? fpdSoftware,
    String? fpdVersion,
    String? fpdModule,
    String? fpdLicense,
    String? fpdLicenseType, // Added
    String? fpdDongleSerial, // Added
    Map<String, String>? customMetadata,
    List<Engineer>? engineers,
    List<MachinePart>? parts,
  }) =>
      InstalledMachine(
        id: id ?? this.id,
        hospitalId: hospitalId ?? this.hospitalId,
        machineType: machineType ?? this.machineType,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        serialNumber: serialNumber ?? this.serialNumber,
        installationEngineerName: installationEngineerName ?? this.installationEngineerName,
        installationEngineerId: installationEngineerId ?? this.installationEngineerId, // Added
        installationDate: installationDate ?? this.installationDate,
        warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
        invoiceUrl: invoiceUrl ?? this.invoiceUrl,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        
        pcCpu: pcCpu ?? this.pcCpu,
        pcRam: pcRam ?? this.pcRam,
        pcStorage: pcStorage ?? this.pcStorage,
        pcOs: pcOs ?? this.pcOs,
        pcMobo: pcMobo ?? this.pcMobo, // Added
        pcLanPorts: pcLanPorts ?? this.pcLanPorts, // Added
        assignedIps: assignedIps ?? this.assignedIps,

        printerAe: printerAe ?? this.printerAe,
        printerIp1: printerIp1 ?? this.printerIp1,
        printerIp2: printerIp2 ?? this.printerIp2,
        printerPort: printerPort ?? this.printerPort,
        printerPcVersion: printerPcVersion ?? this.printerPcVersion,
        printerMbVersion: printerMbVersion ?? this.printerMbVersion,
        printerImagerVersion: printerImagerVersion ?? this.printerImagerVersion,

        xrayConsoleSl: xrayConsoleSl ?? this.xrayConsoleSl,
        xrayTubeSl: xrayTubeSl ?? this.xrayTubeSl,
        xrayGeneratorSl: xrayGeneratorSl ?? this.xrayGeneratorSl,

        fpdAcqId: fpdAcqId ?? this.fpdAcqId,
        fpdSoftware: fpdSoftware ?? this.fpdSoftware,
        fpdVersion: fpdVersion ?? this.fpdVersion,
        fpdModule: fpdModule ?? this.fpdModule,
        fpdLicense: fpdLicense ?? this.fpdLicense,
        fpdLicenseType: fpdLicenseType ?? this.fpdLicenseType, // Added
        fpdDongleSerial: fpdDongleSerial ?? this.fpdDongleSerial, // Added

        customMetadata: customMetadata ?? this.customMetadata,
        engineers: engineers ?? this.engineers,
        parts: parts ?? this.parts,
      );

  @override
  List<Object?> get props => [
        id,
        hospitalId,
        brand,
        model,
        installationEngineerId, // Added
        pcCpu,
        pcRam,
        pcStorage,
        pcOs,
        pcMobo, // Added
        pcLanPorts, // Added
        assignedIps,
        printerAe,
        printerIp1,
        printerIp2,
        printerPort,
        printerPcVersion,
        printerMbVersion,
        printerImagerVersion,
        xrayConsoleSl,
        xrayTubeSl,
        xrayGeneratorSl,
        fpdAcqId,
        fpdSoftware,
        fpdVersion,
        fpdModule,
        fpdLicense,
        fpdLicenseType, // Added
        fpdDongleSerial, // Added
        customMetadata,
      ];
}