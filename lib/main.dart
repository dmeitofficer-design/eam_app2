// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/app_constants.dart'; 
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart'; 
import 'core/router/app_router.dart';

// Repositories
import 'features/auth/data/repositories/auth_repository.dart'; 
import 'features/clients/data/repositories/clients_repository.dart'; 
import 'features/machines/data/repositories/machines_repository.dart'; 
import 'features/dashboard/data/repositories/dashboard_repository.dart'; 
import 'features/engineers/data/repositories/engineers_repository.dart'; 
import 'features/config/data/repositories/config_repository.dart'; 

// BLoCs
import 'features/auth/presentation/bloc/auth_bloc.dart'; 
import 'features/clients/presentation/bloc/clients_bloc.dart'; 
import 'features/machines/presentation/bloc/machines_bloc.dart'; 
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart'; 
import 'features/engineers/presentation/bloc/engineers_bloc.dart'; 
import 'features/config/presentation/bloc/config_bloc.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //[cite: 6]

  // 1. Load the environment file assets safely from disk
  await dotenv.load(fileName: ".env"); //[cite: 6]

  // 2. Initialize Supabase using the loaded environment parameters once
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '', //[cite: 6]
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '', //[cite: 6]
  );

  // Initialize the theme state from local disk storage 
  await ThemeController.init(); //[cite: 6]

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]); //[cite: 6]

  runApp(const EamApp()); //[cite: 6]
}

class EamApp extends StatefulWidget {
  const EamApp({super.key});
  @override
  State<EamApp> createState() => _EamAppState();
}

class _EamAppState extends State<EamApp> {
  late final AuthRepository      _authRepo      = AuthRepository(); //[cite: 6]
  late final ClientsRepository   _clientsRepo   = ClientsRepository(); //[cite: 6]
  late final MachinesRepository  _machinesRepo  = MachinesRepository(); //[cite: 6]
  late final DashboardRepository _dashRepo      = DashboardRepository(); //[cite: 6]
  late final EngineersRepository _engineersRepo = EngineersRepository(); //[cite: 6]
  late final ConfigRepository    _configRepo    = ConfigRepository(); //[cite: 6]

  // 🌟 Removed inline cascade invocation to prevent race conditions during early navigation tree boots
  late final AuthBloc _authBloc = AuthBloc(authRepository: _authRepo); //[cite: 6]

  late final _router = buildRouter(_authBloc); //[cite: 6]

  @override
  void initState() {
    super.initState();
    // 🌟 Safely kick off token validation sequence after initial layout evaluation context is established
    _authBloc.add(AuthStarted());
  }

  @override
  void dispose() {
    _authBloc.close(); //[cite: 6]
    super.dispose(); //[cite: 6]
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepo), //[cite: 6]
        RepositoryProvider<ClientsRepository>.value(value: _clientsRepo), //[cite: 6]
        RepositoryProvider<MachinesRepository>.value(value: _machinesRepo), //[cite: 6]
        RepositoryProvider<DashboardRepository>.value(value: _dashRepo), //[cite: 6]
        RepositoryProvider<EngineersRepository>.value(value: _engineersRepo), //[cite: 6]
        RepositoryProvider<ConfigRepository>.value(value: _configRepo), //[cite: 6]
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc), //[cite: 6]
          BlocProvider<DashboardBloc>(
            create: (_) => DashboardBloc(repository: _dashRepo), //[cite: 6]
          ),
          BlocProvider<ClientsBloc>(
            create: (_) => ClientsBloc(repository: _clientsRepo), //[cite: 6]
          ),
          BlocProvider<MachinesBloc>(
            create: (_) => MachinesBloc(repository: _machinesRepo), //[cite: 6]
          ),
          BlocProvider<EngineersBloc>(
            create: (_) => EngineersBloc(repository: _engineersRepo), //[cite: 6]
          ),
          BlocProvider<ConfigBloc>(
            create: (_) =>
                ConfigBloc(repository: _configRepo)..add(ConfigLoadRequested()), //[cite: 6]
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.themeModeNotifier, //[cite: 6]
          builder: (context, themeMode, _) {
            return MaterialApp.router(
              title: AppStrings.appName, //[cite: 6]
              debugShowCheckedModeBanner: false, //[cite: 6]
              theme: AppTheme.light(), //[cite: 6]
              darkTheme: AppTheme.dark(), //[cite: 6]
              themeMode: themeMode, 
              routerConfig: _router, //[cite: 6]
            );
          },
        ),
      ),
    );
  }
}