// lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart'; 
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../../data/models/dashboard_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/presentation/widgets/developer_footer.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(const DashboardFetchRequested());
  }

  void _toggleTheme(BuildContext context) {
    ThemeController.toggleTheme();
    final isDark = ThemeController.isDarkMode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDark ? 'Switched to Dark Mode' : 'Switched to Light Mode'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showProfilePopup(BuildContext context, dynamic profile) {
    final authBloc = context.read<AuthBloc>();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final String userEmail = currentUser?.email ?? 'User Account';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true, 
      backgroundColor: Colors.transparent, 
      elevation: 0, 
      isScrollControlled: true,
      useSafeArea: false, 
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = ThemeController.isDarkMode;
        
        return Container(
          width: double.infinity, 
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20), 
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false, 
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl + MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface3 : AppColors.lightSurface3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark ? AppColors.surface3 : AppColors.lightSurface2,
                      child: Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      userEmail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      profile.isAdmin ? 'Administrator Access' : 'View-Only Access',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    
                    // ── Theme Mode Option ─────────────────────────────────
                    ListTile(
                      dense: true,
                      leading: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, 
                        color: theme.colorScheme.onSurface.withOpacity(0.7), 
                        size: 20,
                      ),
                      title: Text(
                        isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      onTap: () {
                        Navigator.of(bottomSheetContext).pop();
                        _toggleTheme(context);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    
                    // ── Change Password Option ─────────────────────────────
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.lock_reset_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                      title: Text(
                        'Change Password',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      onTap: () {
                        Navigator.of(bottomSheetContext).pop();
                        context.push('/change-password');
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      onTap: () {
                        Navigator.of(bottomSheetContext).pop();
                        authBloc.add(AuthLogoutRequested());
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                   const DeveloperFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final isDark = ThemeController.isDarkMode;

    Future<void> handleRefresh() async {
      final bloc = context.read<DashboardBloc>();
      bloc.add(const DashboardFetchRequested(forceRefresh: true));
      await bloc.stream.firstWhere((state) => state is! DashboardLoading);
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: theme.colorScheme.surface,
            onRefresh: handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── FIXED: Wrapped header layout with Expanded to stop horizontal overflows ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard', 
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Asset overview at a glance.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            tooltip: 'Toggle Theme Mode',
                            onPressed: () => _toggleTheme(context),
                          ),
                          if (profile != null && !isDesktop) ...[
                            const SizedBox(width: AppSpacing.xs),
                            GestureDetector(
                              onTap: () => _showProfilePopup(context, profile),
                              child: _RoleBadge(isAdmin: profile.isAdmin),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  BlocBuilder<DashboardBloc, DashboardState>(
                    builder: (context, state) {
                      if (state is DashboardLoading || state is DashboardInitial) {
                        return _ShimmerGrid(isDesktop: isDesktop);
                      }
                      if (state is DashboardError) {
                        return Column(
                          children: [
                            _ErrorCard(message: state.message),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: () => context
                                  .read<DashboardBloc>()
                                  .add(const DashboardFetchRequested(forceRefresh: true)),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry Loading'),
                            ),
                          ],
                        );
                      }
                      if (state is DashboardLoaded) {
                        return _AnalyticsGrid(
                          analytics: state.analytics,
                          isDesktop: isDesktop,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Row(
                    children: [
                      Text(
                        'PLATFORM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _InfoCard(
                    icon: Icons.shield_rounded,
                    title: 'Role-Based Access',
                    subtitle: profile?.isAdmin == true
                        ? 'You have Admin access — full read/write.'
                        : 'You have View-Only access — read only.',
                    accent: profile?.isAdmin == true
                        ? AppColors.accent
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoCard(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Live Sync',
                    subtitle: 'Data is synced directly from Supabase in real time.',
                    accent: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Analytics Grid ───────────────────────────────────────────

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({
    required this.analytics,
    required this.isDesktop,
  });
  final DashboardAnalytics analytics;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        label: AppStrings.totalClients,
        value: analytics.totalClients.toString(),
        icon: Icons.local_hospital_rounded,
        sublabel: 'Hospital accounts',
      ),
      _Metric(
        label: AppStrings.activeBrands,
        value: analytics.activeBrands.toString(),
        icon: Icons.verified_rounded,
        sublabel: 'Distinct brands',
      ),
      _Metric(
        label: AppStrings.totalDivisions,
        value: analytics.totalDivisions.toString(),
        icon: Icons.map_rounded,
        sublabel: 'Divisions covered',
      ),
      _Metric(
        label: AppStrings.availableEngineers,
        value: analytics.availableEngineers.toString(),
        icon: Icons.engineering_rounded,
        sublabel: 'Ready to deploy',
        routePath: '/engineers', 
      ),
      _Metric(
        label: 'Total Machines',
        value: analytics.totalMachines.toString(),
        icon: Icons.precision_manufacturing_rounded,
        sublabel: 'Installed units',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: isDesktop ? 130.0 : 135.0,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _MetricCard(metric: metrics[i]),
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.sublabel,
    this.routePath, 
  });
  final String label;
  final String value;
  final IconData icon;
  final String sublabel;
  final String? routePath; 
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;
    
    return InkWell(
      onTap: metric.routePath != null 
          ? () => context.push(metric.routePath!) 
          : null,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: isDark ? AppColors.surface0 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  metric.icon, 
                  size: 20, 
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                if (metric.routePath != null)
                  Icon(
                    Icons.arrow_forward_rounded, 
                    size: 16, 
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  metric.sublabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer ──────────────────────────────────────────────────

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.surface2 : AppColors.lightSurface2,
      highlightColor: isDark ? AppColors.surface4 : AppColors.lightSurface1,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 3 : 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          mainAxisExtent: isDesktop ? 130.0 : 135.0,
        ),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface1 : AppColors.lightSurface1,
            borderRadius: AppRadius.card,
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ───────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.accentDim : (isDark ? AppColors.surface2 : AppColors.lightSurface2),
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: isAdmin ? AppColors.accent : (isDark ? AppColors.surface3 : AppColors.lightSurface3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAdmin ? 'ADMIN' : 'VIEW ONLY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isAdmin ? const Color.fromARGB(255, 241, 248, 255) : theme.colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 16,
            color: isAdmin ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isDark ? const Color.fromARGB(255, 59, 59, 59) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle, 
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}