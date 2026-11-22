import 'package:eam_platform/features/clients/data/models/hospital_client.dart';
import 'package:eam_platform/features/clients/presentation/screens/client_pin_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseLatLng accepts pasted Google Maps coordinates inside Bangladesh', () {
    expect(parseLatLng('23.7516, 90.3825'), (23.7516, 90.3825));
    expect(parseLatLng(' 23.7516 90.3825 '), (23.7516, 90.3825));
    expect(parseLatLng('51.5, -0.1'), isNull); // outside Bangladesh
    expect(parseLatLng('23.75'), isNull);
    expect(parseLatLng('abc, def'), isNull);
  });

  test('HospitalClient reads the pin columns', () {
    final base = {
      'id': 'x', 'name': 'n', 'address': 'a', 'division': 'Dhaka',
      'facility_type': 'Hospital', 'contact_person_name': 'c',
      'contact_person_designation': 'd', 'contact_person_phone': 'p',
      'created_at': '2026-11-22T00:00:00Z',
    };
    expect(HospitalClient.fromJson(base).hasLocation, isFalse);
    final pinned = HospitalClient.fromJson({
      ...base, 'latitude': 23, 'longitude': 90.38,
      'location_set_by': 'Rafiq Hasan (smartHr)',
    });
    expect(pinned.hasLocation, isTrue);
    expect(pinned.latitude, 23.0);
    expect(pinned.copyWith(name: 'm').longitude, 90.38);
  });
}
