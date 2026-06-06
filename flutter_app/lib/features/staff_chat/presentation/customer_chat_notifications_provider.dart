import 'dart:async';
import 'dart:convert';

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
    if (_started) return;
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
    if (!_started || token == null || token.isEmpty) return;

    final uri = Uri.parse(ApiConstants.realtimeNotificationsWsEndpoint)
        .replace(queryParameters: {'token': token});
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (_) {
          if (!mounted) return;
          state = state.copyWith(
            isConnected: false,
            error: 'Mất kết nối thông báo tin nhắn.',
          );
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _started && _channel != null) {
          state = state.copyWith(isConnected: true, clearError: true);
        }
      });
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isConnected: false,
        error: 'Không thể kết nối thông báo tin nhắn.',
      );
      _scheduleReconnect();
    }
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      if (decoded['event_type']?.toString() != 'staff_chat_message') {
        return;
      }

      final payload = decoded['payload'];
      if (payload is Map<String, dynamic> &&
          payload['sender_role']?.toString() != 'staff') {
        return;
      }

      _localNotifications.showOperationNotification(
        title: decoded['title']?.toString() ?? 'Tin nhắn mới',
        body: decoded['message']?.toString() ?? '',
      );
    } catch (_) {
      return;
    }
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
