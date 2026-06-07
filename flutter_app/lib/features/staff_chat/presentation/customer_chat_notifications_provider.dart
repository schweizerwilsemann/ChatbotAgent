import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/services/local_notification_service.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final customerChatNotificationsProvider = StateNotifierProvider<
    CustomerChatNotificationsNotifier, CustomerChatNotificationsState>((ref) {
  return CustomerChatNotificationsNotifier(
    storage: ref.watch(secureStorageProvider),
    localNotifications: LocalNotificationService(),
  );
});

class CustomerChatNotificationsState {
  final bool isConnected;
  final String? error;

  const CustomerChatNotificationsState({
    this.isConnected = false,
    this.error,
  });

  CustomerChatNotificationsState copyWith({
    bool? isConnected,
    String? error,
    bool clearError = false,
  }) {
    return CustomerChatNotificationsState(
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CustomerChatNotificationsNotifier
    extends StateNotifier<CustomerChatNotificationsState> {
  final FlutterSecureStorage _storage;
  final LocalNotificationService _localNotifications;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _started = false;

  CustomerChatNotificationsNotifier({
    required FlutterSecureStorage storage,
    required LocalNotificationService localNotifications,
  })  : _storage = storage,
        _localNotifications = localNotifications,
        super(const CustomerChatNotificationsState());

  void start() {
    if (_started) {
      debugPrint('[CustomerNoti] Already started, skipping');
      return;
    }
    debugPrint('[CustomerNoti] Starting...');
    _started = true;
    _connect();
  }

  void stop() {
    if (!_started && _channel == null && !state.isConnected) return;
    _started = false;
    _disconnect();
    if (mounted) {
      state = state.copyWith(isConnected: false);
    }
  }

  Future<void> _connect() async {
    final token = await _storage.read(key: 'auth_token');
    if (!_started || token == null || token.isEmpty) {
      debugPrint('[CustomerNoti] No auth token or not started, cannot connect');
      return;
    }

    final uri = Uri.parse(ApiConstants.realtimeNotificationsWsEndpoint)
        .replace(queryParameters: {'token': token});
    debugPrint('[CustomerNoti] Connecting to WS: $uri');
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (_) {
          if (!mounted) return;
          debugPrint('[CustomerNoti] WS error');
          state = state.copyWith(
            isConnected: false,
            error: 'Mất kết nối thông báo tin nhắn.',
          );
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          debugPrint('[CustomerNoti] WS closed');
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _started && _channel != null) {
          debugPrint('[CustomerNoti] WS connected');
          state = state.copyWith(isConnected: true, clearError: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[CustomerNoti] WS connect error: $e');
      state = state.copyWith(
        isConnected: false,
        error: 'Không thể kết nối thông báo tin nhắn.',
      );
      _scheduleReconnect();
    }
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      debugPrint(
          '[CustomerNoti] Received WS message: ${raw.toString().substring(0, raw.toString().length.clamp(0, 200))}');
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;

      // Handle ui_event (court_status_changed, payment_status_changed, etc.)
      if (decoded['type']?.toString() == 'ui_event') {
        final eventType = decoded['event']?.toString() ?? '';
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        debugPrint('[CustomerNoti] UI event: $eventType');

        if (eventType == 'court_status_changed') {
          _handleCourtStatusChanged(data);
        }
        return;
      }

      if (decoded['event_type']?.toString() != 'staff_chat_message') {
        debugPrint(
            '[CustomerNoti] Ignoring non-chat event: ${decoded['event_type']}');
        return;
      }

      final payload = decoded['payload'];
      if (payload is Map<String, dynamic> &&
          payload['sender_role']?.toString() != 'staff') {
        debugPrint('[CustomerNoti] Ignoring non-staff message');
        return;
      }

      debugPrint(
          '[CustomerNoti] Showing native notification: ${decoded['title']}');
      _localNotifications.showOperationNotification(
        title: decoded['title']?.toString() ?? 'Tin nhắn mới',
        body: decoded['message']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('[CustomerNoti] Error handling WS message: $e');
      return;
    }
  }

  void _handleCourtStatusChanged(Map<String, dynamic> data) {
    final bookingId = data['booking_id']?.toString();
    final status = data['status']?.toString();
    if (bookingId == null || status == null) return;

    debugPrint(
        '[CustomerNoti] Court status changed: booking=$bookingId, status=$status');

    _localNotifications.showOperationNotification(
      title: 'Cập nhật đặt sân',
      body: status == 'checked_in'
          ? 'Bạn đã nhận sân thành công!'
          : 'Trạng thái sân đã thay đổi',
    );
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _started && !state.isConnected) {
        _connect();
      }
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
