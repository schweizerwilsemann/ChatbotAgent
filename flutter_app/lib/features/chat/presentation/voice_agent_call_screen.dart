import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_agent_controller.dart';

class VoiceAgentCallScreen extends ConsumerStatefulWidget {
  const VoiceAgentCallScreen({super.key});

  @override
  ConsumerState<VoiceAgentCallScreen> createState() =>
      _VoiceAgentCallScreenState();
}

class _VoiceAgentCallScreenState extends ConsumerState<VoiceAgentCallScreen> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceAgentControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(voiceAgentControllerProvider);
    final controller = ref.read(voiceAgentControllerProvider.notifier);

    ref.listen<VoiceAgentCallData>(voiceAgentControllerProvider, (prev, next) {
      if (next.status == VoiceAgentCallStatus.ended &&
          mounted &&
          !_closing &&
          context.canPop()) {
        _closing = true;
        context.pop();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _closing = true;
          unawaited(controller.endCall());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, callState, controller),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          _VoiceOrb(callState: callState),
                          const SizedBox(height: 28),
                          Text(
                            _statusText(callState),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            callState.localeLabel,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                          const SizedBox(height: 28),
                          _buildTranscriptPanel(context, callState),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomControls(callState, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    VoiceAgentCallData callState,
    VoiceAgentController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            color: AppColors.textPrimary,
            tooltip: 'Thu nhỏ',
            onPressed: () async {
              await _closeCall(controller);
            },
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: callState.status == VoiceAgentCallStatus.error
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: callState.status == VoiceAgentCallStatus.error
                    ? AppColors.error
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  callState.status == VoiceAgentCallStatus.error
                      ? Icons.error_outline
                      : Icons.support_agent,
                  size: 16,
                  color: callState.status == VoiceAgentCallStatus.error
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Mimo',
                  style: TextStyle(
                    color: callState.status == VoiceAgentCallStatus.error
                        ? AppColors.error
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel(
    BuildContext context,
    VoiceAgentCallData callState,
  ) {
    final liveTranscript = callState.transcript.trim();
    final error = callState.errorMessage;

    return Column(
      children: [
        if (liveTranscript.isNotEmpty)
          _SpeechLine(
            icon: Icons.mic,
            label: 'Bạn',
            text: liveTranscript,
            color: AppColors.primary,
          ),
        if (callState.lastAssistantText.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SpeechLine(
            icon: Icons.smart_toy,
            label: 'Mimo',
            text: callState.lastAssistantText,
            color: AppColors.info,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          _SpeechLine(
            icon: Icons.error_outline,
            label: 'Lỗi',
            text: error,
            color: AppColors.error,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomControls(
    VoiceAgentCallData callState,
    VoiceAgentController controller,
  ) {
    final canRetry = callState.status == VoiceAgentCallStatus.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (canRetry) ...[
            SizedBox(
              width: 72,
              height: 72,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                onPressed: controller.retryListening,
                child: const Icon(Icons.mic, size: 30),
              ),
            ),
            const SizedBox(width: 22),
          ],
          SizedBox(
            width: 76,
            height: 76,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              onPressed: () async {
                await _closeCall(controller);
              },
              child: const Icon(Icons.call_end, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeCall(VoiceAgentController controller) async {
    if (_closing) return;
    _closing = true;
    await controller.endCall();
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  String _statusText(VoiceAgentCallData callState) {
    return switch (callState.status) {
      VoiceAgentCallStatus.idle => 'Đang kết nối...',
      VoiceAgentCallStatus.greeting => 'Mimo đang chào bạn',
      VoiceAgentCallStatus.listening => 'Mimo đang nghe',
      VoiceAgentCallStatus.thinking => 'Mimo đang xử lý',
      VoiceAgentCallStatus.speaking => 'Mimo đang trả lời',
      VoiceAgentCallStatus.error => 'Mimo cần bạn thử lại',
      VoiceAgentCallStatus.ended => 'Đã kết thúc',
    };
  }
}

class _SpeechLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _SpeechLine({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  final VoiceAgentCallData callState;

  const _VoiceOrb({required this.callState});

  @override
  Widget build(BuildContext context) {
    final active = callState.isActive;
    final icon = switch (callState.status) {
      VoiceAgentCallStatus.listening => Icons.mic,
      VoiceAgentCallStatus.thinking => Icons.psychology,
      VoiceAgentCallStatus.speaking => Icons.graphic_eq,
      VoiceAgentCallStatus.error => Icons.error_outline,
      _ => Icons.support_agent,
    };

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _VoiceOrbPainter(
              levels: callState.audioLevels,
              active: active,
              status: callState.status,
            ),
          ),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: callState.status == VoiceAgentCallStatus.error
                    ? AppColors.error
                    : AppColors.primary,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 52,
              color: callState.status == VoiceAgentCallStatus.error
                  ? AppColors.error
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  final List<double> levels;
  final bool active;
  final VoiceAgentCallStatus status;

  const _VoiceOrbPainter({
    required this.levels,
    required this.active,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = status == VoiceAgentCallStatus.error
        ? AppColors.error
        : AppColors.primary;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = baseColor.withValues(alpha: active ? 0.34 : 0.16);

    canvas.drawCircle(center, 92, ringPaint);
    canvas.drawCircle(center, 108,
        ringPaint..color = ringPaint.color.withValues(alpha: 0.18));

    if (levels.isEmpty) return;

    final bars = min(levels.length, 32);
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = baseColor.withValues(alpha: 0.72);

    for (var i = 0; i < bars; i++) {
      final angle = (2 * pi / bars) * i - pi / 2;
      final level = levels[levels.length - bars + i];
      const inner = 84.0;
      final outer = inner + 12 + (level * 28);
      final start = center + Offset(cos(angle) * inner, sin(angle) * inner);
      final end = center + Offset(cos(angle) * outer, sin(angle) * outer);
      canvas.drawLine(start, end, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) {
    return oldDelegate.levels != levels ||
        oldDelegate.active != active ||
        oldDelegate.status != status;
  }
}
