// lib/shared/extensions/date_extensions.dart

import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  /// e.g. "12 Jan 2024"
  String get shortDate => DateFormat('d MMM yyyy').format(this);

  /// e.g. "Jan 2024"
  String get monthYear => DateFormat('MMM yyyy').format(this);

  /// e.g. "12 Jan 2024 · 09:30"
  String get dateTime => DateFormat('d MMM yyyy · HH:mm').format(this);

  /// "2 days ago", "3 months ago", etc.
  String get relative {
    final diff = DateTime.now().difference(this);
    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return 'Just now';
  }

  /// True if today is within `months` months of this date
  bool isWithinMonths(int months) {
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return isAfter(cutoff);
  }
}
