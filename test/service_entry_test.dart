import 'package:eam_platform/features/clients/data/models/service_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ServiceEntry reads the smartHr contract', () {
    final e = ServiceEntry.fromJson({
      'kind': 'job', 'id': 'x', 'date': '2026-11-20', 'end_date': '2026-11-21',
      'staff': ['Rafiq Hasan'], 'title': 'PM', 'job_type': 'Service',
      'status': 'done', 'report': 'Replaced tube', 'reported_at': null,
    });
    expect(e.kindLabel, 'Job');
    expect(e.endDate, DateTime(2026, 11, 21));
    expect(e.staff, ['Rafiq Hasan']);

    final v = ServiceEntry.fromJson({'kind': 'unplanned', 'date': '2026-11-01'});
    expect(v.kindLabel, 'Unplanned visit');
    expect(v.staff, isEmpty);
    expect(v.report, isNull);
  });
}
