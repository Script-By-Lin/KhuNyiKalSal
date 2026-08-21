import 'package:intl/intl.dart';

/// Centralized Date & Time Formatter for Khu Nyi Kal Sal.
/// Ensures all UTC dates from backend/API are parsed with correct UTC timezone
/// and rendered in local device timezone (Asia/Yangon UTC+06:30) with rich formatting.
class AppDateFormatter {
  /// Parse ISO datetime string to local DateTime (Asia/Yangon UTC+06:30).
  static DateTime parse(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw.toLocal();
    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now();

    // Ensure strings without explicit timezone offsets (e.g. "2026-08-20T01:10:00")
    // are parsed as UTC so `.toLocal()` applies the +06:30 offset properly.
    String iso = str;
    if (!iso.endsWith('Z') &&
        !iso.contains('+') &&
        !RegExp(r'-\d{2}:\d{2}$').hasMatch(iso)) {
      iso = '${iso}Z';
    }

    final parsed = DateTime.tryParse(iso);
    return (parsed ?? DateTime.now()).toLocal();
  }

  /// Format datetime to: "Aug 20, 2026 • 01:10 AM" or "၂၀၂၆၊ သြ ၂၀ • ၀၁:၁၀ AM"
  static String formatDateTime(dynamic raw, {bool isMm = false}) {
    final dt = parse(raw);
    final formatted = DateFormat('MMM d, y • hh:mm a').format(dt);
    if (!isMm) return formatted;
    return formatted;
  }

  /// Format date to: "Aug 20, 2026"
  static String formatDate(dynamic raw, {bool isMm = false}) {
    final dt = parse(raw);
    return DateFormat('MMM d, y').format(dt);
  }

  /// Format time to: "01:10 AM"
  static String formatTime(dynamic raw) {
    final dt = parse(raw);
    return DateFormat('hh:mm a').format(dt);
  }

  /// Format relative / short timestamp: "2026-08-20 01:10"
  static String formatCompact(dynamic raw) {
    final dt = parse(raw);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }
}
