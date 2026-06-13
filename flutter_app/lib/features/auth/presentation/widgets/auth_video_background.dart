import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:video_player/video_player.dart';

class AuthVideoBackground extends StatefulWidget {
  const AuthVideoBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AuthVideoBackground> createState() => _AuthVideoBackgroundState();
}

class _AuthVideoBackgroundState extends State<AuthVideoBackground> {
  static const _assetPath = 'assets/main/welcome_background_video.mp4';

  late final VideoPlayerController _controller;
  bool _isVideoReady = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      _assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    unawaited(_startVideo());
  }

  Future<void> _startVideo() async {
    try {
      await _controller.initialize();
      if (_isDisposed) return;

      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();
      if (!mounted) return;

      setState(() => _isVideoReady = true);
    } catch (error) {
      debugPrint('Unable to play auth background video: $error');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF211915)),
        if (_isVideoReady)
          IgnorePointer(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
        const ColoredBox(color: Color(0x59000000)),
        widget.child,
      ],
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(28);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: AppColors.textPrimary.withValues(alpha: 0.1),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: AppColors.primary,
                selectionHandleColor: AppColors.primary,
              ),
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.46),
                labelStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.94),
                ),
                floatingLabelStyle: const TextStyle(
                  color: AppColors.primary,
                ),
                hintStyle: TextStyle(
                  color: AppColors.textHint.withValues(alpha: 0.9),
                ),
                helperStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
                errorStyle: const TextStyle(color: AppColors.error),
                prefixIconColor: AppColors.textSecondary,
                suffixIconColor: AppColors.textSecondary,
                border: inputBorder,
                enabledBorder: inputBorder,
                disabledBorder: inputBorder,
                errorBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.4,
                  ),
                ),
                focusedBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
