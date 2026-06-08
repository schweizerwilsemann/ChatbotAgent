import 'package:flutter/services.dart';

class CallRingtoneService {
  static const _channel = MethodChannel('sports_venue_chatbot/call_ringtone');
  bool _playing = false;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;

    try {
      await _channel.invokeMethod('startRingtone');
    } catch (_) {
      _vibrateLoop();
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;

    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}

    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> _vibrateLoop() async {
    while (_playing) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_playing) break;
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }
}
