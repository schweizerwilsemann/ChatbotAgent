import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    try {
      _initialized = await _speech.initialize(
        onError: (error) {
          state = state.copyWith(
            state: VoiceInputState.error,
            errorMessage: error.errorMsg,
          );
          _stopLevelTimer();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _stopLevelTimer();
            if (state.state == VoiceInputState.listening) {
              state = state.copyWith(state: VoiceInputState.idle);
            }
          }
        },
      );
      return _initialized;
    } catch (e) {
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage: 'Không thể khởi tạo nhận diện giọng nói.',
      );
      return false;
    }
  }

  Future<void> startListening() async {
    final available = await _ensureInitialized();
    if (!available) return;

    state = const VoiceInputData(
      state: VoiceInputState.listening,
      recognizedText: '',
      audioLevels: [],
    );

    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      ),
    );

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
