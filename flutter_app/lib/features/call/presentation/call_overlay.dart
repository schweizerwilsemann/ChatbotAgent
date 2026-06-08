import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/call/data/call_models.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_provider.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    if (callState.status == CallStatus.idle) return const SizedBox.shrink();

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(callState),
                const SizedBox(height: 20),
                _buildStatusText(callState),
                const SizedBox(height: 8),
                if (callState.callerName != null &&
                    callState.status != CallStatus.connected)
                  Text(
                    callState.callerName!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (callState.status == CallStatus.connected)
                  _buildDuration(callState),
                if (callState.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    callState.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                _buildActions(context, ref, callState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(CallState callState) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: callState.status == CallStatus.connected
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.primarySurface,
      ),
      child: Icon(
        callState.status == CallStatus.connected
            ? Icons.call
            : Icons.phone_in_talk,
        size: 36,
        color: callState.status == CallStatus.connected
            ? AppColors.success
            : AppColors.primary,
      ),
    );
  }

  Widget _buildStatusText(CallState callState) {
    String text;
    switch (callState.status) {
      case CallStatus.outgoingRinging:
        text = 'Đang gọi...';
        break;
      case CallStatus.incomingRinging:
        text = 'Cuộc gọi đến';
        break;
      case CallStatus.connected:
        text = 'Đang trong cuộc gọi';
        break;
      default:
        text = '';
    }
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDuration(CallState callState) {
    final minutes = callState.duration.inMinutes;
    final seconds = callState.duration.inSeconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, WidgetRef ref, CallState callState) {
    switch (callState.status) {
      case CallStatus.outgoingRinging:
        return _RoundButton(
          icon: Icons.call_end,
          color: AppColors.error,
          label: 'Hủy',
          onPressed: () => ref.read(callProvider.notifier).endCall(),
        );

      case CallStatus.incomingRinging:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.call_end,
              color: AppColors.error,
              label: 'Từ chối',
              onPressed: () => ref.read(callProvider.notifier).rejectCall(),
            ),
            _RoundButton(
              icon: Icons.call,
              color: AppColors.success,
              label: 'Nghe',
              onPressed: () => ref.read(callProvider.notifier).acceptCall(),
            ),
          ],
        );

      case CallStatus.connected:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: callState.isMuted ? Icons.mic_off : Icons.mic,
              color: callState.isMuted
                  ? AppColors.warning
                  : AppColors.textSecondary,
              label: callState.isMuted ? 'Bật mic' : 'Tắt mic',
              onPressed: () => ref.read(callProvider.notifier).toggleMute(),
            ),
            _RoundButton(
              icon: Icons.call_end,
              color: AppColors.error,
              label: 'Kết thúc',
              onPressed: () => ref.read(callProvider.notifier).endCall(),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CallButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabled;

  const CallButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.call,
        color: enabled ? AppColors.success : AppColors.textHint,
      ),
      tooltip: 'Gọi điện',
      onPressed: enabled ? onPressed : null,
    );
  }
}
