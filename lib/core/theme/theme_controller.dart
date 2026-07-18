// lib/core/theme/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  // REMOVED 'private' keywords here:
  static const String _themePreferenceKey = 'is_dark_mode';
  static SharedPreferences? _prefs;

  // Global notifier holding the current ThemeMode (defaulting to light)
  static final ValueNotifier<ThemeMode> themeModeNotifier = 
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  /// Initialize local preferences and load the saved theme
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Read the saved value. If it doesn't exist yet, default to false (light mode)
    final isDarkSaved = _prefs?.getBool(_themePreferenceKey) ?? false;
    
    themeModeNotifier.value = isDarkSaved ? ThemeMode.dark : ThemeMode.light;
  }

  /// Toggle the theme and persist the change locally
  static Future<void> toggleTheme() async {
    if (isDarkMode) {
      themeModeNotifier.value = ThemeMode.light;
      await _prefs?.setBool(_themePreferenceKey, false);
    } else {
      themeModeNotifier.value = ThemeMode.dark;
      await _prefs?.setBool(_themePreferenceKey, true);
    }
  }
}