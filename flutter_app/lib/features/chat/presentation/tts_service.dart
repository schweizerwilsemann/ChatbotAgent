import 'dart:async';

import 'package:audio_session/audio_session.dart';
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

    // Configure audio session for communication mode (enables AEC)
    await _configureAudioSession();

    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.55);
    _initialized = true;
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          usage: AndroidAudioUsage.voiceCommunication,
          contentType: AndroidAudioContentType.speech,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientExclusive,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      debugPrint('[TtsService] Audio session config failed: $e');
    }
  }

  Future<void> speak(String text, {VoiceAgentLocale? locale}) async {
    final content = _stripMarkdown(text).trim();
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

  Future<void> speakWithBargeIn(String text, {VoiceAgentLocale? locale}) async {
    final content = _stripMarkdown(text).trim();
    if (content.isEmpty) return;

    await _ensureConfigured();
    final targetLocale = locale ?? VoiceAgentText.inferLocale(content);

    try {
      await _tts.setLanguage(VoiceAgentText.ttsLocaleId(targetLocale));
    } catch (e) {
      debugPrint('[TtsService] setLanguage failed: $e');
    }

    // Lower volume to reduce echo when listening simultaneously
    await _tts.setVolume(0.6);
    await _tts.speak(content);
    // Restore volume after speaking
    await _tts.setVolume(1.0);
  }

  String _stripMarkdown(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    result = result.replaceAll(RegExp(r'`[^`]*`'), ' ');
    result = result.replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' ');
    result = result.replaceAll(RegExp(r'\$[^$]+\$'), ' ');
    result = result.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
    result = result.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    result = result.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    result = result.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    result = result.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    result = result.replaceAll(RegExp(r'_(.+?)_'), r'$1');
    result = result.replaceAll(RegExp(r'~~(.+?)~~'), r'$1');
    result = result.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^---+$', multiLine: true), '');
    result = result.replaceAll(r'$', '');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    result = _stripEmoji(result);
    result = _keepOnlyReadable(result);
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  String _stripEmoji(String text) {
    return text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
        unicode: true,
      ),
      '',
    );
  }

  String _keepOnlyReadable(String text) {
    // Keep: letters (Latin + Vietnamese), digits, whitespace, basic punctuation
    return text.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s.,;:!?()\-]', unicode: true),
      '',
    );
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    unawaited(_tts.stop());
  }
}
