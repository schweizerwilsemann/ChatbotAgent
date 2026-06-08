enum CallStatus {
  idle,
  outgoingRinging,
  incomingRinging,
  connected,
  ended,
}

class CallState {
  final CallStatus status;
  final String? callerId;
  final String? callerName;
  final String? callerRole;
  final String? calleeId;
  final String? roomId;
  final Duration duration;
  final bool isMuted;
  final String? error;

  const CallState({
    this.status = CallStatus.idle,
    this.callerId,
    this.callerName,
    this.callerRole,
    this.calleeId,
    this.roomId,
    this.duration = Duration.zero,
    this.isMuted = false,
    this.error,
  });

  CallState copyWith({
    CallStatus? status,
    String? callerId,
    String? callerName,
    String? callerRole,
    String? calleeId,
    String? roomId,
    Duration? duration,
    bool? isMuted,
    String? error,
    bool clearError = false,
    bool clearCaller = false,
  }) {
    return CallState(
      status: status ?? this.status,
      callerId: clearCaller ? null : (callerId ?? this.callerId),
      callerName: clearCaller ? null : (callerName ?? this.callerName),
      callerRole: clearCaller ? null : (callerRole ?? this.callerRole),
      calleeId: calleeId ?? this.calleeId,
      roomId: roomId ?? this.roomId,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isActive =>
      status == CallStatus.connected ||
      status == CallStatus.outgoingRinging ||
      status == CallStatus.incomingRinging;

  bool get isInCall => status == CallStatus.connected;
}
