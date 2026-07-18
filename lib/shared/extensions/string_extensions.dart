// lib/shared/extensions/string_extensions.dart

extension StringExt on String {
  String get titleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get sentenceCase {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// Truncate to [maxLength] chars with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}…';
  }

  bool get isValidEmail {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(this);
  }

  bool get isValidBdPhone {
    return RegExp(r'^(\+880|0)(1[3-9]\d{8})$').hasMatch(this);
  }
}

// lib/shared/extensions/int_extensions.dart

extension IntExt on int {
  /// Months → human string, e.g. 14 → "1yr 2mo"
  String get toWarrantyLabel {
    if (this <= 0) return 'Expired';
    final years  = this ~/ 12;
    final months = this % 12;
    if (years > 0 && months > 0) return '${years}yr ${months}mo';
    if (years > 0) return '${years}yr';
    return '${months}mo';
  }

  String get monthsLabel => '$this month${this == 1 ? '' : 's'}';
}
