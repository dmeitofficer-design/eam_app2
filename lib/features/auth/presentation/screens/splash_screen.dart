// lib/features/auth/presentation/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart'; 
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Staggered Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  
  late Animation<double> _loaderFade;
  
  late Animation<double> _versionFade;
  late Animation<Offset> _versionSlide;

  bool _animationCompleted = false;
  String _appVersion = ''; 

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // Slightly longer for staggered elegance
    );

    // 1. Logo & App Title Animation (0% to 60% of total duration)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Loading Indicator Animation (40% to 80% of total duration)
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    // 3. Version Info Animation (60% to 100% of total duration)
    _versionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _versionSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Execute transitions
    _animationController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _animationCompleted = true;
      });
      _evaluateNavigation(context.read<AuthBloc>().state);
    });
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
    if (!_animationCompleted) return;

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
            // Centered Brand Focus Group
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with staggered scale, fade, and upward slide[cite: 6]
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
                  
                  // ── App Title Text ─────────────────────────────────
               // ── App Title Text ─────────────────────────────────
FadeTransition(
  opacity: _logoFade,
  child: SlideTransition(
    position: _logoSlide,
    child: Text(
      'DME CLIENT MANAGER',
      style: theme.textTheme.titleMedium?.copyWith(
        fontFamily: 'Anta', // Reference registered local font family name
        color: AppColors.accent,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ),
  ),
),
                  const SizedBox(height: 24),
                  
                  // Sleek, minimal progress line that fades in right below[cite: 6]
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
            
            // Bottom Version Layer with upward entrance slide[cite: 6]
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