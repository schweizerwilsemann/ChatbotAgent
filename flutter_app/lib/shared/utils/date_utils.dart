import 'package:intl/intl.dart';

/// Vietnamese date and time formatting utilities.
///
/// Provides locale-aware formatting for dates and times
/// commonly used in the Vietnamese interface.
class VietnameseDateUtils {
  VietnameseDateUtils._();

  /// Vietnamese day-of-week names (Monday through Sunday).
  static const List<String> _dayNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  /// Format a [DateTime] to Vietnamese full date string.
  ///
  /// Example: "Thứ Hai, 01/01/2024"
  static String formatDate(DateTime date) {
    final dayName = _dayNames[date.weekday - 1];
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return '$dayName, $formatted';
  }

  /// Format a [DateTime] to time string (24-hour format).
  ///
  /// Example: "14:30"
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Format a [DateTime] to time and date string.
  ///
  /// Example: "14:30 - 01/01/2024"
  static String formatDateTime(DateTime date) {
    final time = formatTime(date);
    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    return '$time - $dateStr';
  }

  /// Format a [DateTime] to relative time string (e.g., "2 giờ trước").
  ///
  /// Returns a human-readable relative time for recent dates.
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks tuần trước';
    } else {
      return formatDate(date);
    }
  }

  /// Format a [DateTime] to short date (without day name).
  ///
  /// Example: "01/01/2024"
  static String formatShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format a [DateTime] to month and year string.
  ///
  /// Example: "Tháng 1, 2024"
  static String formatMonthYear(DateTime date) {
    return 'Tháng ${date.month}, ${date.year}';
  }
}
