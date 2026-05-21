import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/shared/widgets/pressable_scale.dart';

class FloatingBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color? color;

  const FloatingBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.color,
  });
}

class FloatingBottomNav extends StatelessWidget {
  final List<FloatingBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const FloatingBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final safeIndex =
        selectedIndex >= 0 && selectedIndex < items.length ? selectedIndex : 0;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Align(
        heightFactor: 1,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _FloatingBottomNavTile(
                      item: items[index],
                      isSelected: index == safeIndex,
                      onTap: () => onTap(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBottomNavTile extends StatelessWidget {
  final FloatingBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingBottomNavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = item.color ?? AppColors.primary;
    final iconColor = isSelected ? activeColor : AppColors.textSecondary;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.94,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: isSelected ? 0.15 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: iconColor,
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
