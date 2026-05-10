import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';

/// A reusable, themed dialog that can be customised for many use-cases.
///
/// ## Quick usage
///
/// ```dart
/// // Simple info dialog
/// await AppDialog.show(
///   context: context,
///   title: 'Thông báo',
///   content: 'Đặt sân thành công!',
///   icon: Icons.check_circle,
///   iconColor: AppColors.success,
/// );
///
/// // Custom body + actions
/// await AppDialog.show(
///   context: context,
///   title: 'Xác nhận',
///   body: TextField(...),
///   actions: [
///     TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
///     ElevatedButton(onPressed: () => Navigator.pop(context, 'ok'), child: Text('OK')),
///   ],
/// );
/// ```
class AppDialog {
  AppDialog._();

  // ═══════════════════════════════════════════════════════════════════════
  // Generic show
  // ═══════════════════════════════════════════════════════════════════════

  /// Shows a fully customisable dialog.
  ///
  /// * [title]      — required heading text.
  /// * [content]    — optional plain-text body (ignored when [body] is set).
  /// * [body]       — optional custom widget body (takes precedence over [content]).
  /// * [icon]       — optional large icon displayed above the title.
  /// * [iconColor]  — colour for [icon]. Defaults to [AppColors.primary].
  /// * [actions]    — list of action buttons placed at the bottom.
  /// * [barrierDismissible] — whether tapping outside closes the dialog.
  /// * [maxWidth]   — max width constraint (default 400).
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? body,
    IconData? icon,
    Color? iconColor,
    List<Widget>? actions,
    bool barrierDismissible = true,
    double? maxWidth,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ──────────────────────────────────────────────
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 48,
                    color: iconColor ?? AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Title ─────────────────────────────────────────────
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                // ── Body / Content ────────────────────────────────────
                if (body != null) ...[
                  const SizedBox(height: 16),
                  body,
                ] else if (content != null && content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // ── Actions ───────────────────────────────────────────
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Convenience variants
  // ═══════════════════════════════════════════════════════════════════════

  /// Shows a **success** dialog (green check icon).
  static Future<T?> showSuccess<T>(
    BuildContext context, {
    required String title,
    String? content,
    Widget? body,
    List<Widget>? actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      content: content,
      body: body,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      actions: actions,
    );
  }

  /// Shows an **error** dialog (red error icon).
  static Future<T?> showError<T>(
    BuildContext context, {
    required String title,
    String? content,
    Widget? body,
    List<Widget>? actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      content: content,
      body: body,
      icon: Icons.error_rounded,
      iconColor: AppColors.error,
      actions: actions,
    );
  }

  /// Shows a **warning** dialog (orange warning icon).
  static Future<T?> showWarning<T>(
    BuildContext context, {
    required String title,
    String? content,
    Widget? body,
    List<Widget>? actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      content: content,
      body: body,
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warning,
      actions: actions,
    );
  }

  /// Shows an **info** dialog (blue info icon).
  static Future<T?> showInfo<T>(
    BuildContext context, {
    required String title,
    String? content,
    Widget? body,
    List<Widget>? actions,
  }) {
    return show<T>(
      context: context,
      title: title,
      content: content,
      body: body,
      icon: Icons.info_rounded,
      iconColor: AppColors.info,
      actions: actions,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Input dialog — quick data entry
  // ═══════════════════════════════════════════════════════════════════════

  /// Shows a dialog with a single [TextField] and returns the entered value.
  ///
  /// Returns `null` if dismissed or cancelled.
  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String confirmLabel = 'Xác nhận',
    String cancelLabel = 'Hủy',
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return show<String>(
      context: context,
      title: title,
      barrierDismissible: false,
      body: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() == true) {
              Navigator.of(context, rootNavigator: true).pop(controller.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
