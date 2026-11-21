import 'package:eam_platform/features/clients/data/bd_districts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('64 districts', () => expect(bdDistricts.length, 64));

  test('matchDistrict handles case, aliases, suffix', () {
    expect(matchDistrict('dhaka'), 'Dhaka');
    expect(matchDistrict('Chittagong'), 'Chattogram');
    expect(matchDistrict('Comilla District'), 'Cumilla');
    expect(matchDistrict("Cox's Bazar"), "Cox's Bazar");
    expect(matchDistrict('Coxs Bazar'), "Cox's Bazar");
    expect(matchDistrict('Bangladesh'), isNull);
  });
}
