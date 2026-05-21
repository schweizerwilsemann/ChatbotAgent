import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/shared/widgets/pressable_scale.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final effectiveLeading = leading ??
        (showBackButton
            ? GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Quay lại',
                onPressed:
                    onBackPressed ?? () => Navigator.of(context).maybePop(),
              )
            : null);

    return SafeArea(
      bottom: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: preferredSize.height,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: surface.withValues(alpha: 0.78),
            child: Row(
              children: [
                if (effectiveLeading != null) ...[
                  effectiveLeading,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: DefaultTextStyle(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                    child: title,
                  ),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: AppSpacing.sm),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    final button = PressableScale(
      onTap: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
