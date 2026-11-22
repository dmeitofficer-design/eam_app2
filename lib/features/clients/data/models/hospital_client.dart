// lib/features/clients/data/models/hospital_client.dart

import 'package:equatable/equatable.dart';
import '../../../approvals/data/models/approval_status.dart';

enum DivisionType {
  dhaka('Dhaka'),
  chattogram('Chattogram'),
  rajshahi('Rajshahi'),
  khulna('Khulna'),
  barishal('Barishal'),
  sylhet('Sylhet'),
  mymensingh('Mymensingh'),
  rangpur('Rangpur');

  const DivisionType(this.label);
  final String label;

  static DivisionType fromString(String value) =>
      DivisionType.values.firstWhere(
        (e) => e.label.toLowerCase() == value.toLowerCase(),
        orElse: () => DivisionType.dhaka,
      );
}

enum FacilityType {
  hospital('Hospital'),
  clinic('Clinic'),
  diagnosticCenter('Diagnostic Center'),
  government('Government Hospital'),
  medicalCheckupCenter('Medical Checkup Center'),
  reseller('reseller'),
  ;


  const FacilityType(this.label);
  final String label;

  static FacilityType fromString(String value) =>
      FacilityType.values.firstWhere(
        (e) => e.label.toLowerCase() == value.toLowerCase(),
        orElse: () => FacilityType.hospital,
      );
}

class HospitalClient extends Equatable {
  final String id;
  final String name;
  final String address;
  final String district;
  final String genre;
  final DivisionType division;
  final FacilityType facilityType;
  final String contactPersonName;
  final String contactPersonDesignation;
  final String contactPersonPhone;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedByName;
  final String? createdByName;
  final String? createdBy;
  final ApprovalStatus approvalStatus;
  final String? rejectionReason;
  final double? latitude;
  final double? longitude;
  final DateTime? locationSetAt;
  final String? locationSetBy;

  bool get hasLocation => latitude != null && longitude != null;

  const HospitalClient({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.genre,
    required this.division,
    required this.facilityType,
    required this.contactPersonName,
    required this.contactPersonDesignation,
    required this.contactPersonPhone,
    required this.createdAt,
    this.updatedAt,
    this.updatedByName,
    this.createdByName,
    this.createdBy,
    this.approvalStatus = ApprovalStatus.approved,
    this.rejectionReason,
    this.latitude,
    this.longitude,
    this.locationSetAt,
    this.locationSetBy,
  });

  factory HospitalClient.fromJson(Map<String, dynamic> json) => HospitalClient(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        district: json['district'] as String? ?? '',
        genre: json['genre'] as String? ?? 'General',
        division: DivisionType.fromString(json['division'] as String),
        facilityType: FacilityType.fromString(json['facility_type'] as String),
        contactPersonName: json['contact_person_name'] as String,
        contactPersonDesignation: json['contact_person_designation'] as String,
        contactPersonPhone: json['contact_person_phone'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        updatedByName: json['updated_by_name'] as String?,
        createdByName: json['created_by_name'] as String?,
        createdBy: json['created_by'] as String?,
        approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String?),
        rejectionReason: json['rejection_reason'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationSetAt: json['location_set_at'] != null
            ? DateTime.parse(json['location_set_at'] as String)
            : null,
        locationSetBy: json['location_set_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'district': district,
        'genre': genre,
        'division': division.label,
        'facility_type': facilityType.label,
        'contact_person_name': contactPersonName,
        'contact_person_designation': contactPersonDesignation,
        'contact_person_phone': contactPersonPhone,
      };

  HospitalClient copyWith({
    String? id,
    String? name,
    String? address,
    String? district,
    String? genre,
    DivisionType? division,
    FacilityType? facilityType,
    String? contactPersonName,
    String? contactPersonDesignation,
    String? contactPersonPhone,
    DateTime? createdAt,
  }) =>
      HospitalClient(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        district: district ?? this.district,
        genre: genre ?? this.genre,
        division: division ?? this.division,
        facilityType: facilityType ?? this.facilityType,
        contactPersonName: contactPersonName ?? this.contactPersonName,
        contactPersonDesignation:
            contactPersonDesignation ?? this.contactPersonDesignation,
        contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt,
        updatedByName: updatedByName,
        createdByName: createdByName,
        createdBy: createdBy,
        approvalStatus: approvalStatus,
        rejectionReason: rejectionReason,
        latitude: latitude,
        longitude: longitude,
        locationSetAt: locationSetAt,
        locationSetBy: locationSetBy,
      );

  @override
  List<Object?> get props => [id, name, district, division, facilityType, approvalStatus];
}
