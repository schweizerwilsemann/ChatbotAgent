import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeUiEvent {
  final String
      type; // court_status_changed, order_changed, payment_status_changed
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  RealtimeUiEvent({
    required this.type,
    required this.data,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  String? get orderId => data['order_id']?.toString();
  String? get bookingId => data['booking_id']?.toString();
  String? get action => data['action']?.toString();
}

final realtimeEventProvider =
    StateNotifierProvider<RealtimeEventNotifier, AsyncValue<RealtimeUiEvent?>>(
        (ref) {
  return RealtimeEventNotifier(
    storage: ref.watch(secureStorageProvider),
  );
});

class RealtimeEventNotifier
    extends StateNotifier<AsyncValue<RealtimeUiEvent?>> {
  final FlutterSecureStorage _storage;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _started = false;
  final _eventController = StreamController<RealtimeUiEvent>.broadcast();

  RealtimeEventNotifier({required FlutterSecureStorage storage})
      : _storage = storage,
        super(const AsyncValue.data(null));

  Stream<RealtimeUiEvent> get eventStream => _eventController.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _connect();
  }

  Future<void> _connect() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    final uri = Uri.parse(ApiConstants.realtimeNotificationsWsEndpoint)
        .replace(queryParameters: {'token': token});
    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static const _uiEventTypes = {
    'court_status_changed',
    'order_changed',
    'payment_status_changed',
  };

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      if (decoded['type'] == 'ui_event') {
        final eventType = decoded['event']?.toString() ?? '';
        if (_uiEventTypes.contains(eventType)) {
          final data = (decoded['data'] as Map<String, dynamic>?) ?? {};
          final event = RealtimeUiEvent(type: eventType, data: data);
          state = AsyncValue.data(event);
          _eventController.add(event);
          debugPrint('[Realtime] UI event: $eventType');
        }
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (!_started) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_started) _connect();
    });
  }

  Future<void> stop() async {
    _started = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  @override
  void dispose() {
    stop();
    _eventController.close();
    super.dispose();
  }
}
