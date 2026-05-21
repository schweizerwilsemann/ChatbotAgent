import 'package:flutter/material.dart';

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 110),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || widget.onTap == null) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
