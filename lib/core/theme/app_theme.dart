// lib/core/theme/app_theme.dart
// Material 3 Expressive — Monotonic / Uber-inspired

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

// ────────────────────────────────────────────────────────────
// COLOUR TOKENS
// ────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Fixed dark-mode literals ─────────────────────────────────────
  // Use these directly (AppColors.darkX) only when you need a color that
  // must always stay dark regardless of the active theme — e.g. building
  // AppTheme.dark() itself, or an intentional "inverse surface". Everyday
  // UI code should use the reactive tokens further down instead.
  static const Color darkBlack       = Color(0xFF0A0A0A);
  static const Color darkSurface0    = Color.fromARGB(255, 62, 62, 63); // scaffold
  static const Color darkSurface1    = Color(0xFF1A1A1A); // cards
  static const Color darkSurface2    = Color(0xFF242424); // elevated cards
  static const Color darkSurface3    = Color(0xFF2E2E2E); // dividers / borders
  static const Color darkSurface4    = Color(0xFF3A3A3A); // input fields
  static const Color darkTextPrimary   = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkTextTertiary  = Color(0xFF616161);
  static const Color darkAccentSurface = Color.fromARGB(255, 36, 39, 41);

  // ── Fixed light-mode literals ────────────────────────────────────
  static const Color lightBlack      = Color(0xFFF9F9F9);
  static const Color lightSurface0   = Color(0xFFFFFFFF);
  static const Color lightSurface1   = Color(0xFFF4F4F4);
  static const Color lightSurface2   = Color(0xFFEBEBEB);
  static const Color lightSurface3   = Color(0xFFDDDDDD);
  static const Color lightSurface4   = Color(0xFFD0D0D0);
  static const Color lightTextPrimary   = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF555555);
  static const Color lightTextTertiary  = Color(0xFF888888);
  static const Color lightAccentSurface = Color(0xFFE0F2FE);

  // Accent — single, intentional Electric Indigo
  // (Medical tech: precision, trust, clarity)
  // Identical across both themes by design, so no dark/light split needed.
  static const Color accent        = Color.fromARGB(255, 99, 198, 255);
  static const Color accentDim     = Color.fromARGB(255, 55, 128, 176);

  // Semantic — also identical across both themes.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);

  // ── Reactive tokens ───────────────────────────────────────────────
  // What every screen should actually use: AppColors.surface0,
  // AppColors.textPrimary, etc. These resolve to the dark or light
  // literal above based on the globally active ThemeMode, so ad-hoc
  // Container/Icon/Text colors stay correct on toggle without every
  // call site needing BuildContext or a manual isDark ternary.
  static bool get _isDark => ThemeController.isDarkMode;

  static Color get black       => _isDark ? darkBlack : lightBlack;
  static Color get surface0    => _isDark ? darkSurface0 : lightSurface0;
  static Color get surface1    => _isDark ? darkSurface1 : lightSurface1;
  static Color get surface2    => _isDark ? darkSurface2 : lightSurface2;
  static Color get surface3    => _isDark ? darkSurface3 : lightSurface3;
  static Color get surface4    => _isDark ? darkSurface4 : lightSurface4;
  static Color get textPrimary   =>
      _isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      _isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary  =>
      _isDark ? darkTextTertiary : lightTextTertiary;
  static Color get accentSurface =>
      _isDark ? darkAccentSurface : lightAccentSurface;
}

// ────────────────────────────────────────────────────────────
// RADIUS TOKENS
// ────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double xs  = 6.0;
  static const double sm  = 10.0;
  static const double md  = 14.0;
  static const double lg  = 20.0;
  static const double xl  = 28.0;
  static const double xxl = 36.0;

  static BorderRadius card       = BorderRadius.circular(lg);
  static BorderRadius button     = BorderRadius.circular(sm);
  static BorderRadius chip       = BorderRadius.circular(xxl);
  static BorderRadius inputField = BorderRadius.circular(sm);
  static BorderRadius dialog     = BorderRadius.circular(xl);
}

// ────────────────────────────────────────────────────────────
// SPACING TOKENS
// ────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xxs  = 4.0;
  static const double xs   = 8.0;
  static const double sm   = 12.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double xxxl = 64.0;
}

// ────────────────────────────────────────────────────────────
// THEME BUILDER
// ────────────────────────────────────────────────────────────

// lib/core/theme/app_theme.dart
// Material 3 Expressive — Monotonic / Uber-inspired



// (Keep your AppColors, AppRadius, and AppSpacing exactly as they are)

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary:          AppColors.accent,
      onPrimary:        AppColors.darkTextPrimary,
      primaryContainer: AppColors.darkAccentSurface,
      onPrimaryContainer: AppColors.accent,
      secondary:        AppColors.darkSurface3,
      onSecondary:      AppColors.darkTextPrimary,
      secondaryContainer: AppColors.darkSurface2,
      onSecondaryContainer: AppColors.darkTextSecondary,
      tertiary:         AppColors.accentDim,
      onTertiary:       AppColors.darkTextPrimary,
      error:            AppColors.error,
      onError:          AppColors.darkTextPrimary,
      surface:          AppColors.darkSurface1,
      onSurface:        AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurface2,
      outline:          AppColors.darkSurface3,
      outlineVariant:   AppColors.darkSurface4,
      shadow:           Colors.black,
      scrim:            Colors.black87,
      inverseSurface:   AppColors.darkTextPrimary,
      onInverseSurface: AppColors.darkBlack,
      inversePrimary:   AppColors.accentDim,
    );

    final textTheme = _buildTextTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkSurface0,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface0,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.darkSurface2, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: BorderSide(color: AppColors.darkSurface3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: BorderSide(color: AppColors.darkSurface3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkTextTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: BorderSide(color: AppColors.darkSurface3),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface2,
        selectedColor: AppColors.darkAccentSurface,
        labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.darkTextSecondary),
        side: BorderSide(color: AppColors.darkSurface3),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkSurface2,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.darkTextSecondary,
        textColor: AppColors.darkTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface1,
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme: const IconThemeData(color: AppColors.darkTextTertiary),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.darkTextTertiary,
        ),
        indicatorColor: AppColors.darkAccentSurface,
        useIndicator: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface1,
        indicatorColor: AppColors.darkAccentSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accent);
          }
          return const IconThemeData(color: AppColors.darkTextTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(color: AppColors.darkTextTertiary);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface1,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.darkTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.darkAccentSurface;
          return AppColors.darkSurface3;
        }),
      ),
    );
  }

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary:          AppColors.accent,
      onPrimary:        Colors.white,
      primaryContainer: Color(0xFFEAE8FF),
      onPrimaryContainer: AppColors.accentDim,
      secondary:        AppColors.lightSurface3,
      onSecondary:      AppColors.lightTextPrimary,
      secondaryContainer: AppColors.lightSurface2,
      onSecondaryContainer: AppColors.lightTextSecondary,
      tertiary:         AppColors.accentDim,
      onTertiary:       Colors.white,
      error:            AppColors.error,
      onError:          Colors.white,
      surface:          AppColors.lightSurface1,
      onSurface:        AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurface2,
      outline:          AppColors.lightSurface3,
      outlineVariant:   AppColors.lightSurface4,
      shadow:           Colors.black12,
      scrim:            Colors.black54,
      inverseSurface:   AppColors.darkBlack,
      onInverseSurface: AppColors.darkTextPrimary,
      inversePrimary:   AppColors.accent,
    );

    final textTheme = _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFEBECEF), // High-quality light-grey background
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFEBECEF),
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.lightSurface2, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.lightSurface3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.lightSurface3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightTextTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: const BorderSide(color: AppColors.lightSurface3),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface2,
        selectedColor: AppColors.lightAccentSurface,
        labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.lightTextSecondary),
        side: const BorderSide(color: AppColors.lightSurface3),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightSurface2,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.lightTextSecondary,
        textColor: AppColors.lightTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface1,
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme: const IconThemeData(color: AppColors.lightTextTertiary),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.lightTextTertiary,
        ),
        indicatorColor: AppColors.lightAccentSurface,
        useIndicator: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface1,
        indicatorColor: AppColors.lightAccentSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accent);
          }
          return const IconThemeData(color: AppColors.lightTextTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(color: AppColors.lightTextTertiary);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurface2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface1,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.lightTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.lightAccentSurface;
          return AppColors.lightSurface3;
        }),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 57, fontWeight: FontWeight.w800,
        color: primary, letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 45, fontWeight: FontWeight.w800,
        color: primary, letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 36, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -0.2,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: secondary, letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: secondary, letterSpacing: 0.5,
      ),
    );
  }
}