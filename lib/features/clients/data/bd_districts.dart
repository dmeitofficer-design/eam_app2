// lib/features/clients/data/bd_districts.dart

import 'models/hospital_client.dart';

/// All 64 districts of Bangladesh with their division.
const Map<String, DivisionType> bdDistricts = {
  // Dhaka
  'Dhaka': DivisionType.dhaka, 'Faridpur': DivisionType.dhaka,
  'Gazipur': DivisionType.dhaka, 'Gopalganj': DivisionType.dhaka,
  'Kishoreganj': DivisionType.dhaka, 'Madaripur': DivisionType.dhaka,
  'Manikganj': DivisionType.dhaka, 'Munshiganj': DivisionType.dhaka,
  'Narayanganj': DivisionType.dhaka, 'Narsingdi': DivisionType.dhaka,
  'Rajbari': DivisionType.dhaka, 'Shariatpur': DivisionType.dhaka,
  'Tangail': DivisionType.dhaka,
  // Chattogram
  'Bandarban': DivisionType.chattogram, 'Brahmanbaria': DivisionType.chattogram,
  'Chandpur': DivisionType.chattogram, 'Chattogram': DivisionType.chattogram,
  "Cox's Bazar": DivisionType.chattogram, 'Cumilla': DivisionType.chattogram,
  'Feni': DivisionType.chattogram, 'Khagrachhari': DivisionType.chattogram,
  'Lakshmipur': DivisionType.chattogram, 'Noakhali': DivisionType.chattogram,
  'Rangamati': DivisionType.chattogram,
  // Rajshahi
  'Bogura': DivisionType.rajshahi, 'Chapainawabganj': DivisionType.rajshahi,
  'Joypurhat': DivisionType.rajshahi, 'Naogaon': DivisionType.rajshahi,
  'Natore': DivisionType.rajshahi, 'Pabna': DivisionType.rajshahi,
  'Rajshahi': DivisionType.rajshahi, 'Sirajganj': DivisionType.rajshahi,
  // Khulna
  'Bagerhat': DivisionType.khulna, 'Chuadanga': DivisionType.khulna,
  'Jashore': DivisionType.khulna, 'Jhenaidah': DivisionType.khulna,
  'Khulna': DivisionType.khulna, 'Kushtia': DivisionType.khulna,
  'Magura': DivisionType.khulna, 'Meherpur': DivisionType.khulna,
  'Narail': DivisionType.khulna, 'Satkhira': DivisionType.khulna,
  // Barishal
  'Barguna': DivisionType.barishal, 'Barishal': DivisionType.barishal,
  'Bhola': DivisionType.barishal, 'Jhalokati': DivisionType.barishal,
  'Patuakhali': DivisionType.barishal, 'Pirojpur': DivisionType.barishal,
  // Sylhet
  'Habiganj': DivisionType.sylhet, 'Moulvibazar': DivisionType.sylhet,
  'Sunamganj': DivisionType.sylhet, 'Sylhet': DivisionType.sylhet,
  // Rangpur
  'Dinajpur': DivisionType.rangpur, 'Gaibandha': DivisionType.rangpur,
  'Kurigram': DivisionType.rangpur, 'Lalmonirhat': DivisionType.rangpur,
  'Nilphamari': DivisionType.rangpur, 'Panchagarh': DivisionType.rangpur,
  'Rangpur': DivisionType.rangpur, 'Thakurgaon': DivisionType.rangpur,
  // Mymensingh
  'Jamalpur': DivisionType.mymensingh, 'Mymensingh': DivisionType.mymensingh,
  'Netrokona': DivisionType.mymensingh, 'Sherpur': DivisionType.mymensingh,
};

/// Old / alternate spellings (Google still uses some) → official name.
const Map<String, String> _aliases = {
  'chittagong': 'Chattogram', 'comilla': 'Cumilla', 'bogra': 'Bogura',
  'jessore': 'Jashore', 'barisal': 'Barishal', 'coxs bazar': "Cox's Bazar",
  'chapai nawabganj': 'Chapainawabganj', 'nawabganj': 'Chapainawabganj',
  'jhalakati': 'Jhalokati', 'maulvibazar': 'Moulvibazar',
  'netrakona': 'Netrokona', 'khagrachari': 'Khagrachhari',
  'laxmipur': 'Lakshmipur',
};

/// Returns the official district name for [raw], or null if it isn't one.
/// Tolerates case, aliases and a trailing "District"/"Zila".
String? matchDistrict(String raw) {
  final key = raw
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+(district|zila|zilla)$'), '')
      .trim();
  for (final d in bdDistricts.keys) {
    if (d.toLowerCase().replaceAll("'", '') == key) return d;
  }
  return _aliases[key];
}
