// lib/features/dashboard/presentation/screens/dashboard_screen.dart
//
// Dashboard, built from the dashboard design: a grey header band, blue
// summary cards (clients, divisions, engineers, machines) and the platform
// notes. Cards press in with haptics; numbers count up as they load.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final authState = context.watch<AuthBloc>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final topInset = MediaQuery.of(context).padding.top;

    Future<void> handleRefresh() async {
      unawaited(HapticFeedback.mediumImpact());
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
        backgroundColor: AppColors.surface0,
        body: RefreshIndicator(
          color: _Look.blue,
          backgroundColor: AppColors.surface1,
          edgeOffset: topInset,
          onRefresh: handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header band (design: 0–60 → 84 dp, #F1F2F2) ─────────────
                ColoredBox(
                  color: _Look.band,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(isDesktop ? AppSpacing.xl : 20, topInset + 18, isDesktop ? AppSpacing.xl : 15, 16),
                    child: Row(
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
                          onToggleTheme: () {
                            HapticFeedback.mediumImpact();
                            _toggleTheme(context);
                          },
                          profile: profile,
                          onAvatarTap: profile == null
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  isDesktop ? context.go('/profile') : _showProfilePopup(context, profile);
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Body ────────────────────────────────────────────────────
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isDesktop ? AppSpacing.xl : 12, 11, isDesktop ? AppSpacing.xl : 12, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BlocBuilder<DashboardBloc, DashboardState>(
                            builder: (context, state) {
                              if (state is DashboardLoading || state is DashboardInitial) {
                                return const _ShimmerCards();
                              }
                              if (state is DashboardError) {
                                return Column(
                                  children: [
                                    _ErrorCard(message: state.message),
                                    const SizedBox(height: AppSpacing.md),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        context
                                            .read<DashboardBloc>()
                                            .add(const DashboardFetchRequested(forceRefresh: true));
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Retry Loading'),
                                    ),
                                  ],
                                );
                              }
                              if (state is DashboardLoaded) return _Cards(analytics: state.analytics);
                              return const SizedBox.shrink();
                            },
                          ),
                          const SizedBox(height: 18),

                          // ── Platform ──────────────────────────────────────
                          _Reveal(
                            index: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 3, right: 4),
                              child: Row(
                                children: [
                                  Text('Platform', style: _Look.poppins(8.5, FontWeight.w800)),
                                  const SizedBox(width: 25),
                                  Expanded(child: Container(height: 0.5, color: DesignInk.primary)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _Reveal(
                            index: 5,
                            child: _PlatformCard(
                              icon: 'shield',
                              iconSize: const Size(23, 25),
                              title: 'Role Based Access',
                              subtitle: _accessDescription(profile?.role),
                              minHeight: 59,
                              alignTop: true,
                            ),
                          ),
                          const SizedBox(height: 4.5),
                          const _Reveal(
                            index: 6,
                            child: _PlatformCard(
                              icon: 'cloud',
                              iconSize: Size(27, 18),
                              title: 'Live Data Sync',
                              subtitle: 'Data syncs directly from Supabase in real time',
                              minHeight: 42,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ── Look of the design ───────────────────────────────────────────────────────

class _Look {
  _Look._();

  static bool get _dark => ThemeController.isDarkMode;

  /// #E9F4FF cards with a #BCBEC0 hairline.
  static Color get card => _dark ? AppColors.accentSurface : const Color(0xFFE9F4FF);
  static Color get cardLine => _dark ? AppColors.surface3 : const Color(0xFFBCBEC0);

  /// #F1F2F2 header band and platform cards.
  static Color get band => _dark ? AppColors.surface1 : const Color(0xFFF1F2F2);
  static Color get arrow => _dark ? AppColors.textSecondary : DesignInk.outline;
  static const muted = Color(0xFF808285);
  static const blue = Color(0xFF27AAE1);

  static TextStyle poppins(double size, FontWeight weight, [Color? color]) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color ?? DesignInk.primary, height: 1.3);

  /// Icon from the dashboard design; black parts follow the text color.
  static Widget icon(String name, Size size) => SvgPicture.asset(
        'assets/icons/dashboard/$name.svg',
        width: size.width,
        height: size.height,
        theme: SvgTheme(currentColor: DesignInk.primary),
      );
}

// ── Cards ────────────────────────────────────────────────────────────────────

class _Cards extends StatelessWidget {
  const _Cards({required this.analytics});
  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Reveal(index: 0, child: _ClientsCard(a: a)),
        const SizedBox(height: 25),
        _Reveal(
          index: 1,
          child: SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 84, child: _DivisionsCard(a: a)),
                const SizedBox(width: 22),
                Expanded(flex: 138, child: _EngineersCard(a: a)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        _Reveal(index: 2, child: _MachinesCard(a: a)),
      ],
    );
  }
}

/// Total Clients: count, per-type counts, the two newest clients.
class _ClientsCard extends StatelessWidget {
  const _ClientsCard({required this.a});
  final DashboardAnalytics a;

  @override
  Widget build(BuildContext context) {
    final light = _Look.poppins(9.7, FontWeight.w300);
    return _PressCard(
      tooltip: 'Open clients',
      onTap: () => context.go('/clients'),
      padding: const EdgeInsets.fromLTRB(15, 12, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _Look.icon('clients', const Size(43, 43)),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text('Total Clients', style: _Look.poppins(11.3, FontWeight.w700)),
                  _CountUp(value: a.totalClients, style: _Look.poppins(27, FontWeight.w700).copyWith(height: 1.1)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, count) in a.clientsByType)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            child: _CountUp(
                              value: count,
                              textAlign: TextAlign.right,
                              style: _Look.poppins(11.3, FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(label, style: _Look.poppins(11.3, FontWeight.w400)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 2),
          Text('Latest Clients', style: light),
          const SizedBox(height: 4),
          if (a.latestClients.isEmpty)
            Row(
              children: [
                Expanded(child: Text('No clients yet', style: light.copyWith(color: _Look.muted))),
                _Arrow(color: _Look.arrow),
              ],
            ),
          for (var i = 0; i < a.latestClients.length; i++)
            _Tappable(
              onTap: () => context.push('/clients/${a.latestClients[i].id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Expanded(
                      flex: 170,
                      child: Text(a.latestClients[i].name, style: light, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 118,
                      child: Row(
                        children: [
                          _Look.icon('location', const Size(7.5, 9.5)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              a.latestClients[i].division,
                              style: light,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 22,
                      child: i == a.latestClients.length - 1 ? _Arrow(color: _Look.arrow) : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DivisionsCard extends StatelessWidget {
  const _DivisionsCard({required this.a});
  final DashboardAnalytics a;

  @override
  Widget build(BuildContext context) {
    return _PressCard(
      tooltip: 'Clients by division',
      onTap: () => context.go('/clients'),
      padding: const EdgeInsets.fromLTRB(9, 4, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 1),
            child: _CountUp(value: a.totalDivisions, style: _Look.poppins(48, FontWeight.w700).copyWith(height: 1.15)),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _Look.icon('division_pin', const Size(20, 26)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(a.totalDivisions == 1 ? 'Division' : 'Divisions', style: _Look.poppins(16, FontWeight.w700).copyWith(height: 1.1)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${a.districtsCovered} ${a.districtsCovered == 1 ? 'district' : 'districts'} covered',
                        style: _Look.poppins(9.7, FontWeight.w300),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngineersCard extends StatelessWidget {
  const _EngineersCard({required this.a});
  final DashboardAnalytics a;

  @override
  Widget build(BuildContext context) {
    return _PressCard(
      tooltip: 'Open engineers',
      onTap: () => context.go('/engineers'),
      padding: const EdgeInsets.fromLTRB(16, 10, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: _Look.icon('engineer', const Size(34, 49)),
              ),
              const Spacer(),
              _CountUp(value: a.availableEngineers, style: _Look.poppins(44, FontWeight.w700).copyWith(height: 1.0)),
              const SizedBox(width: 6),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Available Engineers', style: _Look.poppins(11.3, FontWeight.w700)),
          ),
          Row(
            children: [
              Expanded(child: Text('Ready to deploy', style: _Look.poppins(9.7, FontWeight.w300))),
              _Arrow(color: _Look.arrow),
            ],
          ),
        ],
      ),
    );
  }
}

class _MachinesCard extends StatelessWidget {
  const _MachinesCard({required this.a});
  final DashboardAnalytics a;

  @override
  Widget build(BuildContext context) {
    final light = _Look.poppins(9.7, FontWeight.w300);
    return _PressCard(
      tooltip: 'Open clients',
      onTap: () => context.go('/clients'),
      padding: const EdgeInsets.fromLTRB(8, 12, 13, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Count, warranty split.
          Expanded(
            flex: 113,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Look.icon('machine', const Size(47, 46)),
                    const SizedBox(width: 3),
                    _CountUp(value: a.totalMachines, style: _Look.poppins(27, FontWeight.w700).copyWith(height: 1.0)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text('Installed Machines', style: _Look.poppins(11.3, FontWeight.w700)),
                ),
                const SizedBox(height: 3),
                _WarrantyLine(icon: 'warranty_ok', text: '${a.inWarranty} in warranty', style: light),
                const SizedBox(height: 2),
                _WarrantyLine(icon: 'warranty_out', text: '${a.outOfWarranty} out of warranty', style: light),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Latest installs.
          Expanded(
            flex: 125,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Latest installs', style: light),
                const SizedBox(height: 4),
                if (a.latestInstalls.isEmpty)
                  Text('No machines yet', style: light.copyWith(color: _Look.muted)),
                for (final m in a.latestInstalls)
                  _Tappable(
                    onTap: () => context.push('/clients/${m.clientId}/machine/${m.machineId}'),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title, style: _Look.poppins(11.3, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            m.clientName,
                            style: _Look.poppins(8.5, FontWeight.w300),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(alignment: Alignment.centerRight, child: _Arrow(color: _Look.arrow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarrantyLine extends StatelessWidget {
  const _WarrantyLine({required this.icon, required this.text, required this.style});
  final String icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          children: [
            _Look.icon(icon, const Size(8, 10)),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}

/// Grey card with an icon, a title and a line of text.
class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.subtitle,
    required this.minHeight,
    this.alignTop = false,
  });
  final String icon;
  final Size iconSize;
  final String title;
  final String subtitle;
  final double minHeight;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _Look.band, borderRadius: BorderRadius.circular(6.5)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              SizedBox(width: 30, child: Align(alignment: Alignment.centerLeft, child: _Look.icon(icon, iconSize))),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: _Look.poppins(9.5, FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _Look.poppins(9.5, FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Motion and touch ─────────────────────────────────────────────────────────

/// Card that dips while pressed and springs back, with a tick on touch and
/// a light tap when it opens something.
class _PressCard extends StatefulWidget {
  const _PressCard({required this.child, required this.onTap, required this.padding, required this.tooltip});
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final String tooltip;

  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _set(true);
        },
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: Duration(milliseconds: _down ? 110 : 420),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _Look.card,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _Look.cardLine, width: 0.5),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A row inside a card that opens its own page; fades while pressed.
class _Tappable extends StatefulWidget {
  const _Tappable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _set(true);
        },
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedOpacity(
          opacity: _down ? 0.5 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      );
}

/// Fades and rises into place, each [index] a little after the one before.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) unawaited(_ctrl.forward());
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, (1 - _t.value) * 18), child: child),
        ),
        child: widget.child,
      );
}

/// Number that counts up to [value] (and glides to new values on refresh).
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, this.textAlign});
  final int value;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('${v.round()}', style: style, textAlign: textAlign, maxLines: 1),
      );
}

/// The design's thin arrow (10.6 × 6.7 units, stroke #58595B).
class _Arrow extends StatelessWidget {
  const _Arrow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(16, 11), painter: _ArrowPainter(color));
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final y = size.height / 2;
    canvas.drawLine(Offset(0.7, y), Offset(size.width - 0.7, y), p);
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 6, y - 4.8)
        ..lineTo(size.width - 0.7, y)
        ..lineTo(size.width - 6, y + 4.8),
      p,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _ShimmerCards extends StatelessWidget {
  const _ShimmerCards();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(17)),
        );
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.surface4,
      child: Column(
        children: [
          block(127),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(flex: 84, child: block(110)),
              const SizedBox(width: 22),
              Expanded(flex: 138, child: block(110)),
            ],
          ),
          const SizedBox(height: 13),
          block(127),
        ],
      ),
    );
  }
}

/// What the signed-in role can and cannot do.
String _accessDescription(AppRole? role) => switch (role) {
      AppRole.superAdmin => 'Super Admin - full access: manage every user, approve submissions '
          'and delete any data. Only another super admin can change a super admin.',
      AppRole.admin => 'Admin - can add, edit and approve clients, machines and engineers, and '
          'manage viewers and operators. Deleting needs a super admin\'s approval.',
      AppRole.dataEntry => 'Operator - can add clients and machines, which wait for an admin\'s '
          'approval. Cannot edit approved data, delete, or see technical details.',
      _ => 'Viewer - can see clients, basic machine info and warranty. Cannot add, edit or delete anything.',
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