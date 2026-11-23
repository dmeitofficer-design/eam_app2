// lib/features/clients/data/models/service_entry.dart
//
// One visit, job or unplanned visit at a client, as smartHr reports it.
// Contract: docs/smarthr-service-history.md.

class ServiceEntry {
  const ServiceEntry({
    required this.kind,
    required this.date,
    required this.staff,
    required this.title,
    required this.status,
    this.endDate,
    this.jobType,
    this.report,
  });

  final String kind; // visit | job | unplanned
  final DateTime date;
  final DateTime? endDate;
  final List<String> staff;
  final String title;
  final String? jobType;
  final String status;
  final String? report;

  String get kindLabel => switch (kind) {
        'job' => 'Job',
        'unplanned' => 'Unplanned visit',
        _ => 'Visit',
      };

  factory ServiceEntry.fromJson(Map<String, dynamic> j) => ServiceEntry(
        kind: j['kind'] as String? ?? 'visit',
        date: DateTime.parse(j['date'] as String),
        endDate: j['end_date'] != null ? DateTime.parse(j['end_date'] as String) : null,
        staff: (j['staff'] as List? ?? const []).whereType<String>().toList(),
        title: j['title'] as String? ?? '',
        jobType: j['job_type'] as String?,
        status: j['status'] as String? ?? '',
        report: j['report'] as String?,
      );
}
