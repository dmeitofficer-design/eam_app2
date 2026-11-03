// lib/core/theme/design_type.dart
//
// Colors and type from the redesign SVGs (Engineers Directory, Dashboard).
// Design units are scaled × 1.41 to dp (a 255-unit design ≈ 360 dp phone).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'theme_controller.dart';

class DesignInk {
  DesignInk._();

  /// #231F20 strokes and text; light text in dark mode so it stays readable.
  static Color get primary =>
      ThemeController.isDarkMode ? AppColors.textPrimary : const Color(0xFF231F20);
  static const muted = Color(0xFFAAAAAA); // designation, phone, search hint
  /// #6D6E71 page subtitles; lighter in dark mode so it stays readable.
  static Color get subtitle =>
      ThemeController.isDarkMode ? AppColors.textSecondary : const Color(0xFF6D6E71);
  static const outline = Color(0xFF58595B); // header pill border
  static const searchIcon = Color(0xFFA9A9A9);
  static const available = Color(0xFF39B54A);
  static const unavailable = Color(0xFF808285);
  static const unavailableName = Color(0xFF939598);
  static const delete = Color(0xFFFF2533);
}

class DesignType {
  DesignType._();

  /// Oddlini Bold, bundled from assets/fonts (see pubspec.yaml). Elms Sans
  /// Bold is only a fallback for characters the font doesn't have.
  static TextStyle oddlini(double size, Color color) => TextStyle(
        fontFamily: 'Oddlini',
        fontFamilyFallback: [GoogleFonts.elmsSans(fontWeight: FontWeight.w700).fontFamily!],
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        height: 1.15,
      );

  static TextStyle elms(double size, Color color, FontWeight weight) =>
      GoogleFonts.elmsSans(fontSize: size, color: color, fontWeight: weight, height: 1.2);

  static TextStyle google(double size, Color color) =>
      GoogleFonts.googleSans(fontSize: size, color: color, height: 1.2);
}
