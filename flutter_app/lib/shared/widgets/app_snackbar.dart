import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';

/// Pre-built snackbar type for consistent messaging.
enum SnackBarType { success, error, warning, info }

/// Convenience methods for showing themed snackbars.
///
/// ```dart
/// AppSnackBar.showSuccess(context, 'Đặt sân thành công!');
/// AppSnackBar.showError(context, 'Đã xảy ra lỗi', actionLabel: 'Thử lại', onAction: () => retry());
/// AppSnackBar.showWarning(context, 'Vui lòng nhập số sân hợp lệ.');
/// ```
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _colorForType(type),
        behavior: SnackBarBehavior.floating,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      show(context, message, type: SnackBarType.success);

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message,
        type: SnackBarType.error,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void showWarning(BuildContext context, String message) =>
      show(context, message, type: SnackBarType.warning);

  static Color _colorForType(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return AppColors.success;
      case SnackBarType.error:
        return AppColors.error;
      case SnackBarType.warning:
        return AppColors.warning;
      case SnackBarType.info:
        return AppColors.info;
    }
  }
}
