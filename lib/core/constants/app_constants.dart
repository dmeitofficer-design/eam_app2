// lib/core/constants/app_constants.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
class AppConstants {
  AppConstants._();

  // Dynamic values pulled clean from runtime environments
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static const String invoiceBucket = 'invoices';

  // Tables
  static const String tableProfiles         = 'profiles';
  static const String tableHospitalClients  = 'hospital_clients';
  static const String tableInstalledMachines = 'installed_machines';
  static const String tableEngineers        = 'engineers';

  // Breakpoints
  static const double mobileBreakpoint  = 600;
  static const double tabletBreakpoint  = 900;
  static const double desktopBreakpoint = 1200;
}

class AppStrings {
  AppStrings._();

  static const String appName = 'DME CM';
  static const String tagline = 'Enterprise Asset Management';

  // Dashboard
  static const String totalClients      = 'Total Clients';
  static const String activeBrands      = 'Active Brands';
  static const String totalDivisions    = 'Divisions';
  static const String availableEngineers = 'Available Engineers';

  // Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';
  static const String roleUser  = 'user';
}
