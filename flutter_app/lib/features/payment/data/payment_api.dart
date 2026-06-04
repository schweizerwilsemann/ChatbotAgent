import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/payment/data/payment_models.dart';

final paymentApiProvider = Provider<PaymentApi>((ref) {
  return PaymentApi(ref.watch(dioClientProvider));
});

class PaymentApi {
  final DioClient _dioClient;

  PaymentApi(this._dioClient);

  Future<CreatePaymentResponse> createPayment(CreatePaymentBody body) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.paymentCreateEndpoint,
        data: body.toJson(),
      );
      return CreatePaymentResponse.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }
}
