import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalNotificationService {
  static const MethodChannel _channel =
      MethodChannel('sports_venue_chatbot/notifications');

  Future<void> showOperationNotification({
    required String title,
    required String body,
  }) async {
    try {
      debugPrint('[LocalNoti] Calling showOperationNotification: $title');
      await _channel.invokeMethod<void>('showOperationNotification', {
        'title': title,
        'body': body,
      });
      debugPrint('[LocalNoti] showOperationNotification success');
    } on MissingPluginException {
      debugPrint(
          '[LocalNoti] MissingPluginException - native handler not registered');
      return;
    } catch (e) {
      debugPrint('[LocalNoti] Error: $e');
      return;
    }
  }
}
