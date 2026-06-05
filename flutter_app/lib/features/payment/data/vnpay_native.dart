import 'package:flutter/services.dart';

class VNPayNative {
  static const _channel = MethodChannel('sports_venue_chatbot/vnpay');

  static Future<String> openSdk({
    required String paymentUrl,
    required String tmnCode,
    bool isSandbox = true,
  }) async {
    final result = await _channel.invokeMethod<String>('openVnpaySdk', {
      'paymentUrl': paymentUrl,
      'tmnCode': tmnCode,
      'is_sandbox': isSandbox,
    });
    return result ?? 'unknown';
  }
}
