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
