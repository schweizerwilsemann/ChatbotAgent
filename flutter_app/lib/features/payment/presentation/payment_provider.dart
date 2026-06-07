import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/payment/data/payment_api.dart';
import 'package:sports_venue_chatbot/features/payment/data/payment_models.dart';
import 'package:sports_venue_chatbot/features/payment/domain/payment_repository.dart';
import 'package:sports_venue_chatbot/features/settings/presentation/app_settings_provider.dart';

class PaymentState {
  final bool isLoading;
  final String? paymentUrl;
  final String? error;

  const PaymentState({
    this.isLoading = false,
    this.paymentUrl,
    this.error,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? paymentUrl,
    String? error,
    bool clearError = false,
    bool clearPaymentUrl = false,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      paymentUrl: clearPaymentUrl ? null : (paymentUrl ?? this.paymentUrl),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentRepository _repository;
  final AppSettingsNotifier _settings;

  PaymentNotifier(this._repository, this._settings)
      : super(const PaymentState());

  Future<bool> createPayment({
    required String orderId,
    required int amount,
    required String description,
    String orderType = 'booking',
  }) async {
    state = state.copyWith(
        isLoading: true, clearError: true, clearPaymentUrl: true);
    try {
      final authenticated = await _settings.authenticateForOnlinePayment();
      if (!authenticated) {
        state = state.copyWith(
          isLoading: false,
          error: _settings.latestError ?? 'Cần xác thực để thanh toán online.',
        );
        return false;
      }

      final body = CreatePaymentBody(
        orderId: orderId,
        amount: amount,
        description: description,
        orderType: orderType,
      );
      final response = await _repository.createPayment(body);
      if (response.success && response.paymentUrl != null) {
        state = state.copyWith(
          isLoading: false,
          paymentUrl: response.paymentUrl,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Không thể tạo thanh toán.',
        );
        return false;
      }
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tạo thanh toán. Vui lòng thử lại.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearPaymentUrl() {
    state = state.copyWith(clearPaymentUrl: true);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(paymentApiProvider));
});

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(
    ref.watch(paymentRepositoryProvider),
    ref.watch(appSettingsProvider.notifier),
  );
});
