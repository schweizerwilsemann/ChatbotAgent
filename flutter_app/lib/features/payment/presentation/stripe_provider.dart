import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/payment/data/stripe_api.dart';

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
  StripeNotifier(this._api) : super(const StripeState());

  final StripeApi _api;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final config = await _api.getConfig();
    final publishableKey = config['publishable_key'] as String?;
    if (publishableKey != null && publishableKey.isNotEmpty) {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      _initialized = true;
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
      await _ensureInitialized();

      final result = await _api.createPaymentIntent(
        orderId: orderId,
        amount: amount,
        description: description,
        orderType: orderType,
      );

      final clientSecret = result['client_secret'] as String?;
      if (clientSecret == null) {
        state = state.copyWith(
            isLoading: false, error: 'Không nhận được client_secret');
        return false;
      }

      await _initPaymentSheet(clientSecret);
      await Stripe.instance.presentPaymentSheet();

      state = state.copyWith(isLoading: false);
      return true;
    } on StripeException catch (e) {
      final code = e.error.code;
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
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data['detail']?.toString() ?? e.message,
      );
      return false;
    } catch (e) {
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
  return StripeNotifier(ref.watch(stripeApiProvider));
});
