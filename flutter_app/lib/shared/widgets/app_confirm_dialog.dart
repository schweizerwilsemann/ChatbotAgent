import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';

/// A themed confirm/cancel dialog.
///
/// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
///
/// ```dart
/// final confirmed = await AppConfirmDialog.show(
///   context: context,
///   title: 'Hủy đặt sân',
///   content: 'Bạn có chắc muốn hủy?',
///   confirmLabel: 'Hủy đặt sân',
///   isDestructive: true,
/// );
/// if (confirmed == true) { ... }
/// ```
class AppConfirmDialog {
  AppConfirmDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmLabel = 'Xác nhận',
    String cancelLabel = 'Hủy',
    Color? confirmColor,
    bool isDestructive = false,
  }) {
    final effectiveColor =
        confirmColor ?? (isDestructive ? AppColors.error : AppColors.primary);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
