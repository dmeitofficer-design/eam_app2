// lib/features/clients/presentation/screens/service_history_panel.dart
//
// Who from smartHr visited this client, when, why and what was done.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../data/models/service_entry.dart';
import '../../data/repositories/clients_repository.dart';

class ServiceHistoryPanel extends StatefulWidget {
  const ServiceHistoryPanel({super.key, required this.clientId});
  final String clientId;

  @override
  State<ServiceHistoryPanel> createState() => _ServiceHistoryPanelState();
}

class _ServiceHistoryPanelState extends State<ServiceHistoryPanel> {
  late Future<List<ServiceEntry>> _future = _load();

  Future<List<ServiceEntry>> _load() =>
      context.read<ClientsRepository>().getServiceHistory(widget.clientId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Service history',
          trailing: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Reload',
            onPressed: () => setState(() => _future = _load()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<ServiceEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text('${snap.error}', style: theme.textTheme.bodySmall);
            }
            final entries = snap.data!;
            if (entries.isEmpty) {
              return Text(
                'No visits or jobs from smartHr yet.',
                style: theme.textTheme.bodySmall,
              );
            }
            return Column(
              children: [for (final e in entries) _EntryTile(entry: e)],
            );
          },
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final ServiceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final when = entry.endDate != null
        ? '${fmt.format(entry.date)} – ${fmt.format(entry.endDate!)}'
        : fmt.format(entry.date);
    final what = [entry.kindLabel, if (entry.jobType != null) entry.jobType!].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(when, style: theme.textTheme.labelLarge)),
              Text('$what · ${entry.status}', style: theme.textTheme.labelSmall),
            ],
          ),
          if (entry.title.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(entry.title, style: theme.textTheme.bodyMedium),
          ],
          if (entry.staff.isNotEmpty)
            Text(entry.staff.join(', '), style: theme.textTheme.bodySmall),
          if (entry.report != null && entry.report!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(entry.report!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
