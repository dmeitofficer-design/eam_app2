// lib/features/clients/data/places_search.dart
//
// OpenStreetMap Nominatim search (free, no key), used to fill a client's
// name and address. Usage policy: max 1 request/second and an identifying
// User-Agent — fine for a button-press search, never call it per keystroke.

import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  const PlaceResult(this.name, this.address, this.components, {this.lat, this.lng});
  final String name;
  final String address;
  final double? lat;
  final double? lng;

  /// Address component names, most specific first (area → district → division).
  final List<String> components;
}

Future<List<PlaceResult>> searchPlaces(String query) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'jsonv2',
    'addressdetails': '1',
    'countrycodes': 'bd',
    'limit': '8',
    'accept-language': 'en',
  });
  final res = await http.get(
    uri,
    headers: {'User-Agent': 'eam_platform/1.0 (Flutter app)'},
  ).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw Exception('Place search failed (${res.statusCode})');
  }

  final places = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  return places.map((p) {
    final display = p['display_name'] as String? ?? '';
    final name = p['name'] as String? ?? '';
    final address = (p['address'] as Map<String, dynamic>?) ?? {};
    return PlaceResult(
      name.isNotEmpty ? name : display.split(',').first,
      display,
      address.values.whereType<String>().toList(),
      lat: double.tryParse(p['lat']?.toString() ?? ''),
      lng: double.tryParse(p['lon']?.toString() ?? ''),
    );
  }).toList();
}
