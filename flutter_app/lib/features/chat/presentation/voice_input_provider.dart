import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceInputState {
  idle,
  listening,
  processing,
  error,
}

class _ListenAttempt {
  final String? localeId;
  final ListenMode listenMode;
  final String label;

  const _ListenAttempt({
    required this.localeId,
    required this.listenMode,
    required this.label,
  });
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
  bool _initialized = false;
  bool _sessionActive = false;
  bool _hasRecognizedText = false;
  bool _attemptRetryScheduled = false;
  int _attemptIndex = 0;
  List<_ListenAttempt> _listenAttempts = const [];
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
        onError: _onError,
        onStatus: _onStatus,
        options: [SpeechToText.androidNoBluetooth],
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
    if (_sessionActive) {
      debugPrint(
          '[VoiceInput] startListening ignored; session already active.');
      return;
    }

    final available = await _ensureInitialized();
    if (!available) return;

    state = const VoiceInputData(
      state: VoiceInputState.listening,
      recognizedText: '',
      audioLevels: [],
    );

    final vietnameseLocaleId = await _resolveVietnameseLocale();
    _listenAttempts = _buildListenAttempts(vietnameseLocaleId);
    _attemptIndex = 0;
    _hasRecognizedText = false;
    _attemptRetryScheduled = false;
    _sessionActive = true;
    await _startCurrentAttempt();
  }

  List<_ListenAttempt> _buildListenAttempts(String vietnameseLocaleId) {
    return [
      _ListenAttempt(
        localeId: vietnameseLocaleId,
        listenMode: ListenMode.dictation,
        label: 'Vietnamese dictation',
      ),
      _ListenAttempt(
        localeId: vietnameseLocaleId,
        listenMode: ListenMode.search,
        label: 'Vietnamese search',
      ),
      const _ListenAttempt(
        localeId: null,
        listenMode: ListenMode.dictation,
        label: 'system default dictation',
      ),
      const _ListenAttempt(
        localeId: null,
        listenMode: ListenMode.search,
        label: 'system default search',
      ),
    ];
  }

  Future<void> _startCurrentAttempt() async {
    if (!_sessionActive) return;
    _attemptRetryScheduled = false;

    if (_attemptIndex >= _listenAttempts.length) {
      _sessionActive = false;
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage:
            'Không tạo được transcript. Kiểm tra Google Speech Services hoặc thử trên thiết bị Android thật.',
      );
      return;
    }

    final attempt = _listenAttempts[_attemptIndex];
    state = state.copyWith(state: VoiceInputState.listening);
    debugPrint(
      '[VoiceInput] Attempt ${_attemptIndex + 1}/${_listenAttempts.length}: ${attempt.label}',
    );
    debugPrint(
      '[VoiceInput] Using locale: ${attempt.localeId ?? 'system default'}',
    );

    try {
      debugPrint('[VoiceInput] Starting listen...');

      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          localeId: attempt.localeId,
          listenFor: const Duration(seconds: 45),
          partialResults: true,
          cancelOnError: true,
          listenMode: attempt.listenMode,
        ),
      );

      debugPrint('[VoiceInput] listen() called');
      debugPrint('[VoiceInput] isListening: ${_speech.isListening}');
    } catch (e, st) {
      debugPrint('[VoiceInput] listen() exception: $e\n$st');
      _sessionActive = false;
      state = state.copyWith(
        state: VoiceInputState.error,
        errorMessage: 'Lỗi bắt đầu nghe: $e',
      );
    }
  }

  Future<void> stopListening() async {
    _sessionActive = false;
    _attemptRetryScheduled = false;
    await _speech.stop();
    state = state.copyWith(state: VoiceInputState.idle);
  }

  Future<void> cancelListening() async {
    _sessionActive = false;
    _attemptRetryScheduled = false;
    await _speech.cancel();
    state = const VoiceInputData();
  }

  void _onResult(SpeechRecognitionResult result) {
    debugPrint('[VoiceInput] ====== onResult CALLED ======');
    debugPrint('[VoiceInput] recognizedWords: "${result.recognizedWords}"');
    debugPrint('[VoiceInput] finalResult: ${result.finalResult}');
    debugPrint('[VoiceInput] confidence: ${result.confidence}');

    final text = result.recognizedWords;
    if (text.trim().isNotEmpty) {
      _hasRecognizedText = true;
    }
    if (result.finalResult &&
        text.trim().isEmpty &&
        _sessionActive &&
        !_hasRecognizedText) {
      _scheduleNextAttempt('empty final result');
      return;
    }
    if (result.finalResult) {
      _sessionActive = false;
    }

    state = state.copyWith(
      recognizedText: text,
      state:
          result.finalResult ? VoiceInputState.idle : VoiceInputState.listening,
    );
  }

  Future<String> _resolveVietnameseLocale() async {
    try {
      final locales = await _speech.locales();
      return _findVietnameseLocale(locales);
    } catch (e, st) {
      debugPrint('[VoiceInput] locales() exception: $e\n$st');
      return 'vi_VN';
    }
  }

  void _onSoundLevelChange(double level) {
    if (state.state != VoiceInputState.listening) return;

    final normalizedLevel = (level / 10.0).clamp(0.0, 1.0).toDouble();
    final levels = [...state.audioLevels, normalizedLevel];
    if (levels.length > _maxLevels) {
      levels.removeRange(0, levels.length - _maxLevels);
    }

    state = state.copyWith(audioLevels: levels);
  }

  void _onStatus(String status) {
    debugPrint('[VoiceInput] onStatus: $status');

    if (status == SpeechToText.doneStatus &&
        _sessionActive &&
        !_hasRecognizedText &&
        !_attemptRetryScheduled) {
      _scheduleNextAttempt('done without result');
      return;
    }

    if (!_sessionActive &&
        (status == SpeechToText.notListeningStatus ||
            status == SpeechToText.doneStatus)) {
      if (state.state == VoiceInputState.listening) {
        state = state.copyWith(state: VoiceInputState.idle);
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint(
      '[VoiceInput] onError: ${error.errorMsg}, permanent: ${error.permanent}',
    );

    if (_sessionActive &&
        !_hasRecognizedText &&
        !_attemptRetryScheduled &&
        (error.errorMsg == 'error_language_not_supported' ||
            error.errorMsg == 'error_language_unavailable' ||
            error.errorMsg == 'error_no_match' ||
            error.errorMsg == 'error_speech_timeout')) {
      _scheduleNextAttempt(error.errorMsg);
      return;
    }

    _sessionActive = false;
    state = state.copyWith(
      state: VoiceInputState.error,
      errorMessage: _speechErrorMessage(error.errorMsg),
    );
  }

  String _speechErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_speech_timeout':
      case 'error_no_match':
        return 'Không nghe thấy giọng nói. Hãy thử nói lại gần micro hơn.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'Thiết bị chưa hỗ trợ nhận diện tiếng Việt. Kiểm tra Google Speech Services.';
      case 'error_permission':
        return 'Cần cấp quyền microphone trong Cài đặt.';
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
      case 'error_server_disconnected':
        return 'Dịch vụ nhận diện giọng nói đang lỗi mạng. Hãy kiểm tra kết nối và thử lại.';
      case 'error_busy':
        return 'Micro đang được dùng bởi tác vụ khác. Hãy thử lại sau.';
      default:
        return 'Lỗi nhận diện giọng nói: $errorMsg';
    }
  }

  void _scheduleNextAttempt(String reason) {
    if (_attemptRetryScheduled) return;

    _attemptRetryScheduled = true;
    _attemptIndex += 1;
    debugPrint('[VoiceInput] Retrying next attempt: $reason');
    Future.delayed(
      const Duration(milliseconds: 250),
      _startCurrentAttempt,
    );
  }

  void clearError() {
    state = state.copyWith(
      state: state.state == VoiceInputState.error
          ? VoiceInputState.idle
          : state.state,
      clearError: true,
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}

final voiceInputProvider =
    StateNotifierProvider<VoiceInputNotifier, VoiceInputData>((ref) {
  return VoiceInputNotifier();
});
