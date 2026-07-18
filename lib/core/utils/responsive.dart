// lib/core/utils/responsive.dart

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= AppConstants.mobileBreakpoint &&
        w < AppConstants.desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

  /// Returns one of three values depending on current breakpoint.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }

  /// Adaptive padding: more room on wider screens.
  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.all(
        Responsive.value<double>(
          context,
          mobile: 16,
          tablet: 24,
          desktop: 32,
        ),
      );

  /// Max content width for desktop layouts.
  static double maxContentWidth(BuildContext context) =>
      Responsive.value<double>(
        context,
        mobile: double.infinity,
        tablet: 800,
        desktop: 1200,
      );
}
