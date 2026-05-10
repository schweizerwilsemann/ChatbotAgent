import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/core/services/local_notification_service.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/staff/data/staff_notification.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

final staffNotificationsProvider =
    StateNotifierProvider<StaffNotificationsNotifier, StaffNotificationsState>(
        (ref) {
  return StaffNotificationsNotifier(
    dioClient: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
    localNotifications: ref.watch(localNotificationServiceProvider),
  );
});

class StaffNotificationsState {
  final List<StaffNotification> notifications;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  const StaffNotificationsState({
    this.notifications = const [],
    this.isConnected = false,
    this.isLoading = false,
    this.error,
  });

  StaffNotificationsState copyWith({
    List<StaffNotification>? notifications,
    bool? isConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return StaffNotificationsState(
      notifications: notifications ?? this.notifications,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StaffNotificationsNotifier
    extends StateNotifier<StaffNotificationsState> {
  final DioClient _dioClient;
  final FlutterSecureStorage _storage;
  final LocalNotificationService _localNotifications;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _started = false;

  StaffNotificationsNotifier({
    required DioClient dioClient,
    required FlutterSecureStorage storage,
    required LocalNotificationService localNotifications,
  })  : _dioClient = dioClient,
        _storage = storage,
        _localNotifications = localNotifications,
        super(const StaffNotificationsState());

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    await _connect();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.realtimeNotificationsEndpoint,
      );
      final data = response.data ?? const [];
      final notifications = data
          .map((item) =>
              StaffNotification.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải thông báo vận hành.',
      );
    }
  }

  Future<void> _connect() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    final uri = Uri.parse(ApiConstants.realtimeNotificationsWsEndpoint)
        .replace(queryParameters: {'token': token});
    try {
      _channel = WebSocketChannel.connect(uri);
      state = state.copyWith(isConnected: true, clearError: true);
      _subscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (_) {
          state = state.copyWith(
            isConnected: false,
            error: 'Mất kết nối realtime.',
          );
          _scheduleReconnect();
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
      );
    } catch (_) {
      state = state.copyWith(
        isConnected: false,
        error: 'Không thể kết nối realtime.',
      );
      _scheduleReconnect();
    }
  }

  void _handleSocketMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final notification = StaffNotification.fromJson(decoded);
      final exists =
          state.notifications.any((item) => item.id == notification.id);
      final updated = exists
          ? state.notifications
          : [notification, ...state.notifications].take(100).toList();
      state = state.copyWith(notifications: updated);
      _localNotifications.showOperationNotification(
        title: notification.title,
        body: notification.message,
      );
    } catch (_) {
      return;
    }
  }

  void _scheduleReconnect() {
    if (!_started) return;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_started && !state.isConnected) {
        _connect();
      }
    });
  }

  Future<void> stop() async {
    _started = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
