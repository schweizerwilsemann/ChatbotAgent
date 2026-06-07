import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  system,
  vietnamese,
  english;

  static const supportedLanguages = [AppLanguage.vietnamese];

  String get storageValue {
    switch (this) {
      case AppLanguage.system:
        return 'system';
      case AppLanguage.vietnamese:
        return 'vi_VN';
      case AppLanguage.english:
        return 'en_US';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.system:
        return 'Theo hệ thống';
      case AppLanguage.vietnamese:
        return 'Tiếng Việt';
      case AppLanguage.english:
        return 'English';
    }
  }

  String get description {
    switch (this) {
      case AppLanguage.system:
        return 'Dùng ngôn ngữ mặc định của thiết bị';
      case AppLanguage.vietnamese:
        return 'Ngôn ngữ nội dung hiện đang được hỗ trợ';
      case AppLanguage.english:
        return 'Chưa có bộ chuỗi giao diện tiếng Anh';
    }
  }

  Locale? get locale {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.vietnamese:
        return const Locale('vi', 'VN');
      case AppLanguage.english:
        return const Locale('en', 'US');
    }
  }

  String? get intlLocaleName {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.vietnamese:
        return 'vi_VN';
      case AppLanguage.english:
        return 'en_US';
    }
  }

  static AppLanguage fromStorage(String? value) {
    final language = AppLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => AppLanguage.vietnamese,
    );
    return supportedLanguages.contains(language)
        ? language
        : AppLanguage.vietnamese;
  }
}

class AppSettingsState {
  final bool isLoading;
  final bool requireAuthForOnlinePayment;
  final bool deviceAuthSupported;
  final List<BiometricType> biometrics;
  final AppLanguage language;
  final String? error;

  const AppSettingsState({
    this.isLoading = true,
    this.requireAuthForOnlinePayment = false,
    this.deviceAuthSupported = false,
    this.biometrics = const [],
    this.language = AppLanguage.vietnamese,
    this.error,
  });

  AppSettingsState copyWith({
    bool? isLoading,
    bool? requireAuthForOnlinePayment,
    bool? deviceAuthSupported,
    List<BiometricType>? biometrics,
    AppLanguage? language,
    String? error,
    bool clearError = false,
  }) {
    return AppSettingsState(
      isLoading: isLoading ?? this.isLoading,
      requireAuthForOnlinePayment:
          requireAuthForOnlinePayment ?? this.requireAuthForOnlinePayment,
      deviceAuthSupported: deviceAuthSupported ?? this.deviceAuthSupported,
      biometrics: biometrics ?? this.biometrics,
      language: language ?? this.language,
      error: clearError ? null : (error ?? this.error),
    );
  }

  String get authCapabilityLabel {
    if (!deviceAuthSupported) {
      return 'Thiết bị chưa hỗ trợ khóa màn hình hoặc sinh trắc học';
    }
    if (biometrics.isEmpty) {
      return 'Dùng passcode, PIN hoặc khóa màn hình của thiết bị';
    }
    final labels = biometrics.map((type) {
      switch (type) {
        case BiometricType.face:
          return 'Face ID';
        case BiometricType.fingerprint:
          return 'vân tay';
        case BiometricType.iris:
          return 'mống mắt';
        case BiometricType.strong:
          return 'sinh trắc học mạnh';
        case BiometricType.weak:
          return 'sinh trắc học';
      }
    }).join(', ');
    return 'Hỗ trợ $labels hoặc khóa màn hình';
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    load();
  }

  static const _requirePaymentAuthKey = 'require_auth_for_online_payment';
  static const _languageKey = 'app_language';

  final LocalAuthentication _localAuth = LocalAuthentication();

  String? get latestError => state.error;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final supported = await _safeIsDeviceSupported();
      final biometrics = await _safeGetBiometrics();
      state = state.copyWith(
        isLoading: false,
        requireAuthForOnlinePayment:
            prefs.getBool(_requirePaymentAuthKey) ?? false,
        deviceAuthSupported: supported,
        biometrics: biometrics,
        language: AppLanguage.fromStorage(prefs.getString(_languageKey)),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải cài đặt.',
      );
    }
  }

  Future<void> setRequireAuthForOnlinePayment(bool value) async {
    if (value && !state.deviceAuthSupported) {
      state = state.copyWith(
        error:
            'Thiết bị cần có khóa màn hình, PIN, passcode hoặc sinh trắc học.',
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requirePaymentAuthKey, value);
    state = state.copyWith(
      requireAuthForOnlinePayment: value,
      clearError: true,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.storageValue);
    state = state.copyWith(language: language, clearError: true);
  }

  Future<bool> authenticateForOnlinePayment() async {
    if (state.isLoading) {
      await load();
    }
    if (!state.requireAuthForOnlinePayment) return true;
    if (!state.deviceAuthSupported) {
      state = state.copyWith(
        error:
            'Thiết bị cần có khóa màn hình, PIN, passcode hoặc sinh trắc học.',
      );
      return false;
    }
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Xác thực để tiếp tục thanh toán online',
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) {
        state = state.copyWith(error: 'Bạn đã huỷ xác thực thanh toán.');
      }
      return authenticated;
    } on LocalAuthException catch (e) {
      state = state.copyWith(error: _mapLocalAuthError(e.code));
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Không thể xác thực thiết bị.');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> _safeIsDeviceSupported() async {
    try {
      return _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> _safeGetBiometrics() async {
    try {
      return _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  String _mapLocalAuthError(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Thiết bị chưa cài khóa màn hình, PIN hoặc passcode.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Thiết bị không có phần cứng sinh trắc học.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'Thiết bị chưa đăng ký Face ID, vân tay hoặc sinh trắc học.';
      case LocalAuthExceptionCode.biometricLockout:
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Sinh trắc học đang bị khóa tạm thời. Hãy dùng passcode hoặc thử lại sau.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Bạn đã huỷ xác thực thanh toán.';
      case LocalAuthExceptionCode.authInProgress:
        return 'Đang có một phiên xác thực khác.';
      case LocalAuthExceptionCode.uiUnavailable:
        return 'Không thể mở màn hình xác thực ở thời điểm này.';
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.unknownError:
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Không thể xác thực thiết bị. Vui lòng thử lại.';
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});
