// lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart'; 
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/update_dialog.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/theme/design_type.dart';
import '../../../../shared/widgets/role_avatar.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../../data/models/dashboard_analytics.dart';
import '../../../config/presentation/widgets/developer_footer.dart';
import '../../../notifications/presentation/notifications_screen.dart';

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
    
    // Check for updates after the first frame finishes rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppUpdate();
    });
  }

  Future<void> _checkAppUpdate() async {
    if (!mounted) return;

    final updateInfo = await UpdateService().checkForUpdates();

    if (updateInfo != null && updateInfo.hasUpdate && mounted) {
      await UpdateDialog.show(context, updateInfo);
    }
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

  void _showProfilePopup(BuildContext context, UserProfile profile) {
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
                color: Colors.black.withValues(alpha: 0.08),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                      '${profile.displayName} · ${profile.role.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    
                    ListTile(
                      dense: true,
                      leading: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, 
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7), 
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
                    
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.person_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
                      title: Text(
                        'My Profile',
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
                        context.go('/profile');
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    ListTile(
                      dense: true,
                      leading: Icon(Icons.lock_reset_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
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
                  // Header, from the dashboard SVG (design units × 1.41).
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: DesignType.oddlini(22, DesignInk.primary), // ~15.7 → 22
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Asset Overview at a glance',
                              style: DesignType.elms(12.7, DesignInk.subtitle, FontWeight.w300), // 9 → 12.7
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _HeaderPill(
                        onToggleTheme: () => _toggleTheme(context),
                        profile: profile,
                        onAvatarTap: profile == null
                            ? null
                            : () => isDesktop
                                ? context.go('/profile')
                                : _showProfilePopup(context, profile),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    subtitle: _accessDescription(profile?.role),
                    accent: profile?.isAdmin == true
                        ? AppColors.accent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _InfoCard(
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
        routePath: '/clients', 
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                if (metric.routePath != null)
                  Icon(
                    Icons.arrow_forward_rounded, 
                    size: 16, 
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  metric.sublabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

String _accessDescription(AppRole? role) => switch (role) {
      AppRole.superAdmin => 'Super Admin — full access, including deleting data and managing all users.',
      AppRole.admin => 'Admin — full read/write, approvals and user management.',
      AppRole.dataEntry => 'Data Entry — view clients and machines, and submit new data.',
      _ => 'Viewer — clients, machines and warranty, read only.',
    };

/// Theme toggle, notifications and the role avatar in an outlined pill
/// (design: 106.5 × 32.93 → 150 × 46, stroke #58595B).
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.onToggleTheme,
    required this.profile,
    required this.onAvatarTap,
  });

  final VoidCallback onToggleTheme;
  final UserProfile? profile;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    final isDark = ThemeController.isDarkMode;

    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 6, right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: isDark ? AppColors.textTertiary : DesignInk.outline,
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: onToggleTheme,
            icon: isDark
                ? Icon(Icons.dark_mode_rounded, size: 22, color: ink)
                : SizedBox.square(dimension: 22, child: CustomPaint(painter: _SunPainter(ink))),
          ),
          NotificationsBell(icon: Icons.notifications_active_rounded, size: 24, color: ink),
          const SizedBox(width: 4),
          if (profile != null)
            Tooltip(
              message: '${profile!.displayName} · ${profile!.role.label}',
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: RoleAvatar(role: profile!.role, size: 38),
              ),
            ),
        ],
      ),
    );
  }
}

/// The design's sun: filled center (r 2.72) with eight round-capped rays.
class _SunPainter extends CustomPainter {
  _SunPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final k = size.width / 14.4; // design sun spans ~14.4 units
    canvas.drawCircle(c, 2.72 * k, Paint()..color = color);
    final ray = Paint()
      ..color = color
      ..strokeWidth = 1.0 * k
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (4.6 * k), c + dir * (7.2 * k), ray);
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.color != color;
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
              color: accent.withValues(alpha: 0.12),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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