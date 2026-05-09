import 'package:flutter/material.dart';

/// An [ElevatedButton] that shows a loading spinner when [isLoading] is true.
///
/// ```dart
/// // Simple button
/// LoadingButton(
///   label: 'Đăng nhập',
///   onPressed: _handleLogin,
///   isLoading: loginState.isLoading,
///   width: double.infinity,
/// )
///
/// // Button with icon
/// LoadingButton(
///   label: 'Xác nhận đặt sân',
///   icon: Icons.check_circle_outline,
///   onPressed: _confirmBooking,
///   isLoading: bookingState.isCreating,
///   backgroundColor: courtColor,
/// )
/// ```
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double? width;
  final double? height;

  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveFg = foregroundColor ?? Colors.white;

    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: effectiveOnPressed,
            icon: _buildIcon(effectiveFg),
            label: Text(label),
            style: _buildStyle(),
          )
        : ElevatedButton(
            onPressed: effectiveOnPressed,
            style: _buildStyle(),
            child: _buildChild(effectiveFg),
          );

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: button);
    }

    return button;
  }

  Widget _buildIcon(Color fgColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
      );
    }
    return Icon(icon, size: 20);
  }

  Widget _buildChild(Color fgColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
      );
    }
    return Text(label);
  }

  ButtonStyle? _buildStyle() {
    if (backgroundColor == null) return null;
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor ?? Colors.white,
    );
  }
}
