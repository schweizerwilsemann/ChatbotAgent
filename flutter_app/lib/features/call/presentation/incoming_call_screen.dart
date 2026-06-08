import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/call/data/call_models.dart';
import 'package:sports_venue_chatbot/features/call/data/call_ringtone_service.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_provider.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  final _ringtone = CallRingtoneService();
  bool _ringtoneStarted = false;

  @override
  void initState() {
    super.initState();
    _startRingtoneIfNeeded();
  }

  void _startRingtoneIfNeeded() {
    final callState = ref.read(callProvider);
    if (callState.status == CallStatus.incomingRinging && !_ringtoneStarted) {
      _ringtoneStarted = true;
      _ringtone.start();
    }
  }

  void _stopRingtone() {
    if (_ringtoneStarted) {
      _ringtoneStarted = false;
      _ringtone.stop();
    }
  }

  @override
  void dispose() {
    _stopRingtone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    debugPrint('[IncomingCallScreen] build called, status=${callState.status}');

    ref.listen<CallState>(callProvider, (prev, next) {
      // Stop ringtone when call is no longer incoming
      if (prev?.status == CallStatus.incomingRinging &&
          next.status != CallStatus.incomingRinging) {
        _stopRingtone();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySurface,
              ),
              child: const Icon(
                Icons.phone_in_talk,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            // Caller name
            Text(
              callState.callerName ?? 'Cuộc gọi đến',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              callState.status == CallStatus.incomingRinging
                  ? 'Cuộc gọi đến...'
                  : callState.status == CallStatus.connected
                      ? 'Đang trong cuộc gọi'
                      : callState.status == CallStatus.outgoingRinging
                          ? 'Đang gọi...'
                          : '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            if (callState.status == CallStatus.connected) ...[
              const SizedBox(height: 12),
              _buildDuration(callState),
            ],
            if (callState.error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  callState.error!,
                  style: const TextStyle(
                    color: AppColors.errorLight,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Spacer(flex: 3),
            // Actions
            _buildActions(context, callState),
            const SizedBox(height: 48),
          ],
        ),
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
        color: Colors.white,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildActions(BuildContext context, CallState callState) {
    switch (callState.status) {
      case CallStatus.incomingRinging:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.call_end,
              color: AppColors.error,
              label: 'Từ chối',
              onPressed: () {
                _stopRingtone();
                ref.read(callProvider.notifier).rejectCall();
              },
            ),
            _RoundButton(
              icon: Icons.call,
              color: AppColors.success,
              label: 'Nghe',
              onPressed: () {
                _stopRingtone();
                ref.read(callProvider.notifier).acceptCall();
              },
            ),
          ],
        );

      case CallStatus.outgoingRinging:
        return Center(
          child: _RoundButton(
            icon: Icons.call_end,
            color: AppColors.error,
            label: 'Hủy',
            onPressed: () {
              ref.read(callProvider.notifier).endCall();
            },
          ),
        );

      case CallStatus.connected:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: callState.isMuted ? Icons.mic_off : Icons.mic,
              color: callState.isMuted
                  ? AppColors.warning
                  : Colors.white.withValues(alpha: 0.3),
              label: callState.isMuted ? 'Bật mic' : 'Tắt mic',
              onPressed: () => ref.read(callProvider.notifier).toggleMute(),
            ),
            _RoundButton(
              icon: Icons.call_end,
              color: AppColors.error,
              label: 'Kết thúc',
              onPressed: () {
                ref.read(callProvider.notifier).endCall();
              },
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
          elevation: 6,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
