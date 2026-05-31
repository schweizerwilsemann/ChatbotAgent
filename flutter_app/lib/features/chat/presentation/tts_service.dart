import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_agent_language.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureConfigured() async {
    if (_initialized) return;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.48);
    _initialized = true;
  }

  Future<void> speak(String text, {VoiceAgentLocale? locale}) async {
    final content = text.trim();
    if (content.isEmpty) return;

    await _ensureConfigured();
    final targetLocale = locale ?? VoiceAgentText.inferLocale(content);

    try {
      await _tts.setLanguage(VoiceAgentText.ttsLocaleId(targetLocale));
    } catch (e) {
      debugPrint('[TtsService] setLanguage failed: $e');
    }

    await _tts.speak(content);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    unawaited(_tts.stop());
  }
}
