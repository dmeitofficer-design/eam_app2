// lib/features/clients/presentation/screens/client_pin_sheet.dart
//
// Admin-only: set, move or clear a client's map pin. Search a place
// (OpenStreetMap), tap the map, or paste "lat, lng" from Google Maps.
// smartHr can only fill an empty pin; changing one is done here.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/models/hospital_client.dart';
import '../../data/places_search.dart';
import '../../data/repositories/clients_repository.dart';

/// "23.75, 90.38" → (23.75, 90.38) when inside Bangladesh (the database check), else null.
(double, double)? parseLatLng(String text) {
  final parts = text.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null) return null;
  if (lat < 20 || lat > 27 || lng < 88 || lng > 93) return null;
  return (lat, lng);
}

Uri mapsUri(double lat, double lng) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'});

Future<void> openInMaps(BuildContext context, HospitalClient c) async {
  if (!c.hasLocation) return;
  final ok = await launchUrl(
    mapsUri(c.latitude!, c.longitude!),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) AppFeedback.error(context, 'Could not open Maps.');
}

/// Returns the updated client, or null if nothing changed.
Future<HospitalClient?> showClientPinSheet(BuildContext context, HospitalClient client) {
  return showModalBottomSheet<HospitalClient>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false, // dragging pans the map, not the sheet
    builder: (_) => RepositoryProvider.value(
      value: context.read<ClientsRepository>(),
      child: _ClientPinSheet(client: client),
    ),
  );
}

class _ClientPinSheet extends StatefulWidget {
  const _ClientPinSheet({required this.client});
  final HospitalClient client;

  @override
  State<_ClientPinSheet> createState() => _ClientPinSheetState();
}

class _ClientPinSheetState extends State<_ClientPinSheet> {
  static const _bangladesh = LatLng(23.7, 90.35);

  final _map = MapController();
  late final _searchCtrl = TextEditingController(
    text: [widget.client.name, widget.client.district]
        .where((s) => s.isNotEmpty)
        .join(', '),
  );
  late final _coordsCtrl = TextEditingController(
    text: widget.client.hasLocation
        ? '${widget.client.latitude}, ${widget.client.longitude}'
        : '',
  );
  late LatLng? _pin = widget.client.hasLocation
      ? LatLng(widget.client.latitude!, widget.client.longitude!)
      : null;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _coordsCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _setPin(LatLng p, {bool move = false}) {
    setState(() {
      _pin = p;
      _error = null;
      _coordsCtrl.text =
          '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
    });
    if (move) _map.move(p, 16);
  }

  // Nominatim allows 1 request/second: search on button or Enter only.
  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3 || _searching) return;
    setState(() => _searching = true);
    try {
      final found = (await searchPlaces(q)).where((p) => p.lat != null && p.lng != null).toList();
      if (!mounted) return;
      setState(() => _results = found);
      if (found.isEmpty) AppFeedback.info(context, 'No places found. Tap the map instead.');
    } catch (_) {
      if (mounted) AppFeedback.error(context, 'Place search failed. Check the connection.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _coordsTyped(String text) {
    final p = parseLatLng(text);
    if (p == null) {
      setState(() => _error = 'Enter "latitude, longitude" inside Bangladesh');
      return;
    }
    _setPin(LatLng(p.$1, p.$2), move: true);
  }

  Future<void> _save({required bool clear}) async {
    final pin = _pin;
    final parsed = clear || pin == null
        ? null
        : parseLatLng('${pin.latitude}, ${pin.longitude}');
    if (!clear && parsed == null) {
      setState(
        () => _error = pin == null
            ? 'Search a place or tap the map to drop the pin'
            : 'The pin must be inside Bangladesh',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context
          .read<ClientsRepository>()
          .setLocation(widget.client.id, parsed?.$1, parsed?.$2);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, 'Could not save the pin: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Map pin', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Search the place, or tap the map where the client is.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search place',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      tooltip: 'Search',
                      onPressed: _search,
                    ),
            ),
            onSubmitted: (_) => _search(),
          ),
          for (final p in _results.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(p.name),
              subtitle: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                setState(() => _results = const []);
                _setPin(LatLng(p.lat!, p.lng!), move: true);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.card,
            child: SizedBox(
              height: 320,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _pin ?? _bangladesh,
                  initialZoom: _pin != null ? 16 : 7,
                  onTap: (_, p) => _setPin(p),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.eam_platform',
                  ),
                  if (_pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin!,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.error,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  const SimpleAttributionWidget(
                    source: Text('OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _coordsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Latitude, longitude',
              helperText: 'Or paste the numbers from Google Maps, then press Enter',
              prefixIcon: const Icon(Icons.pin_drop_rounded),
              errorText: _error,
            ),
            onSubmitted: _coordsTyped,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (widget.client.hasLocation)
                TextButton.icon(
                  onPressed: _saving ? null : () => _save(clear: true),
                  icon: const Icon(Icons.location_off_rounded),
                  label: const Text('Clear pin'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : () => _save(clear: false),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save pin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
