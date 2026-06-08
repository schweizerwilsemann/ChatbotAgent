import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_models.dart';
import 'package:sports_venue_chatbot/features/staff_chat/domain/staff_chat_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final staffChatProvider =
    StateNotifierProvider.family<StaffChatNotifier, StaffChatState, String>(
        (ref, requestId) {
  final notifier = StaffChatNotifier(
    repository: ref.watch(staffChatRepositoryProvider),
    storage: ref.watch(secureStorageProvider),
    requestId: requestId,
  );
  // Set current user role for optimistic messages
  final authState = ref.read(authStateProvider);
  notifier.currentUserRole = authState.valueOrNull?.role.toLowerCase() ?? '';
  debugPrint(
      '[StaffChat] Provider created for requestId=$requestId, currentUserRole=${notifier.currentUserRole}');

  // Wire call signaling globally (persists even after screen disposal)
  final callNotifier = ref.read(callProvider.notifier);
  final callState = ref.read(callProvider);
  notifier.onCallSignaling = (data) {
    callNotifier.handleSignalingMessage(data);
  };
  // Only attach outgoing signaling if no call is active
  // (to prevent overriding during an active call in another room)
  if (!callState.isActive) {
    callNotifier.attachSignaling((msg) {
      notifier.sendSignalingMessage(msg);
    });
  }

  return notifier;
});

class StaffChatState {
  final List<StaffChatMessage> messages;
  final bool isConnected;
  final bool isOtherTyping;
  final bool isOtherOnline;
  final bool isRoomClosed;
  final String? error;

  const StaffChatState({
    this.messages = const [],
    this.isConnected = false,
    this.isOtherTyping = false,
    this.isOtherOnline = false,
    this.isRoomClosed = false,
    this.error,
  });

  StaffChatState copyWith({
    List<StaffChatMessage>? messages,
    bool? isConnected,
    bool? isOtherTyping,
    bool? isOtherOnline,
    bool? isRoomClosed,
    String? error,
    bool clearError = false,
  }) {
    return StaffChatState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isOtherTyping: isOtherTyping ?? this.isOtherTyping,
      isOtherOnline: isOtherOnline ?? this.isOtherOnline,
      isRoomClosed: isRoomClosed ?? this.isRoomClosed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StaffChatNotifier extends StateNotifier<StaffChatState> {
  final StaffChatRepository _repository;
  final FlutterSecureStorage _storage;
  final String _requestId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _typingTimer;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  static const _uuid = Uuid();

  /// The role of the current user ('staff' or 'customer').
  /// Set by the provider so optimistic messages have the correct senderRole.
  String currentUserRole = '';

  /// Callback for call signaling messages. Set by CallNotifier.
  void Function(Map<String, dynamic>)? onCallSignaling;

  /// Callback when a new message arrives from the other party.
  /// Used for showing notifications when user is outside the chat screen.
  void Function(StaffChatMessage message)? onNewMessageFromOther;

  StaffChatNotifier({
    required StaffChatRepository repository,
    required FlutterSecureStorage storage,
    required String requestId,
  })  : _repository = repository,
        _storage = storage,
        _requestId = requestId,
        super(const StaffChatState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadHistory();
    await _connect();
  }

  Future<void> _loadHistory() async {
    try {
      final messages = await _repository.getHistory(_requestId);
      state = state.copyWith(messages: messages);
    } catch (_) {
      // Silent fail — will retry on reconnect
    }
  }

  Future<void> _connect() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    final uri = Uri.parse(ApiConstants.staffChatWsEndpoint(_requestId))
        .replace(queryParameters: {'token': token});

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) {
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (_channel != null) {
          state = state.copyWith(isConnected: true, clearError: true);
          _startHeartbeat();
        }
      });
    } catch (_) {
      state = state.copyWith(
        isConnected: false,
        error: 'Không thể kết nối chat.',
      );
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'message':
          final msg = StaffChatMessage.fromJson(data);
          debugPrint(
              '[StaffChat] Received message: id=${msg.id}, senderRole=${msg.senderRole}, content=${msg.content}');
          // Dedup by ID first, then by content for optimistic messages
          // (optimistic messages have empty senderRole and client-generated ID)
          final isDuplicate = state.messages.any((m) => m.id == msg.id) ||
              state.messages.any((m) =>
                  m.content == msg.content &&
                  (m.senderRole == msg.senderRole || m.senderRole.isEmpty) &&
                  msg.timestamp.difference(m.timestamp).inSeconds.abs() < 5);
          if (!isDuplicate) {
            state = state.copyWith(messages: [...state.messages, msg]);
            // Notify listeners about new message from other party
            onNewMessageFromOther?.call(msg);
          } else {
            debugPrint('[StaffChat] Duplicate message, skipping');
          }
          break;

        case 'typing':
          state = state.copyWith(isOtherTyping: true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) state = state.copyWith(isOtherTyping: false);
          });
          break;

        case 'participant_joined':
          state = state.copyWith(isOtherOnline: true);
          break;

        case 'participant_left':
          state = state.copyWith(isOtherOnline: false, isOtherTyping: false);
          break;

        case 'room_closed':
          state = state.copyWith(isRoomClosed: true);
          _disconnect();
          break;

        case 'call_offer':
        case 'call_answer':
        case 'call_ice_candidate':
        case 'call_end':
        case 'call_reject':
        case 'call_busy':
          onCallSignaling?.call(data);
          break;
      }
    } catch (_) {
      // Ignore malformed messages
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || state.isRoomClosed) return;

    final msg = StaffChatMessage(
      id: _uuid.v4(),
      roomId: _requestId,
      senderId: '',
      senderName: '',
      senderRole: currentUserRole,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    debugPrint(
        '[StaffChat] Sending message: id=${msg.id}, content=${msg.content}, currentUserRole=$currentUserRole, senderRole=${msg.senderRole}');

    // Optimistic append
    state = state.copyWith(messages: [...state.messages, msg]);

    try {
      _channel?.sink.add(jsonEncode({
        'type': 'message',
        'content': content.trim(),
      }));
    } catch (_) {
      state = state.copyWith(error: 'Không thể gửi tin nhắn.');
    }
  }

  void sendTyping() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'typing'}));
    } catch (_) {
      // Ignore
    }
  }

  void sendSignalingMessage(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {
      // Ignore
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        // Will reconnect on next cycle
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !state.isConnected && !state.isRoomClosed) {
        _connect();
      }
    });
  }

  void _disconnect() {
    _heartbeatTimer?.cancel();
    _typingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
