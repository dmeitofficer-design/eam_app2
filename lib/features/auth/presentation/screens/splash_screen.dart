// lib/features/auth/presentation/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart'; 
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/update_service.dart';
import '../bloc/auth_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _loaderFade;
  late Animation<double> _versionFade;
  late Animation<Offset> _versionSlide;

  bool _animationCompleted = false;
  bool _isMandatoryUpdateActive = false;
  String _appVersion = ''; 

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
    );
    _versionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
    );
    _versionSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic)),
    );

    // FIX: Keep _animationCompleted = false until AFTER the update check finishes
    _animationController.forward().then((_) async {
      if (!mounted) return;

      // 1. Run update check FIRST while _animationCompleted is false (blocks BlocListener navigation)
      final isBlockedByMandatory = await _checkAppUpdate();

      if (!mounted) return;

      // 2. Mark animation completed ONLY AFTER update dialog closes or finishes
      setState(() {
        _animationCompleted = true;
      });

      // 3. Navigate only if not blocked by a mandatory update
      if (!isBlockedByMandatory) {
        _evaluateNavigation(context.read<AuthBloc>().state);
      }
    });
  }

  Future<bool> _checkAppUpdate() async {
    if (!mounted) return false;
    try {
      final updateInfo = await UpdateService().checkForUpdates();

      if (updateInfo != null && updateInfo.hasUpdate && mounted) {
        if (updateInfo.isMandatory) {
          setState(() {
            _isMandatoryUpdateActive = true;
          });
        }

        await showDialog(
          context: context,
          barrierDismissible: !updateInfo.isMandatory,
          builder: (dialogContext) => PopScope(
            canPop: !updateInfo.isMandatory,
            child: AlertDialog(
              title: Text('Update Available (${updateInfo.latestVersion})'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(updateInfo.releaseNotes ?? 'A new version of DME CM is available.'),
                  if (updateInfo.isMandatory) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'This update is required to continue using the app.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!updateInfo.isMandatory)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Later'),
                  ),
                ElevatedButton(
                  onPressed: () => UpdateService.launchUpdateUrl(updateInfo.downloadUrl),
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ),
        );

        return updateInfo.isMandatory;
      }
    } catch (e) {
      debugPrint('SPLASH UPDATE CHECK ERROR: $e');
    }
    return false;
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = '';
        });
      }
    }
  }

  void _evaluateNavigation(AuthState state) {
    if (!_animationCompleted || _isMandatoryUpdateActive) return;

    if (state is AuthAuthenticated) {
      context.go('/dashboard');
    } else if (state is AuthUnauthenticated || state is AuthError) {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.lightSurface0,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          _evaluateNavigation(state);
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: SvgPicture.asset(
                          'assets/icons/dasgboard_logo.svg',
                          width: 130,
                          height: 130,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: Text(
                        'DME CLIENT MANAGER',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'Anta',
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _loaderFade,
                    child: SizedBox(
                      width: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: AppColors.lightSurface2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_appVersion.isNotEmpty)
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _versionFade,
                  child: SlideTransition(
                    position: _versionSlide,
                    child: Center(
                      child: Text(
                        _appVersion,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}