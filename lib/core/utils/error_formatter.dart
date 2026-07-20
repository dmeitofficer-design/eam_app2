// lib/core/utils/error_formatter.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorFormatter {
  static String format(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is AuthException) {
      // Catch network-specific auth failures
      if (error.statusCode == '504' || error.message.toLowerCase().contains('network') || error.message.toLowerCase().contains('failed to fetch')) {
        return 'Network request timed out. Please check your internet connection.';
      }
      return error.message;
    }

    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socketexception') ||
        errorString.contains('clientexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network_error') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}