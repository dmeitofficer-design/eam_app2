// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart'; 
import '../../features/auth/presentation/screens/change_password_page.dart'; 
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/machines/presentation/screens/machine_detail_screen.dart';
import '../../features/machines/presentation/bloc/machines_bloc.dart';
import '../../features/config/data/repositories/config_repository.dart';
import '../../features/config/presentation/bloc/config_bloc.dart';
import '../../features/engineers/presentation/bloc/engineers_bloc.dart';
import '../../features/engineers/data/repositories/engineers_repository.dart';
import '../../features/engineers/presentation/screens/engineers_screen.dart'; // Added Import for Engineers Directory Screen
import '../shell/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/', 
    refreshListenable: GoRouterAuthNotifier(authBloc),
    redirect: (context, state) {
      final auth = authBloc.state;
      final isLoggedIn = auth is AuthAuthenticated;
      final isSplash = state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';

      // 1. Allow the splash screen route to remain on-screen during boot orchestration//[cite: 8]
      if (isSplash) return null;//[cite: 8]

      // 2. Standard authentication security layout gates//[cite: 8]
      if (!isLoggedIn && !isLoggingIn) return '/login';//[cite: 8]
      if (isLoggedIn && isLoggingIn) return '/dashboard';//[cite: 8]
      
      return null;//[cite: 8]
    },
    routes: [
      // Splash Route Entry//[cite: 8]
      GoRoute(
        path: '/',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),//[cite: 8]
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),//[cite: 8]
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),//[cite: 8]
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _noTransition(
              const DashboardScreen(),
              state.pageKey,
            ),//[cite: 8]
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => _noTransition(
              const ClientsScreen(),
              state.pageKey,
            ),//[cite: 8]
            routes: [
              GoRoute(
                path: ':clientId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => ClientDetailScreen(
                  clientId: state.pathParameters['clientId']!,
                ),//[cite: 8]
                routes: [
                  GoRoute(
                    path: 'machine/:machineId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final clientId = state.pathParameters['clientId']!;
                      final machineId = state.pathParameters['machineId']!;
                      return MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (_) => MachinesBloc(
                              repository: context.read(),
                            ),
                          ),//[cite: 8]
                          BlocProvider(
                            create: (_) => EngineersBloc(
                              repository: context.read<EngineersRepository>(),
                            ),
                          ),//[cite: 8]
                          BlocProvider(
                            create: (_) => ConfigBloc(
                              repository: context.read<ConfigRepository>(),
                            )..add(ConfigLoadRequested()),
                          ),//[cite: 8]
                        ],
                        child: MachineDetailScreen(
                          machineId: machineId,
                          clientId: clientId,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          
          // ── Engineers Directory Screen Route ─────────────────────────────
          GoRoute(
            path: '/engineers',
            pageBuilder: (context, state) => _noTransition(
              const EngineersScreen(),
              state.pageKey,
            ),
          ),

          // ── Secure Password Custom Update Route Layer ───────────────────
          GoRoute(
            path: '/change-password',
            pageBuilder: (context, state) => _noTransition(
              const ChangePasswordPage(),
              state.pageKey,
            ),//[cite: 8]
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),//[cite: 8]
  );
}

Page<dynamic> _noTransition(Widget child, ValueKey<String> key) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (_, __, ___, child) => child,
  );//[cite: 8]
}

class GoRouterAuthNotifier extends ChangeNotifier {
  GoRouterAuthNotifier(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());//[cite: 8]
  }
}