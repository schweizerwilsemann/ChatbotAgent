import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_input_provider.dart';

class VoiceInputOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onTextReady;

  const VoiceInputOverlay({
    super.key,
    required this.onClose,
    required this.onTextReady,
  });

  @override
  ConsumerState<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends ConsumerState<VoiceInputOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(voiceInputProvider.notifier);
      await notifier.startListening();
      if (!mounted) {
        await notifier.cancelListening();
      }
    });
  }

  @override
  void dispose() {
    ref.read(voiceInputProvider.notifier).cancelListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceData = ref.watch(voiceInputProvider);
    final notifier = ref.read(voiceInputProvider.notifier);

    ref.listen<VoiceInputData>(voiceInputProvider, (prev, next) {
      if (next.state == VoiceInputState.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: next.errorMessage!.contains('Cài đặt')
                ? SnackBarAction(
                    label: 'Mở Cài đặt',
                    textColor: Colors.white,
                    onPressed: () => openAppSettings(),
                  )
                : null,
          ),
        );
        notifier.clearError();
      }
    });

    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, voiceData),
                  const SizedBox(height: 24),
                  _buildWaveform(voiceData),
                  const SizedBox(height: 16),
                  _buildTranscript(voiceData),
                  const SizedBox(height: 24),
                  _buildControls(context, voiceData, notifier),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VoiceInputData data) {
    final isActive = data.state == VoiceInputState.listening;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? AppColors.error : AppColors.textHint,
            shape: BoxShape.circle,
          ),
          child: isActive ? const _PulsingDot() : null,
        ),
        const SizedBox(width: 10),
        Text(
          isActive ? 'Đang nghe...' : 'Nhấn để bắt đầu nói',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildWaveform(VoiceInputData data) {
    final isActive = data.state == VoiceInputState.listening;
    return SizedBox(
      height: 80,
      child: isActive
          ? CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _WaveformPainter(
                levels: data.audioLevels,
                color: AppColors.primary,
              ),
            )
          : Center(
              child: Icon(
                Icons.mic,
                size: 48,
                color: AppColors.textHint.withValues(alpha: 0.5),
              ),
            ),
    );
  }

  Widget _buildTranscript(VoiceInputData data) {
    final text = data.recognizedText;
    final isError = data.state == VoiceInputState.error;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isError ? AppColors.error : AppColors.divider),
      ),
      child: text.isEmpty && !isError
          ? const Text(
              'Văn bản sẽ hiển thị ở đây...',
              style: TextStyle(
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          : Text(
              text,
              style: TextStyle(
                color: isError ? AppColors.error : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    VoiceInputData data,
    VoiceInputNotifier notifier,
  ) {
    final isActive = data.state == VoiceInputState.listening;
    final hasText = data.recognizedText.trim().isNotEmpty;
    final isError = data.state == VoiceInputState.error;
    final needsSettings = data.errorMessage?.contains('Cài đặt') ?? false;

    if (isError && needsSettings) {
      return _ControlButton(
        icon: Icons.settings,
        label: 'Mở Cài đặt',
        color: AppColors.primary,
        onTap: () => openAppSettings(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasText)
          _ControlButton(
            icon: Icons.check,
            label: 'Gửi',
            color: AppColors.primary,
            onTap: () {
              final text = data.recognizedText.trim();
              notifier.stopListening();
              widget.onTextReady(text);
            },
          ),
        if (hasText) const SizedBox(width: 16),
        _ControlButton(
          icon: isActive ? Icons.stop : Icons.mic,
          label: isActive ? 'Dừng' : 'Nói',
          color: isActive ? AppColors.error : AppColors.primary,
          onTap: () {
            if (isActive) {
              notifier.stopListening();
            } else {
              notifier.startListening();
            }
          },
        ),
        if (hasText) ...[
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.refresh,
            label: 'Làm lại',
            color: AppColors.textSecondary,
            onTap: () {
              notifier.cancelListening();
              notifier.startListening();
            },
          ),
        ],
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.error
                .withValues(alpha: 0.3 + _controller.value * 0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  _WaveformPainter({required this.levels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final barWidth = size.width / levels.length;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.45;

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i].clamp(0.0, 1.0);
      final barHeight = max(2.0, level * maxBarHeight);
      final x = i * barWidth + barWidth / 2;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.4 + level * 0.6)
        ..strokeWidth = barWidth * 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.levels != levels || oldDelegate.color != color;
  }
}
