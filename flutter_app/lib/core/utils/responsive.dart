import 'package:flutter/material.dart';

/// Responsive breakpoints and helpers.
///
/// On tablets the content should not stretch to full width —
/// instead it's centred inside a [ResponsiveContainer] with a max width.
class Responsive {
  Responsive._();

  // ── Breakpoints (logical pixels) ───────────────────────────────────
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  /// Returns `true` when the screen width is < 600 dp (phone portrait).
  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;

  /// Returns `true` when the screen width is >= 600 dp (tablet / landscape).
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= phone;

  /// Returns `true` when the screen width is >= 900 dp (large tablet / desktop).
  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// Returns `true` when the screen width is >= 1200 dp (desktop).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  // ── Dynamic helpers ────────────────────────────────────────────────

  /// Responsive horizontal padding: 20 on phone, 32 on tablet+.
  static double horizontalPadding(BuildContext context) =>
      isPhone(context) ? 20 : 32;

  /// Returns the number of grid columns for a menu / product grid.
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return 5;
    if (width >= tablet) return 3;
    return 2; // phone
  }

  /// Returns the grid childAspectRatio for the menu.
  static double menuGridAspectRatio(BuildContext context) =>
      isPhone(context) ? 0.72 : 0.78;

  /// Returns the number of suggestion columns for the chat welcome screen.
  static int suggestionChipColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tablet) return 2;
    return 1;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ResponsiveContainer — centres content and limits max width on tablets
// ═══════════════════════════════════════════════════════════════════════

/// Wraps a child widget so that on tablet+ screens the content is
/// horizontally centred and constrained to [maxWidth].
///
/// On phones the child stretches to full width.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
