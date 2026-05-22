import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceInputState {
  idle,
  listening,
  processing,
  error,
}

class VoiceInputData {
  final VoiceInputState state;
  final String recognizedText;
  final String? errorMessage;
  final List<double> audioLevels;

  const VoiceInputData({
    this.state = VoiceInputState.idle,
    this.recognizedText = '',
    this.errorMessage,
    this.audioLevels = const [],
  });

  VoiceInputData copyWith({
    VoiceInputState? state,
    String? recognizedText,
    String? errorMessage,
    List<double>? audioLevels,
    bool clearError = false,
  }) {
    return VoiceInputData(
      state: state ?? this.state,
      recognizedText: recognizedText ?? this.recognizedText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      audioLevels: audioLevels ?? this.audioLevels,
    );
  }
}

class VoiceInputNotifier extends StateNotifier<VoiceInputData> {
  final SpeechToText _speech = SpeechToText();
  Timer? _levelTimer;
  bool _initialized = false;
  static const int _maxLevels = 30;

  VoiceInputNotifier() : super(const VoiceInputData());

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;

    final micStatus = await Permission.microphone.status;
    debugPrint('[VoiceInput] Mic permission status: $micStatus');
    if (micStatus.isDenied) {
      final result = await Permission.microphone.request();
      debugPrint('[VoiceInput] Mic permission request result: $result');
      if (result.isDenied || result.isPermanentlyDenied) {
        state = state.copyWith(
          state: VoiceInputState.error,
          errorMessage: 'Cần cấp quyền microphone trong Cài đặt.',
        );
        return false;
      }
    } else if (micStatus.isPermanentlyDenied) {
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage:
            'Quyền microphone bị từ chối. Vào Cài đặt > Ứng dụng > Sports Venue Chatbot > Quyền để cấp lại.',
      );
      return false;
    }

    try {
      debugPrint('[VoiceInput] Initializing speech_to_text...');
      _initialized = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceInput] onError: ${error.errorMsg}');
          state = state.copyWith(
            state: VoiceInputState.error,
            errorMessage: 'Lỗi nhận diện: ${error.errorMsg}',
          );
          _stopLevelTimer();
        },
        onStatus: (status) {
          debugPrint('[VoiceInput] onStatus: $status');
        },
      );
      debugPrint('[VoiceInput] Initialized: $_initialized');

      if (!_initialized) {
        state = state.copyWith(
          state: VoiceInputState.error,
          errorMessage:
              'Nhận dạng giọng nói không khả dụng. Kiểm tra Google Speech Services.',
        );
        return false;
      }

      return true;
    } catch (e, st) {
      debugPrint('[VoiceInput] Init exception: $e\n$st');
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage: 'Không thể khởi tạo nhận diện giọng nói: $e',
      );
      return false;
    }
  }

  String _findVietnameseLocale(List<LocaleName> locales) {
    debugPrint(
        '[VoiceInput] Available locales: ${locales.map((l) => l.localeId).toList()}');

    for (final pattern in ['vi_VN', 'vi-VN', 'vie_VN', 'vi']) {
      final match = locales.firstWhere(
        (l) => l.localeId == pattern,
        orElse: () => LocaleName('', ''),
      );
      if (match.localeId.isNotEmpty) {
        debugPrint('[VoiceInput] Found Vietnamese locale: ${match.localeId}');
        return match.localeId;
      }
    }

    for (final l in locales) {
      if (l.localeId.toLowerCase().startsWith('vi')) {
        debugPrint('[VoiceInput] Found locale (partial): ${l.localeId}');
        return l.localeId;
      }
    }

    if (locales.isNotEmpty) {
      final fallback = locales.first.localeId;
      debugPrint(
          '[VoiceInput] No Vietnamese locale. Falling back to: $fallback');
      return fallback;
    }

    debugPrint('[VoiceInput] No locales available, using vi_VN');
    return 'vi_VN';
  }

  Future<void> startListening() async {
    final available = await _ensureInitialized();
    if (!available) return;

    state = const VoiceInputData(
      state: VoiceInputState.listening,
      recognizedText: '',
      audioLevels: [],
    );

    final locales = await _speech.locales();
    final localeId = _findVietnameseLocale(locales);
    debugPrint('[VoiceInput] Using locale: $localeId');

    try {
      debugPrint('[VoiceInput] Starting listen...');

      // Use the simplest possible listen call
      _speech.listen(
        onResult: _onResult,
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );

      debugPrint('[VoiceInput] listen() called');
      debugPrint('[VoiceInput] isListening: ${_speech.isListening}');
    } catch (e, st) {
      debugPrint('[VoiceInput] listen() exception: $e\n$st');
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage: 'Lỗi bắt đầu nghe: $e',
      );
    }

    _startLevelTimer();
  }

  Future<void> stopListening() async {
    _stopLevelTimer();
    await _speech.stop();
    state = state.copyWith(state: VoiceInputState.idle);
  }

  Future<void> cancelListening() async {
    _stopLevelTimer();
    await _speech.cancel();
    state = const VoiceInputData();
  }

  void _onResult(SpeechRecognitionResult result) {
    debugPrint('[VoiceInput] ====== onResult CALLED ======');
    debugPrint('[VoiceInput] recognizedWords: "${result.recognizedWords}"');
    debugPrint('[VoiceInput] finalResult: ${result.finalResult}');
    debugPrint('[VoiceInput] confidence: ${result.confidence}');

    final text = result.recognizedWords;
    state = state.copyWith(
      recognizedText: text,
      state:
          result.finalResult ? VoiceInputState.idle : VoiceInputState.listening,
    );
  }

  void _startLevelTimer() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_speech.isListening) return;
      final level = _speech.lastStatus == 'listening'
          ? max(0.0, min(1.0, _speech.lastSoundLevel / 10.0))
          : 0.0;
      final levels = [...state.audioLevels, level];
      if (levels.length > _maxLevels) {
        levels.removeRange(0, levels.length - _maxLevels);
      }
      state = state.copyWith(audioLevels: levels);
    });
  }

  void _stopLevelTimer() {
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _stopLevelTimer();
    _speech.cancel();
    super.dispose();
  }
}

final voiceInputProvider =
    StateNotifierProvider<VoiceInputNotifier, VoiceInputData>((ref) {
  return VoiceInputNotifier();
});
