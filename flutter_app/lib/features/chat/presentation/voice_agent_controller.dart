import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_provider.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/tts_service.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_agent_language.dart';

enum VoiceAgentCallStatus {
  idle,
  greeting,
  listening,
  thinking,
  speaking,
  error,
  ended,
}

class VoiceAgentCallData {
  final VoiceAgentCallStatus status;
  final String transcript;
  final String lastUserText;
  final String lastAssistantText;
  final String? errorMessage;
  final String localeLabel;
  final List<double> audioLevels;

  const VoiceAgentCallData({
    this.status = VoiceAgentCallStatus.idle,
    this.transcript = '',
    this.lastUserText = '',
    this.lastAssistantText = '',
    this.errorMessage,
    this.localeLabel = 'VI/EN',
    this.audioLevels = const [],
  });

  bool get isActive =>
      status == VoiceAgentCallStatus.greeting ||
      status == VoiceAgentCallStatus.listening ||
      status == VoiceAgentCallStatus.thinking ||
      status == VoiceAgentCallStatus.speaking;

  VoiceAgentCallData copyWith({
    VoiceAgentCallStatus? status,
    String? transcript,
    String? lastUserText,
    String? lastAssistantText,
    String? errorMessage,
    String? localeLabel,
    List<double>? audioLevels,
    bool clearError = false,
  }) {
    return VoiceAgentCallData(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      lastUserText: lastUserText ?? this.lastUserText,
      lastAssistantText: lastAssistantText ?? this.lastAssistantText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localeLabel: localeLabel ?? this.localeLabel,
      audioLevels: audioLevels ?? this.audioLevels,
    );
  }
}

class VoiceAgentController extends StateNotifier<VoiceAgentCallData> {
  final ChatNotifier _chatNotifier;
  final TtsService _ttsService;
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _active = false;
  bool _startingListen = false;
  bool _hasRecognizedText = false;
  bool _disposed = false;
  List<String?> _localeIds = const [];
  Timer? _retryTimer;
  VoiceAgentLocale _lastSpokenLocale = VoiceAgentLocale.vietnamese;

  static const int _maxLevels = 32;

  VoiceAgentController({
    required ChatNotifier chatNotifier,
    required TtsService ttsService,
  })  : _chatNotifier = chatNotifier,
        _ttsService = ttsService,
        super(const VoiceAgentCallData());

  Future<void> start() async {
    if (_active || _disposed) return;

    _active = true;
    final ready = await _ensureInitialized();
    if (!ready) {
      _active = false;
      return;
    }

    state = state.copyWith(status: VoiceAgentCallStatus.greeting);
    await _speak(
      'Mình đây, bạn cần hỗ trợ gì?',
      locale: VoiceAgentLocale.vietnamese,
    );
    await _startListening();
  }

  Future<void> endCall({bool sayGoodbye = false}) async {
    final goodbyeText = _lastSpokenLocale == VoiceAgentLocale.english
        ? 'Ending the call.'
        : 'Mình kết thúc cuộc gọi nhé.';

    _active = false;
    _startingListen = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_initialized) {
      await _speech.cancel();
    }

    if (sayGoodbye) {
      if (!_disposed) {
        state = state.copyWith(status: VoiceAgentCallStatus.speaking);
      }
      try {
        await _ttsService.speak(goodbyeText, locale: _lastSpokenLocale);
      } catch (e, st) {
        debugPrint('[VoiceAgent] goodbye TTS exception: $e\n$st');
      }
    } else {
      await _ttsService.stop();
    }

    if (!_disposed) {
      state = state.copyWith(status: VoiceAgentCallStatus.ended);
    }
  }

  Future<void> _ensureNextTurn() async {
    if (!_active || _disposed) return;
    await _startListening();
  }

  Future<void> retryListening() async {
    if (!_active || _disposed || _startingListen) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_initialized) {
      await _speech.cancel();
    }
    await _startListening();
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;

    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        state = state.copyWith(
          status: VoiceAgentCallStatus.error,
          errorMessage: 'Cần cấp quyền microphone để nói chuyện với Mimo.',
        );
        return false;
      }
    } else if (micStatus.isPermanentlyDenied) {
      state = state.copyWith(
        status: VoiceAgentCallStatus.error,
        errorMessage:
            'Quyền microphone bị từ chối. Vào Cài đặt để cấp lại quyền.',
      );
      return false;
    }

    try {
      _initialized = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        options: [SpeechToText.androidNoBluetooth],
      );
      if (!_initialized) {
        state = state.copyWith(
          status: VoiceAgentCallStatus.error,
          errorMessage: 'Nhận dạng giọng nói không khả dụng trên thiết bị này.',
        );
        return false;
      }

      _localeIds = await _resolveLocales();
      return true;
    } catch (e, st) {
      debugPrint('[VoiceAgent] initialize exception: $e\n$st');
      state = state.copyWith(
        status: VoiceAgentCallStatus.error,
        errorMessage: 'Không thể khởi tạo voice agent: $e',
      );
      return false;
    }
  }

  Future<List<String?>> _resolveLocales() async {
    try {
      final locales = await _speech.locales();
      final vi = _findLocale(
        locales,
        [VoiceAgentText.speechLocaleId(VoiceAgentLocale.vietnamese), 'vi-VN'],
      );
      final en = _findLocale(
        locales,
        [VoiceAgentText.speechLocaleId(VoiceAgentLocale.english), 'en-US'],
      );

      final ids = <String?>[
        if (vi != null) vi,
        if (en != null) en,
        null,
      ];
      return ids.toSet().toList();
    } catch (e, st) {
      debugPrint('[VoiceAgent] locales exception: $e\n$st');
      return const ['vi_VN', 'en_US', null];
    }
  }

  String? _findLocale(List<LocaleName> locales, List<String> candidates) {
    for (final candidate in candidates) {
      for (final locale in locales) {
        if (locale.localeId == candidate) return locale.localeId;
      }
    }

    final prefix = candidates.first.split(RegExp('[-_]')).first.toLowerCase();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }

    return null;
  }

  Future<void> _startListening() async {
    if (!_active || _disposed || _startingListen) return;
    _startingListen = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _hasRecognizedText = false;

    final localeId = _nextLocaleId();
    state = state.copyWith(
      status: VoiceAgentCallStatus.listening,
      transcript: '',
      audioLevels: const [],
      localeLabel: _localeLabel(localeId),
      clearError: true,
    );

    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e, st) {
      debugPrint('[VoiceAgent] listen exception: $e\n$st');
      _showListenError('Không mở được micro. Chạm mic để thử lại.');
    } finally {
      _startingListen = false;
    }
  }

  String? _nextLocaleId() {
    if (_localeIds.isEmpty) return null;
    // Always prefer Vietnamese locale for listening
    final viIndex = _localeIds.indexWhere(
      (id) => id != null && id.toLowerCase().startsWith('vi'),
    );
    if (viIndex >= 0) return _localeIds[viIndex];
    // Fallback to first available locale
    return _localeIds.first;
  }

  String _localeLabel(String? localeId) {
    if (localeId == null) return 'Default';
    final lower = localeId.toLowerCase();
    if (lower.startsWith('vi')) return 'VI';
    if (lower.startsWith('en')) return 'EN';
    return localeId;
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!_active || _disposed) return;

    final text = result.recognizedWords.trim();
    if (text.isNotEmpty) {
      _hasRecognizedText = true;
      state = state.copyWith(transcript: text);

      // If user starts speaking while TTS is active, stop TTS immediately
      if (state.status == VoiceAgentCallStatus.speaking) {
        unawaited(_ttsService.stop());
      }
    }

    if (!result.finalResult) return;
    if (text.isEmpty) {
      _showListenError('Mimo chưa nghe rõ. Chạm mic để nói lại.');
      return;
    }

    unawaited(_handleUserTurn(text));
  }

  Future<void> _handleUserTurn(String text) async {
    if (!_active || _disposed) return;

    final userLocale = VoiceAgentText.inferLocale(text);
    _lastSpokenLocale = userLocale;

    if (VoiceAgentText.isExitCommand(text)) {
      await endCall(sayGoodbye: true);
      return;
    }

    state = state.copyWith(
      status: VoiceAgentCallStatus.thinking,
      lastUserText: text,
      transcript: text,
      clearError: true,
    );

    final response = await _chatNotifier.sendVoiceTurn(text);
    if (!_active || _disposed) return;

    if (response == null || response.trim().isEmpty) {
      state = state.copyWith(
        status: VoiceAgentCallStatus.error,
        errorMessage: 'Mimo chưa nhận được phản hồi. Bạn thử nói lại nhé.',
      );
      await _speak(
        userLocale == VoiceAgentLocale.english
            ? 'I could not get a response. Please try again.'
            : 'Mimo chưa nhận được phản hồi. Bạn thử nói lại nhé.',
        locale: userLocale,
      );
      await _ensureNextTurn();
      return;
    }

    final responseLocale = VoiceAgentText.inferLocale(response);
    _lastSpokenLocale = responseLocale;
    state = state.copyWith(
      status: VoiceAgentCallStatus.speaking,
      lastAssistantText: response,
    );

    // Start listening immediately while speaking (barge-in support)
    _startListeningWhileSpeaking();
    // Use lower volume to reduce echo during barge-in
    await _ttsService.speakWithBargeIn(response, locale: responseLocale);

    // TTS finished - cancel barge-in listening and reset flag
    if (!_active || _disposed) return;
    if (_hasRecognizedText) {
      // User already spoke during TTS, handled by _onResultWhileSpeaking
      return;
    }
    _startingListen = false;
    try {
      await _speech.cancel();
    } catch (_) {}
    // Small delay to let audio settle before listening again
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _ensureNextTurn();
  }

  void _startListeningWhileSpeaking() {
    if (!_active || _disposed || _startingListen) return;
    _startingListen = true;
    _hasRecognizedText = false;

    final localeId = _nextLocaleId();

    try {
      _speech.listen(
        onResult: _onResultWhileSpeaking,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e, st) {
      debugPrint('[VoiceAgent] barge-in listen exception: $e\n$st');
      _startingListen = false;
    }
  }

  void _onResultWhileSpeaking(SpeechRecognitionResult result) {
    if (!_active || _disposed) return;

    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    // User is speaking while TTS is active - stop TTS immediately
    _hasRecognizedText = true;
    state = state.copyWith(transcript: text);

    // Stop TTS but keep listening for final result
    unawaited(_ttsService.stop());

    if (!result.finalResult) return;

    // Now we have the final result, cancel listening and process
    _startingListen = false;
    unawaited(_speech.cancel());

    state = state.copyWith(
      status: VoiceAgentCallStatus.thinking,
    );
    unawaited(_handleUserTurn(text));
  }

  Future<void> _speak(String text, {required VoiceAgentLocale locale}) async {
    if (!_active || _disposed) return;
    state = state.copyWith(status: VoiceAgentCallStatus.speaking);
    try {
      await _ttsService.speak(text, locale: locale);
    } catch (e, st) {
      debugPrint('[VoiceAgent] TTS exception: $e\n$st');
    }
  }

  void _onSoundLevelChange(double level) {
    if (state.status != VoiceAgentCallStatus.listening) return;

    final normalizedLevel = (level / 10.0).clamp(0.0, 1.0).toDouble();
    final levels = [...state.audioLevels, normalizedLevel];
    if (levels.length > _maxLevels) {
      levels.removeRange(0, levels.length - _maxLevels);
    }
    state = state.copyWith(audioLevels: levels);
  }

  void _onStatus(String status) {
    if (!_active || _disposed) return;

    // Reset startingListen flag when speech recognition ends
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _startingListen = false;

      if (state.status == VoiceAgentCallStatus.listening &&
          !_hasRecognizedText) {
        _showListenError('Mimo chưa nghe rõ. Chạm mic để nói lại.');
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!_active || _disposed) return;

    if (_isRecoverableError(error.errorMsg)) {
      _showListenError(_recoverableSpeechMessage(error.errorMsg));
      return;
    }

    debugPrint('[VoiceAgent] error: ${error.errorMsg}');
    state = state.copyWith(
      status: VoiceAgentCallStatus.error,
      errorMessage: _speechErrorMessage(error.errorMsg),
    );
  }

  bool _isRecoverableError(String errorMsg) {
    return errorMsg == 'error_no_match' ||
        errorMsg == 'error_speech_timeout' ||
        errorMsg == 'error_language_not_supported' ||
        errorMsg == 'error_language_unavailable' ||
        errorMsg == 'error_busy';
  }

  String _recoverableSpeechMessage(String errorMsg) {
    return switch (errorMsg) {
      'error_busy' => 'Micro đang bận. Chạm mic để thử lại.',
      'error_language_not_supported' ||
      'error_language_unavailable' =>
        'Thiết bị chưa hỗ trợ ngôn ngữ này. Chạm mic để thử lại.',
      _ => 'Mimo chưa nghe rõ. Chạm mic để nói lại.',
    };
  }

  String _speechErrorMessage(String errorMsg) {
    return switch (errorMsg) {
      'error_permission' => 'Cần cấp quyền microphone để nói chuyện với Mimo.',
      'error_network' ||
      'error_network_timeout' ||
      'error_server' =>
        'Dịch vụ nhận dạng giọng nói đang lỗi mạng.',
      _ => 'Voice agent bị lỗi: $errorMsg',
    };
  }

  void _showListenError(String message) {
    if (!_active || _disposed || state.status == VoiceAgentCallStatus.error) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    state = state.copyWith(
      status: VoiceAgentCallStatus.error,
      errorMessage: message,
      audioLevels: const [],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _retryTimer?.cancel();
    unawaited(_speech.cancel());
    unawaited(_ttsService.stop());
    super.dispose();
  }
}

final voiceAgentControllerProvider =
    StateNotifierProvider.autoDispose<VoiceAgentController, VoiceAgentCallData>(
        (ref) {
  return VoiceAgentController(
    chatNotifier: ref.read(chatProvider.notifier),
    ttsService: ref.read(ttsServiceProvider),
  );
});
