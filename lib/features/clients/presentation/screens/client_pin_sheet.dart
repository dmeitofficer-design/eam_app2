// lib/features/clients/presentation/screens/client_pin_sheet.dart
//
// Admin-only: set, move or clear a client's map pin. Coordinates are
// pasted as "lat, lng" (Google Maps: long-press a spot, tap the numbers
// to copy). smartHr can only fill an empty pin; changing one is done here.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/models/hospital_client.dart';
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
  late final _ctrl = TextEditingController(
    text: widget.client.hasLocation
        ? '${widget.client.latitude}, ${widget.client.longitude}'
        : '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool clear}) async {
    final parsed = clear ? null : parseLatLng(_ctrl.text);
    if (!clear && parsed == null) {
      setState(
        () => _error = 'Enter "latitude, longitude" inside Bangladesh, '
            'e.g. 23.7516, 90.3825',
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
    return Padding(
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
            'Paste the coordinates from Google Maps (long-press the spot, '
            'then tap the numbers to copy them).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Latitude, longitude',
              hintText: '23.7516, 90.3825',
              prefixIcon: const Icon(Icons.pin_drop_rounded),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(clear: false),
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
                        width: 18, height: 18,
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
