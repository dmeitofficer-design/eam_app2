// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/device_management_bloc.dart'; 
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/change_password_page.dart';
import '../../features/auth/presentation/screens/device_management_screen.dart'; 
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/machines/presentation/screens/machine_detail_screen.dart';
import '../../features/machines/presentation/bloc/machines_bloc.dart';
import '../../features/config/data/repositories/config_repository.dart';
import '../../features/config/presentation/bloc/config_bloc.dart';
import '../../features/engineers/presentation/bloc/engineers_bloc.dart';
import '../../features/engineers/data/repositories/engineers_repository.dart';
import '../../features/engineers/presentation/screens/engineers_screen.dart';
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
      final isInitialBoot = auth is AuthInitial || auth is AuthLoading;
      
      final isSplash = state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';

      // 1. Hold on the splash screen ONLY while the session integrity validation is checking
      if (isInitialBoot) {
        return isSplash ? null : '/';
      }

      // 2. Cold-boot completion routing resolution from Splash Screen
      if (isSplash) {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      // 3. Standard active runtime security layer gates
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _noTransition(
              const DashboardScreen(),
              state.pageKey,
            ),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => _noTransition(
              const ClientsScreen(),
              state.pageKey,
            ),
            routes: [
              GoRoute(
                path: ':clientId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => ClientDetailScreen(
                  clientId: state.pathParameters['clientId']!,
                ),
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
                          ),
                          BlocProvider(
                            create: (_) => EngineersBloc(
                              repository: context.read<EngineersRepository>(),
                            ),
                          ),
                          BlocProvider(
                            create: (_) => ConfigBloc(
                              repository: context.read<ConfigRepository>(),
                            )..add(ConfigLoadRequested()),
                          ),
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
          
          GoRoute(
            path: '/engineers',
            pageBuilder: (context, state) => _noTransition(
              const EngineersScreen(),
              state.pageKey,
            ),
          ),

          GoRoute(
            path: '/change-password',
            pageBuilder: (context, state) => _noTransition(
              const ChangePasswordPage(),
              state.pageKey,
            ),
          ),

          GoRoute(
            path: '/device-management',
            pageBuilder: (context, state) => _noTransition(
              BlocProvider(
                create: (context) => DeviceManagementBloc(context.read()),
                child: const DeviceManagementScreen(),
              ),
              state.pageKey,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}

Page<dynamic> _noTransition(Widget child, ValueKey<String> key) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

class GoRouterAuthNotifier extends ChangeNotifier {
  GoRouterAuthNotifier(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}