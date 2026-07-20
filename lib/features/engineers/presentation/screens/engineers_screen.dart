// lib/features/engineers/presentation/screens/engineers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/engineers_bloc.dart';
import './engineer_form_sheet.dart'; 

// Point to the comprehensive machines feature model path
import '../../../machines/data/models/engineer.dart';

class EngineersScreen extends StatefulWidget {
  const EngineersScreen({super.key});

  @override
  State<EngineersScreen> createState() => _EngineersScreenState();
}

class _EngineersScreenState extends State<EngineersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<EngineersBloc>().add(EngineersFetchAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to trigger the bottom form sheet
  void _openAddEngineerSheet() {
    EngineerFormSheet.show(
      context,
      machineId: null, 
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Engineers Directory',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
            tooltip: 'Register New Engineer',
            onPressed: _openAddEngineerSheet,
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        onPressed: _openAddEngineerSheet,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.xl : AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track and coordinate field service engineers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Search Input Bar ────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.surface2),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name or contact...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Bloc Consumer Screen State ────────────────────────────────
              Expanded(
                child: BlocConsumer<EngineersBloc, EngineersState>(
                  listener: (context, state) {
                    if (state is EngineersError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                      );
                    } else if (state is EngineersActionFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
                      );
                    } else if (state is EngineersActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.green),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is EngineersInitial) {
                      return Center(
                        child: OutlinedButton.icon(
                          onPressed: _openAddEngineerSheet,
                          icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.textPrimary),
                          label: Text('Register Profile', style: TextStyle(color: AppColors.textPrimary)),
                        ),
                      );
                    }

                    if (state is EngineersLoading) {
                      return _ShimmerList(isDesktop: isDesktop);
                    }
                    
                    if (state is EngineersError) {
                      return _ErrorCard(
                        message: state.message,
                        onRetry: () => context
                            .read<EngineersBloc>()
                            .add(EngineersFetchAll()),
                      );
                    }

                    final List<Engineer> engineersList = switch (state) {
                      EngineersLoaded(:final engineers) => engineers,
                      EngineersActionSuccess(:final engineers) => engineers,
                      EngineersActionFailure(:final engineers) => engineers,
                      _ => <Engineer>[],
                    };

                    final filteredEngineers = engineersList.where((eng) {
                      final nameMatch = eng.name.toLowerCase().contains(_searchQuery);
                      final phoneMatch = (eng.phone ?? '').toLowerCase().contains(_searchQuery);
                      return nameMatch || phoneMatch;
                    }).toList();

                    if (filteredEngineers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.engineering_rounded, 
                              size: 64, 
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No engineers found matching search criteria.'
                                  : 'No engineers registered yet.',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg, 
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              onPressed: _openAddEngineerSheet,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Add Your First Engineer'),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: Colors.blue,
                      backgroundColor: AppColors.surface1,
                      onRefresh: () async {
                        context.read<EngineersBloc>().add(EngineersFetchAll());
                      },
                      child: isDesktop
                          ? GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                mainAxisExtent: 160,
                              ),
                              itemCount: filteredEngineers.length,
                              itemBuilder: (context, index) {
                                return _EngineerCard(engineer: filteredEngineers[index]);
                              },
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredEngineers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                return _EngineerCard(engineer: filteredEngineers[index]);
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Engineer Custom Card Widget ──────────────────────────────────────────────

class _EngineerCard extends StatelessWidget {
  const _EngineerCard({required this.engineer});
  
  final Engineer engineer; 

  void _confirmDelete(BuildContext context, Engineer engineer) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          title: Text('Delete Profile', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Are you sure you want to remove ${engineer.name} from the database?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<EngineersBloc>().add(EngineersDeleteRequested(engineer.id));
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isAvailable = engineer.isAvailable;
    final bool isActive = engineer.isActive;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.surface2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isAvailable 
                  ? Colors.blue.withOpacity(0.12) 
                  : Colors.orange.withOpacity(0.12),
              child: Text(
                engineer.name.isNotEmpty ? engineer.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isAvailable ? Colors.blue : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          engineer.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive) ...[
                            const _InactiveBadge(),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          _StatusBadge(isAvailable: isAvailable),
                        ],
                      ),
                    ],
                  ),
                  if (engineer.designation != null && engineer.designation!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      engineer.designation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    engineer.phone ?? 'No contact listed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md), 
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                        tooltip: 'Edit Profile',
                        onPressed: () {
                          EngineerFormSheet.show(
                            context,
                            machineId: engineer.machineId,
                            engineer: engineer,
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: 'Delete Profile',
                        onPressed: () => _confirmDelete(context, engineer),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting Inactive Badge Widget ────────────────────────────────────────

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: AppRadius.chip,
        border: Border.all(color: AppColors.textTertiary),
      ),
      child: Text(
        'INACTIVE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ── Supporting Status Badge Widget ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isAvailable});
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: isAvailable ? Colors.blue : Colors.orange,
        ),
      ),
      child: Text(
        isAvailable ? 'AVAILABLE' : 'ON DUTY',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isAvailable
              ? (ThemeController.isDarkMode
                  ? const Color.fromARGB(255, 241, 248, 255)
                  : Colors.blue.shade800)
              : (ThemeController.isDarkMode
                  ? Colors.orange.shade100
                  : Colors.orange.shade900),
          letterSpacing: 0.5,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ── Supporting Shimmer Widgets ──────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.surface4,
      child: isDesktop
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                mainAxisExtent: 160,
              ),
              itemCount: 4,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.card,
                ),
              ),
            )
          : ListView.separated(
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, __) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.card,
                ),
              ),
            ),
    );
  }
}

// ── Supporting Error Card Widget ────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isNetworkIssue = message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('timed out') ||
        message.toLowerCase().contains('supabase');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.surface2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isNetworkIssue 
                      ? Colors.orange.withOpacity(0.1) 
                      : AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNetworkIssue ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                  color: isNetworkIssue ? Colors.orange : AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isNetworkIssue ? 'Connection Error' : 'Unable to Load Data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}