import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/payment/data/stripe_api.dart';

class StripeState {
  final String? checkoutUrl;
  final String? sessionId;
  final bool isLoading;
  final String? error;

  const StripeState({
    this.checkoutUrl,
    this.sessionId,
    this.isLoading = false,
    this.error,
  });

  StripeState copyWith({
    String? checkoutUrl,
    String? sessionId,
    bool? isLoading,
    String? error,
  }) {
    return StripeState(
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      sessionId: sessionId ?? this.sessionId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StripeNotifier extends StateNotifier<StripeState> {
  StripeNotifier(this._api) : super(const StripeState());

  final StripeApi _api;

  Future<bool> createCheckout({
    required String orderId,
    required int amount,
    required String description,
    String orderType = 'booking',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.createCheckout(
        orderId: orderId,
        amount: amount,
        description: description,
        orderType: orderType,
      );
      state = state.copyWith(
        isLoading: false,
        checkoutUrl: result['checkout_url'] as String?,
        sessionId: result['session_id'] as String?,
      );
      return result['checkout_url'] != null;
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
