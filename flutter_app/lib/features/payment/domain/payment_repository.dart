import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/payment/data/payment_api.dart';
import 'package:sports_venue_chatbot/features/payment/data/payment_models.dart';

abstract class IPaymentRepository {
  Future<CreatePaymentResponse> createPayment(CreatePaymentBody body);
}

class PaymentRepository implements IPaymentRepository {
  final PaymentApi _paymentApi;

  PaymentRepository(this._paymentApi);

  @override
  Future<CreatePaymentResponse> createPayment(CreatePaymentBody body) async {
    try {
      return await _paymentApi.createPayment(body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tạo thanh toán. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }
}
