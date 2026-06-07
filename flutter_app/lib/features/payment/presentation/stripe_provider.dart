import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/payment/data/stripe_api.dart';
import 'package:sports_venue_chatbot/features/settings/presentation/app_settings_provider.dart';

class StripeState {
  final bool isLoading;
  final String? error;

  const StripeState({
    this.isLoading = false,
    this.error,
  });

  StripeState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return StripeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StripeNotifier extends StateNotifier<StripeState> {
  StripeNotifier(this._api, this._settings) : super(const StripeState());

  final StripeApi _api;
  final AppSettingsNotifier _settings;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final config = await _api.getConfig();
      final publishableKey = config['publishable_key'] as String?;
      debugPrint(
          '[Stripe] Config loaded: key=${publishableKey?.substring(0, 10)}...');
      if (publishableKey != null && publishableKey.isNotEmpty) {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();
        _initialized = true;
        debugPrint('[Stripe] Initialized successfully');
      } else {
        debugPrint('[Stripe] ERROR: publishable_key is empty or null');
      }
    } catch (e) {
      debugPrint('[Stripe] ERROR initializing: $e');
    }
  }

  Future<bool> pay({
    required String orderId,
    required int amount,
    required String description,
    String orderType = 'booking',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authenticated = await _settings.authenticateForOnlinePayment();
      if (!authenticated) {
        debugPrint('[Stripe] Auth failed: ${_settings.latestError}');
        state = state.copyWith(
          isLoading: false,
          error: _settings.latestError ?? 'Cần xác thực để thanh toán online.',
        );
        return false;
      }

      await _ensureInitialized();
      debugPrint(
          '[Stripe] Creating payment intent for order=$orderId, amount=$amount');

      final result = await _api.createPaymentIntent(
        orderId: orderId,
        amount: amount,
        description: description,
        orderType: orderType,
      );
      debugPrint('[Stripe] PaymentIntent created: ${result.keys}');

      final clientSecret = result['client_secret'] as String?;
      if (clientSecret == null) {
        debugPrint('[Stripe] ERROR: client_secret is null');
        state = state.copyWith(
            isLoading: false, error: 'Không nhận được client_secret');
        return false;
      }
      final paymentIntentId = result['payment_intent_id'] as String?;
      if (paymentIntentId == null) {
        debugPrint('[Stripe] ERROR: payment_intent_id is null');
        state = state.copyWith(
          isLoading: false,
          error: 'Không nhận được mã giao dịch Stripe.',
        );
        return false;
      }

      debugPrint('[Stripe] Initializing payment sheet...');
      await _initPaymentSheet(clientSecret);
      debugPrint('[Stripe] Presenting payment sheet...');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('[Stripe] Payment sheet completed, confirming...');
      await _api.confirmPaymentIntent(
        paymentIntentId: paymentIntentId,
        orderId: orderId,
        orderType: orderType,
      );

      debugPrint('[Stripe] Payment successful!');
      state = state.copyWith(isLoading: false);
      return true;
    } on StripeException catch (e) {
      final code = e.error.code;
      debugPrint(
          '[Stripe] StripeException: code=$code, message=${e.error.message}');
      if (code == FailureCode.Canceled) {
        state = state.copyWith(isLoading: false, error: null);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: e.error.message ?? 'Thanh toán thất bại',
      );
      return false;
    } on DioException catch (e) {
      debugPrint('[Stripe] DioException: ${e.response?.data}');
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['detail']?.toString() ?? e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[Stripe] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> _initPaymentSheet(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Sports Venue Chatbot',
        style: ThemeMode.light,
      ),
    );
  }

  void clear() {
    state = const StripeState();
  }
}

final stripeApiProvider = Provider<StripeApi>((ref) {
  return StripeApi(ref.watch(dioClientProvider));
});

final stripeProvider =
    StateNotifierProvider<StripeNotifier, StripeState>((ref) {
  return StripeNotifier(
    ref.watch(stripeApiProvider),
    ref.watch(appSettingsProvider.notifier),
  );
});
