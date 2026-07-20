// lib/features/clients/presentation/screens/clients_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../config/presentation/bloc/config_bloc.dart';
import '../../data/models/hospital_client.dart';
import '../bloc/clients_bloc.dart';
import 'add_client_page.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClients(force: false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _fetchClients({bool force = false}) {
    context.read<ClientsBloc>().add(ClientsFetchRequested(forceRefresh: force));
  }

  void _openAddClient() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ClientsBloc>()),
            BlocProvider(
              create: (_) => ConfigBloc(
                repository: context.read<ConfigRepository>(),
              )..add(ConfigLoadRequested()),
            ),
          ],
          child: const AddClientPage(),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String errorMessage) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.amberAccent,
          onPressed: () => _fetchClients(force: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin =
        authState is AuthAuthenticated && authState.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAddClient,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Client'),
              elevation: 0,
              shape: const StadiumBorder(), 
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + Search + Filters ──────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                isDesktop ? AppSpacing.xl : AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clients', style: theme.textTheme.headlineLarge),
                          BlocBuilder<ClientsBloc, ClientsState>(
                            buildWhen: (p, c) =>
                                p.clients.length != c.clients.length,
                            builder: (context, state) => Text(
                              '${state.clients.length} facilities',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (isAdmin && isDesktop)
                        ElevatedButton.icon(
                          onPressed: _openAddClient,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Client'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (q) => context.read<ClientsBloc>().add(
                      ClientsSearchChanged(q),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone, location…',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                      suffixIcon: BlocBuilder<ClientsBloc, ClientsState>(
                        buildWhen: (p, c) => p.searchQuery != c.searchQuery,
                        builder: (context, state) {
                          if (state.searchQuery.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textTertiary,
                            onPressed: () {
                              _searchCtrl.clear();
                              context
                                  .read<ClientsBloc>()
                                  .add(const ClientsSearchChanged(''));
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Filter chips
                  _FilterRow(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),

            // ── List ──────────────────────────────────────
            Expanded(
              child: BlocConsumer<ClientsBloc, ClientsState>(
                listener: (context, state) {
                  // Show SnackBar when an error occurs while keeping existing list data
                  if (state.error != null && state.clients.isNotEmpty) {
                    _showErrorSnackBar(state.error!);
                  }
                },
                builder: (context, state) {
                  if (state.isLoading && state.clients.isEmpty) {
                    return _ShimmerList();
                  }

                  // Render full error retry view when no clients are cached/available
                  if (state.error != null && state.clients.isEmpty) {
                    return ErrorStateWidget(
                      rawError: state.error!,
                      onRetry: () => _fetchClients(force: true),
                    );
                  }

                  Future<void> handleRefresh() async {
                    final bloc = context.read<ClientsBloc>();
                    bloc.add(const ClientsFetchRequested(forceRefresh: true));
                    await bloc.stream.firstWhere((s) => !s.isLoading);
                  }

                  if (state.clients.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.surface1,
                      onRefresh: handleRefresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 48, color: AppColors.surface3),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    state.hasActiveFilters
                                        ? 'No clients match your filters.'
                                        : 'No clients yet.',
                                    style: theme.textTheme.bodyLarge
                                        ?.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  if (state.hasActiveFilters)
                                    TextButton(
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        context
                                            .read<ClientsBloc>()
                                            .add(ClientsFilterCleared());
                                      },
                                      child: const Text('Clear filters'),
                                    )
                                  else if (isAdmin)
                                    ElevatedButton.icon(
                                      onPressed: _openAddClient,
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('Add first client'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface1,
                    onRefresh: handleRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? AppSpacing.xl : AppSpacing.md,
                        AppSpacing.md,
                        isDesktop ? AppSpacing.xl : AppSpacing.md,
                        isAdmin ? 96 : AppSpacing.md,
                      ),
                      itemCount: state.clients.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _ClientCard(
                        client: state.clients[i],
                        onTap: () =>
                            context.push('/clients/${state.clients[i].id}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter row ───────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      buildWhen: (p, c) =>
          p.divisionFilter != c.divisionFilter ||
          p.facilityTypeFilter != c.facilityTypeFilter,
      builder: (context, state) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DropdownChip<DivisionType>(
              label: state.divisionFilter?.label ?? 'Division',
              isActive: state.divisionFilter != null,
              items: DivisionType.values,
              itemLabel: (d) => d.label,
              onSelected: (d) => context
                  .read<ClientsBloc>()
                  .add(ClientsDivisionFilterChanged(d)),
              onCleared: () => context
                  .read<ClientsBloc>()
                  .add(const ClientsDivisionFilterChanged(null)),
            ),
            const SizedBox(width: AppSpacing.xs),
            _DropdownChip<FacilityType>(
              label: state.facilityTypeFilter?.label ?? 'Facility Type',
              isActive: state.facilityTypeFilter != null,
              items: FacilityType.values,
              itemLabel: (f) => f.label,
              onSelected: (f) => context
                  .read<ClientsBloc>()
                  .add(ClientsFacilityFilterChanged(f)),
              onCleared: () => context
                  .read<ClientsBloc>()
                  .add(const ClientsFacilityFilterChanged(null)),
            ),
            if (state.hasActiveFilters) ...[
              const SizedBox(width: AppSpacing.xs),
              TextButton.icon(
                onPressed: () =>
                    context.read<ClientsBloc>().add(ClientsFilterCleared()),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Clear all'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.isActive,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    required this.onCleared,
  });

  final String label;
  final bool isActive;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (isActive) { onCleared(); return; }
        final result = await showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: AppColors.surface3),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final rowBgColor = index.isEven ? AppColors.surface4 : AppColors.surface1;

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.surface2,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: ListTile(
                        dense: true, 
                        tileColor: rowBgColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 2, 
                        ),
                        title: Text(
                          itemLabel(item),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        );
        if (result != null) onSelected(result);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentSurface : AppColors.surface2,
          borderRadius: AppRadius.chip,
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.surface3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),  
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              isActive
                  ? Icons.close_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isActive ? AppColors.accent : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Client card ──────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});
  final HospitalClient client;
  final VoidCallback onTap;

  IconData _facilityIcon(FacilityType type) {
    switch (type) {
      case FacilityType.hospital:
        return Icons.local_hospital_rounded;
      case FacilityType.clinic:
        return Icons.medical_services_rounded;
      case FacilityType.diagnosticCenter:
        return Icons.biotech_rounded;
      case FacilityType.government:
        return Icons.account_balance_rounded;
      case FacilityType.medicalCheckupCenter:
        return Icons.domain_rounded;
      case FacilityType.reseller:
        return Icons.handshake_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.surface2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _facilityIcon(client.facilityType),
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            [
                              if (client.district.isNotEmpty) client.district,
                              client.division.label,
                              client.facilityType.label,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (client.genre.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        client.genre,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface1,
      highlightColor: AppColors.surface2,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 7,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.card,
          ),
        ),
      ),
    );
  }
}