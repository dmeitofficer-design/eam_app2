// lib/shared/widgets/updated_by_label.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/auth/data/models/user_profile.dart';

/// Small, muted "Updated by Mehedi · 12 Oct 2026" line.
/// Renders nothing when no author was recorded.
class UpdatedByLabel extends StatelessWidget {
  const UpdatedByLabel({super.key, required this.name, this.at});

  final String? name;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final who = firstNameOf(name);
    if (who.isEmpty) return const SizedBox.shrink();

    final when = at == null ? '' : ' · ${DateFormat('d MMM yyyy').format(at!.toLocal())}';
    return Text(
      'Updated by $who$when',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
    );
  }
}
