// lib/features/machines/presentation/screens/machine_config_page.dart
//
// Admin-only page. Lets admins add/remove values from three lists:
//   • Genre / Specialty  (e.g. Radiology, Cardiology)
//   • Brands             (e.g. DRGEM, GE Healthcare)
//   • Machine Types      (e.g. X-ray, CT Scanner)
// These lists power the dropdowns in AddClientPage.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../config/presentation/bloc/config_bloc.dart';

class MachineConfigPage extends StatelessWidget {
  const MachineConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    // If ConfigBloc isn't already in scope, create one
    return BlocProvider.value(
      value: context.read<ConfigBloc>(),
      child: const _MachineConfigView(),
    );
  }
}

class _MachineConfigView extends StatelessWidget {
  const _MachineConfigView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        title: const Text('Machine Model Editor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<ConfigBloc, ConfigState>(
        listener: (context, state) {
          if (state.error != null) {
            AppFeedback.error(context, state.error!);
          }
          if (state.successMessage != null) {
            AppFeedback.success(context, state.successMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _ConfigSection(
                title: 'Genres / Specialties',
                configType: 'genre',
                values: state.genres,
                hint: 'e.g. Cardiology',
              ),
              const SizedBox(height: AppSpacing.lg),
              _ConfigSection(
                title: 'Brands',
                configType: 'brand',
                values: state.brands,
                hint: 'e.g. Mindray',
              ),
              const SizedBox(height: AppSpacing.lg),
              _ConfigSection(
                title: 'Machine Types',
                configType: 'machine_type',
                values: state.machineTypes,
                hint: 'e.g. CT Scanner',
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _ConfigSection extends StatefulWidget {
  const _ConfigSection({
    required this.title,
    required this.configType,
    required this.values,
    required this.hint,
  });

  final String title;
  final String configType;
  final List<String> values;
  final String hint;

  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return;
    if (widget.values.map((v) => v.toLowerCase()).contains(value.toLowerCase())) {
      AppFeedback.warning(context, '"$value" already exists.');
      return;
    }
    context.read<ConfigBloc>().add(
      ConfigOptionAdded(widget.configType, value),
    );
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              widget.title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Existing values
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.surface2),
          ),
          child: Column(
            children: [
              if (widget.values.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'No options yet.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                ...widget.values.asMap().entries.map((entry) {
                  final i = entry.key;
                  final value = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 0,
                        ),
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ),
                        title: Text(value, style: theme.textTheme.bodyMedium),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          color: AppColors.textTertiary,
                          tooltip: 'Delete',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.surface1,
                                title: const Text('Remove option?'),
                                content: Text(
                                  'Delete "$value" from ${widget.title}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 40),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              // We need the ID — fetch from repo
                              final repo = context.read<ConfigRepository>();
                              final items = await repo.getByType(widget.configType);
                              final match = items.where(
                                  (e) => e.value.toLowerCase() ==
                                      value.toLowerCase());
                              if (match.isNotEmpty && context.mounted) {
                                context.read<ConfigBloc>().add(
                                  ConfigOptionDeleted(match.first.id),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      if (i < widget.values.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Add new row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: _add,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(56, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
