// lib/core/shell/app_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Import your Blocs/Events to access them inside the refresh action
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/clients/presentation/bloc/clients_bloc.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _destinations = [
    _NavDest(
      icon: Icons.grid_view_rounded,
      label: 'Dashboard',
      path: '/dashboard',
    ),
    _NavDest(
      icon: Icons.local_hospital_rounded,
      label: 'Clients',
      path: '/clients',
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/clients')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final selectedIdx = _selectedIndex(context);

    if (isDesktop) {
      return _DesktopShell(
        destinations: _destinations,
        selectedIndex: selectedIdx,
        child: child,
      );
    } else {
      return _MobileShell(
        destinations: _destinations,
        selectedIndex: selectedIdx,
        child: child,
      );
    }
  }
}

// ── Desktop: persistent NavigationRail ──────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.destinations,
    required this.selectedIndex,
    required this.child,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final Widget child;

  // Added dynamic refresh routing execution method
  void _handleGlobalRefresh(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith('/dashboard')) {
      context.read<DashboardBloc>().add(const DashboardFetchRequested(forceRefresh: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing dashboard data...'), duration: Duration(milliseconds: 600)),
      );
    } else if (location.startsWith('/clients')) {
      // Adjust this event to match the exact load/fetch event name inside your ClientsBloc
      context.read<ClientsBloc>().add(const ClientsFetchRequested(forceRefresh: true)); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing client registries...'), duration: Duration(milliseconds: 600)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    final isDark = ThemeController.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.lightSurface0,
      body: Row(
        children: [
          // Rail
          Container(
            width: 220,
            color: isDark ? AppColors.surface1 : AppColors.lightSurface1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                // Brand Wrapper
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      // Wrapped the account_tree icon with InkWell for interaction
                      InkWell(
                        onTap: () => _handleGlobalRefresh(context),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        splashColor: AppColors.accent.withOpacity(0.3),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: const Icon(
                            Icons.account_tree,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DME Client Manager',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            'EAM Platform',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Nav items
                ...destinations.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final dest = entry.value;
                  final isSelected = idx == selectedIndex;
                  return _RailItem(
                    dest: dest,
                    isSelected: isSelected,
                    onTap: () => context.go(dest.path),
                  );
                }),

                const Spacer(),
                const Divider(indent: 16, endIndent: 16),

                // Profile
                if (profile != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isDark
                              ? AppColors.accentSurface
                              : const Color(0xFFE0F2FE),
                          child: Text(
                            (profile.fullName?.isNotEmpty == true
                                    ? profile.fullName![0]
                                    : 'U')
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color.fromARGB(255, 99, 198, 255),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName ?? 'User',
                                style: theme.textTheme.labelMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                profile.role.name.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color.fromARGB(255, 99, 198, 255),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          onPressed: () =>
                              context.read<AuthBloc>().add(AuthLogoutRequested()),
                          color: isDark ? AppColors.textTertiary : AppColors.lightTextTertiary,
                          tooltip: 'Sign out',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, color: isDark ? AppColors.surface2 : AppColors.lightSurface2),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.dest,
    required this.isSelected,
    required this.onTap,
  });
  final _NavDest dest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.accentSurface : const Color(0xFFE0F2FE))
                  : Colors.transparent,
              borderRadius: AppRadius.card,
            ),
            child: Row(
              children: [
                Icon(
                  dest.icon,
                  size: 20,
                  color: isSelected
                      ? const Color.fromARGB(255, 99, 211, 255)
                      : (isDark ? AppColors.textTertiary : AppColors.lightTextTertiary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  dest.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? const Color.fromARGB(255, 56, 199, 255)
                        : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile: NavigationBar ────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.destinations,
    required this.selectedIndex,
    required this.child,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.lightSurface0,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) => context.go(destinations[idx].path),
        destinations: destinations
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _NavDest {
  const _NavDest({
    required this.icon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final String label;
  final String path;
}