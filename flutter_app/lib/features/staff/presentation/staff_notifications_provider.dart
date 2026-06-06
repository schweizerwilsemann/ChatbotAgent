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
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final Map<String, String> resolvedStatuses;

  const StaffNotificationsState({
    this.notifications = const [],
    this.isConnected = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.resolvedStatuses = const {},
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Get the effective status for a staff request notification.
  /// Uses resolved status (from accept/complete actions) if available,
  /// otherwise falls back to the notification payload status.
  String getEffectiveStatus(StaffNotification notification) {
    final requestId = notification.payload['request_id']?.toString();
    if (requestId != null && resolvedStatuses.containsKey(requestId)) {
      return resolvedStatuses[requestId]!;
    }
    return notification.payload['status']?.toString() ?? 'pending';
  }

  StaffNotificationsState copyWith({
    List<StaffNotification>? notifications,
    bool? isConnected,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    Map<String, String>? resolvedStatuses,
    bool clearError = false,
  }) {
    return StaffNotificationsState(
      notifications: notifications ?? this.notifications,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      resolvedStatuses: resolvedStatuses ?? this.resolvedStatuses,
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
  static const int _pageSize = 30;
  static const String _resolvedStatusesKey = 'staff_resolved_statuses';

  StaffNotificationsNotifier({
    required DioClient dioClient,
    required FlutterSecureStorage storage,
    required LocalNotificationService localNotifications,
  })  : _dioClient = dioClient,
        _storage = storage,
        _localNotifications = localNotifications,
        super(const StaffNotificationsState()) {
    _loadResolvedStatuses();
  }

  Future<void> _loadResolvedStatuses() async {
    try {
      final raw = await _storage.read(key: _resolvedStatusesKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        final statuses = decoded.map(
          (k, v) => MapEntry(k, v.toString()),
        );
        state = state.copyWith(resolvedStatuses: statuses);
      }
    } catch (_) {}
  }

  Future<void> _saveResolvedStatuses() async {
    try {
      await _storage.write(
        key: _resolvedStatusesKey,
        value: jsonEncode(state.resolvedStatuses),
      );
    } catch (_) {}
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    await _connect();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      clearError: true,
    );
    try {
      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.realtimeNotificationsEndpoint,
        queryParameters: const {
          'limit': _pageSize,
          'offset': 0,
        },
      );
      final data = response.data ?? const [];
      final notifications = data
          .map((item) =>
              StaffNotification.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        hasMore: notifications.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải thông báo vận hành.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.realtimeNotificationsEndpoint,
        queryParameters: {
          'limit': _pageSize,
          'offset': state.notifications.length,
        },
      );
      final data = response.data ?? const [];
      final nextPage = data
          .map((item) =>
              StaffNotification.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        notifications: _mergeNotifications(state.notifications, nextPage),
        isLoadingMore: false,
        hasMore: nextPage.length == _pageSize,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Không thể tải thêm thông báo.',
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
      // Don't set isConnected until we actually receive data
      _subscription = _channel!.stream.listen(
        _handleSocketMessage,
        onError: (error) {
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
      // Set connected after a short delay to confirm the connection is stable
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_channel != null) {
          state = state.copyWith(isConnected: true, clearError: true);
        }
      });
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
      final updated =
          exists ? state.notifications : [notification, ...state.notifications];
      state = state.copyWith(notifications: updated);
      _localNotifications.showOperationNotification(
        title: notification.title,
        body: notification.message,
      );
    } catch (_) {
      return;
    }
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dioClient.patch<void>(
        '${ApiConstants.realtimeNotificationsEndpoint}/$notificationId/read',
      );
      final updated = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(readAt: DateTime.now());
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {
      // Silently fail — the notification is still shown
    }
  }

  /// Update a notification's payload (e.g. after accepting a request).
  void updateNotificationPayload(
      String notificationId, Map<String, dynamic> newPayload) {
    final updated = state.notifications.map((n) {
      if (n.id == notificationId) {
        return StaffNotification(
          id: n.id,
          eventType: n.eventType,
          title: n.title,
          message: n.message,
          source: n.source,
          payload: newPayload,
          createdAt: n.createdAt,
          readAt: n.readAt,
        );
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  /// Mark a request ID as having a resolved status (accepted/completed).
  /// This persists across rebuilds since it's stored in secure storage.
  void markRequestStatus(String requestId, String status) {
    final updated = Map<String, String>.from(state.resolvedStatuses)
      ..[requestId] = status;
    state = state.copyWith(resolvedStatuses: updated);
    _saveResolvedStatuses();
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    try {
      await _dioClient.patch<void>(
        ApiConstants.realtimeNotificationsReadAllEndpoint,
      );
      final now = DateTime.now();
      final updated = state.notifications.map((n) {
        if (!n.isRead) {
          return n.copyWith(readAt: now);
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {
      // Silently fail
    }
  }

  void _scheduleReconnect() {
    if (!_started) return;
    Future<void>.delayed(const Duration(seconds: 5), () {
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

List<StaffNotification> _mergeNotifications(
  List<StaffNotification> current,
  List<StaffNotification> nextPage,
) {
  final seen = current.map((notification) => notification.id).toSet();
  return [
    ...current,
    for (final notification in nextPage)
      if (seen.add(notification.id)) notification,
  ];
}
