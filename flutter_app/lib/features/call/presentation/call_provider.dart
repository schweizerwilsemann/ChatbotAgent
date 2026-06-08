import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/call/data/call_models.dart';
import 'package:sports_venue_chatbot/features/call/data/call_service.dart';

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier();
});

class CallNotifier extends StateNotifier<CallState> {
  final CallService _service = CallService();
  StreamSubscription<Duration>? _durationSub;
  void Function(Map<String, dynamic>)? _sendSignaling;

  final StreamController<Map<String, dynamic>> _signalingController =
      StreamController<Map<String, dynamic>>.broadcast();

  CallNotifier() : super(const CallState()) {
    _durationSub = _service.durationStream.listen((d) {
      if (mounted) state = state.copyWith(duration: d);
    });
  }

  Stream<Map<String, dynamic>> get signalingStream =>
      _signalingController.stream;

  void attachSignaling(void Function(Map<String, dynamic>) send) {
    // Don't override signaling during an active call
    if (!state.isActive) {
      _sendSignaling = send;
    }
  }

  void handleOutgoingSignaling(Map<String, dynamic> data) {
    _signalingController.add(data);
    _sendSignaling?.call(data);
  }

  Future<void> startCall({
    required String roomId,
    required String calleeId,
    required String token,
  }) async {
    if (state.isActive) return;

    // Clean up any previous WebRTC session
    await _service.endCall();

    state = state.copyWith(
      status: CallStatus.outgoingRinging,
      roomId: roomId,
      calleeId: calleeId,
      clearError: true,
    );

    try {
      await _service.startCall(
        roomId: roomId,
        token: token,
        calleeId: calleeId,
        onEvent: _handleServiceEvent,
      );
    } catch (e) {
      state = state.copyWith(
        status: CallStatus.idle,
        error: 'Không thể bắt đầu cuộc gọi: $e',
      );
    }
  }

  Future<void> handleIncomingCall({
    required String callerId,
    required String callerName,
    required String callerRole,
    required String roomId,
    required Map<String, dynamic> sdpData,
  }) async {
    if (state.isActive) {
      _sendSignaling?.call({
        'type': 'call_reject',
        'reason': 'busy',
      });
      return;
    }

    state = state.copyWith(
      status: CallStatus.incomingRinging,
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      roomId: roomId,
    );

    try {
      // Clean up any previous WebRTC session before handling new offer
      await _service.endCall();
      await _service.handleOffer(
        sdpData: sdpData,
        onEvent: _handleServiceEvent,
      );
    } catch (e) {
      state = state.copyWith(
        status: CallStatus.idle,
        error: 'Không thể xử lý cuộc gọi đến: $e',
      );
    }
  }

  Future<void> acceptCall() async {
    if (state.status != CallStatus.incomingRinging) return;

    try {
      final answer = await _service.createAnswer();
      _sendSignaling?.call({
        'type': 'call_answer',
        ...answer,
      });
      state = state.copyWith(status: CallStatus.connected);
      _service.startCallTimer();
    } catch (e) {
      state = state.copyWith(
        status: CallStatus.idle,
        error: 'Không thể chấp nhận cuộc gọi: $e',
      );
    }
  }

  void rejectCall() {
    if (state.status != CallStatus.incomingRinging) return;
    _sendSignaling?.call({
      'type': 'call_reject',
      'reason': 'rejected',
    });
    _cleanup();
  }

  Future<void> endCall() async {
    _sendSignaling?.call({
      'type': 'call_end',
      'reason': 'ended',
    });
    await _cleanup();
  }

  void handleSignalingMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'call_offer':
        final callerId = data['caller_id']?.toString() ?? '';
        final callerName = data['caller_name']?.toString() ?? '';
        final callerRole = data['caller_role']?.toString() ?? '';
        final roomId = data['room_id']?.toString() ?? state.roomId ?? '';
        final sdpData = {
          'sdp': data['sdp'],
          'sdp_type': data['sdp_type'] ?? 'offer',
        };
        handleIncomingCall(
          callerId: callerId,
          callerName: callerName,
          callerRole: callerRole,
          roomId: roomId,
          sdpData: sdpData,
        );
        break;

      case 'call_answer':
        final sdpData = {
          'sdp': data['sdp'],
          'sdp_type': data['sdp_type'] ?? 'answer',
        };
        _service.handleAnswer(sdpData);
        state = state.copyWith(status: CallStatus.connected);
        _service.startCallTimer();
        break;

      case 'call_ice_candidate':
        final candidate = data['candidate'] as Map<String, dynamic>?;
        if (candidate != null) {
          _service.handleIceCandidate(candidate);
        }
        break;

      case 'call_end':
        _cleanup();
        break;

      case 'call_reject':
        final reason = data['reason'] as String? ?? 'rejected';
        state = state.copyWith(
          status: CallStatus.idle,
          error: reason == 'busy'
              ? 'Nhân viên đang bận cuộc gọi khác'
              : 'Cuộc gọi bị từ chối',
        );
        _cleanup();
        break;

      case 'call_busy':
        state = state.copyWith(
          status: CallStatus.idle,
          error: 'Nhân viên đang bận cuộc gọi khác',
        );
        _cleanup();
        break;
    }
  }

  void toggleMute() {
    final mute = !state.isMuted;
    _service.toggleMute(mute);
    state = state.copyWith(isMuted: mute);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _handleServiceEvent(Map<String, dynamic> event) {
    _sendSignaling?.call(event);
  }

  Future<void> _cleanup() async {
    _service.stopCallTimer();
    await _service.endCall();
    if (mounted) {
      state = state.copyWith(
        status: CallStatus.idle,
        clearCaller: true,
        isMuted: false,
      );
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _signalingController.close();
    _service.dispose();
    super.dispose();
  }
}
