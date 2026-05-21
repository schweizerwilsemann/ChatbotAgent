import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';

class FloatingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow>? shadows;

  const FloatingCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.border,
    this.borderRadius = 24,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = color ?? Theme.of(context).colorScheme.surface;

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: shadows ??
            [
              BoxShadow(
                color: isDark ? const Color(0x33000000) : AppColors.shadow,
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
            ],
      ),
      child: child,
    );
  }
}
