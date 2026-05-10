import 'package:flutter/services.dart';

class LocalNotificationService {
  static const MethodChannel _channel =
      MethodChannel('sports_venue_chatbot/notifications');

  Future<void> showOperationNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod<void>('showOperationNotification', {
        'title': title,
        'body': body,
      });
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }
}
