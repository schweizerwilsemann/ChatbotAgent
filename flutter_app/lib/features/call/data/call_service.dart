import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnCallEvent = void Function(Map<String, dynamic> data);

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _callTimer;

  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Duration _callDuration = Duration.zero;
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  Future<MediaStream> _getUserAudio() async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> startCall({
    required String roomId,
    required String token,
    required String calleeId,
    required OnCallEvent onEvent,
  }) async {
    _localStream = await _getUserAudio();

    _peerConnection = await createPeerConnection(_iceServers);

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (candidate) {
      onEvent({
        'type': 'call_ice_candidate',
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onEvent({'type': 'call_end', 'reason': 'connection_failed'});
      }
    };

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    onEvent({
      'type': 'call_offer',
      'callee_id': calleeId,
      'sdp': offer.sdp,
      'sdp_type': offer.type,
    });
  }

  Future<void> handleOffer({
    required Map<String, dynamic> sdpData,
    required OnCallEvent onEvent,
  }) async {
    _localStream = await _getUserAudio();

    _peerConnection = await createPeerConnection(_iceServers);

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (candidate) {
      onEvent({
        'type': 'call_ice_candidate',
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onEvent({'type': 'call_end', 'reason': 'connection_failed'});
      }
    };

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdpData['sdp'], sdpData['sdp_type'] ?? 'offer'),
    );

    // Process any ICE candidates that arrived before peer connection was ready
    await _flushPendingIceCandidates();
  }

  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return {
      'sdp': answer.sdp,
      'sdp_type': answer.type,
    };
  }

  Future<void> handleAnswer(Map<String, dynamic> sdpData) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdpData['sdp'], sdpData['sdp_type'] ?? 'answer'),
    );
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) {
      // Queue for later processing
      _pendingIceCandidates.add(candidateData);
      return;
    }
    await _addIceCandidate(candidateData);
  }

  Future<void> _addIceCandidate(Map<String, dynamic> candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _flushPendingIceCandidates() async {
    final candidates = List<Map<String, dynamic>>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidateData in candidates) {
      await _addIceCandidate(candidateData);
    }
  }

  void startCallTimer() {
    _callDuration = Duration.zero;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      _durationController.add(_callDuration);
    });
  }

  void stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void toggleMute(bool mute) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !mute;
      }
    }
  }

  Future<void> endCall() async {
    stopCallTimer();
    _callDuration = Duration.zero;
    _pendingIceCandidates.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    await _peerConnection?.close();
    _peerConnection = null;
  }

  void dispose() {
    endCall();
    _durationController.close();
  }
}
