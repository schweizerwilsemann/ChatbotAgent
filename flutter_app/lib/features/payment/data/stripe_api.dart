import 'package:sports_venue_chatbot/core/network/dio_client.dart';

class StripeApi {
  StripeApi(this._dioClient);

  final DioClient _dioClient;

  Future<Map<String, dynamic>> createPaymentIntent({
    required String orderId,
    required int amount,
    required String description,
    String orderType = 'booking',
  }) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      '/api/stripe/create-payment-intent',
      data: {
        'order_id': orderId,
        'amount': amount,
        'description': description,
        'order_type': orderType,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfig() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      '/api/stripe/config',
    );
    return response.data as Map<String, dynamic>;
  }
}
