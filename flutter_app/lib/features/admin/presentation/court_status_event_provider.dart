import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CourtStatusEvent {
  final String bookingId;
  final String resourceId;
  final String resourceLabel;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime receivedAt;

  CourtStatusEvent({
    required this.bookingId,
    required this.resourceId,
    required this.resourceLabel,
    required this.status,
    this.startTime,
    this.endTime,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory CourtStatusEvent.fromJson(Map<String, dynamic> json) {
    return CourtStatusEvent(
      bookingId: json['booking_id']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      resourceLabel: json['resource_label']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'].toString())
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'].toString())
          : null,
    );
  }
}

final courtStatusStreamProvider = StateNotifierProvider<
    CourtStatusStreamNotifier, AsyncValue<CourtStatusEvent?>>((ref) {
  return CourtStatusStreamNotifier(
    storage: ref.watch(secureStorageProvider),
  );
});

class CourtStatusStreamNotifier
    extends StateNotifier<AsyncValue<CourtStatusEvent?>> {
  final FlutterSecureStorage _storage;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _started = false;
  final _eventController = StreamController<CourtStatusEvent>.broadcast();

  CourtStatusStreamNotifier({required FlutterSecureStorage storage})
      : _storage = storage,
        super(const AsyncValue.data(null));

  Stream<CourtStatusEvent> get eventStream => _eventController.stream;

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

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      if (decoded['type'] == 'ui_event' &&
          decoded['event'] == 'court_status_changed') {
        final data = decoded['data'] as Map<String, dynamic>;
        final event = CourtStatusEvent.fromJson(data);
        state = AsyncValue.data(event);
        _eventController.add(event);
        debugPrint(
            '[CourtStatus] Received: ${event.status} for ${event.bookingId}');
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
