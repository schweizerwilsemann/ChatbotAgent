import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/services/local_notification_service.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_chat_provider.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/staff_request/domain/staff_request_repository.dart';

// ── Customer-side provider ─────────────────────────────────────────────

final staffRequestProvider =
    StateNotifierProvider<StaffRequestNotifier, StaffRequestState>((ref) {
  return StaffRequestNotifier(
    ref.watch(staffRequestRepositoryProvider),
    ref,
  );
});

class StaffRequestState {
  final StaffRequest? activeRequest;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const StaffRequestState({
    this.activeRequest,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  bool get hasActiveRequest =>
      activeRequest != null &&
      (activeRequest!.status == StaffRequestStatus.pending ||
          activeRequest!.status == StaffRequestStatus.accepted);

  StaffRequestState copyWith({
    StaffRequest? activeRequest,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearActiveRequest = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return StaffRequestState(
      activeRequest:
          clearActiveRequest ? null : (activeRequest ?? this.activeRequest),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class StaffRequestNotifier extends StateNotifier<StaffRequestState> {
  final StaffRequestRepository _repository;
  final Ref _ref;
  Timer? _pollTimer;
  String? _connectedRequestId;

  final StreamController<StaffRequest> _acceptedController =
      StreamController<StaffRequest>.broadcast();

  /// Emits when a staff request is accepted (detected via polling).
  /// UI listens to auto-navigate to chat room.
  Stream<StaffRequest> get acceptedStream => _acceptedController.stream;

  StaffRequestNotifier(this._repository, this._ref)
      : super(const StaffRequestState()) {
    _loadActiveRequest();
  }

  static const _pollInterval = Duration(seconds: 5);

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStatus());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollStatus() async {
    if (!state.hasActiveRequest) {
      _stopPolling();
      return;
    }
    try {
      final requests = await _repository.getMyRequests();
      final activeId = state.activeRequest!.id;
      final match = requests.where((r) => r.id == activeId).firstOrNull;
      if (match != null && match.status != state.activeRequest!.status) {
        final oldStatus = state.activeRequest!.status;
        state = state.copyWith(activeRequest: match);

        // When staff accepts the request → notify customer + emit event
        if (oldStatus == StaffRequestStatus.pending &&
            match.status == StaffRequestStatus.accepted) {
          final staffName = match.acceptedByName ?? 'Nhân viên';
          LocalNotificationService().showOperationNotification(
            title: 'Yêu cầu đã được tiếp nhận',
            body: '$staffName đã tiếp nhận yêu cầu. Mở chat ngay!',
          );
          _acceptedController.add(match);

          // Connect chat WebSocket immediately so we can receive messages
          // even when customer is not on the chat screen
          _connectChatForNotifications(match.id);
        }

        if (!state.hasActiveRequest) {
          _stopPolling();
        }
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  Future<void> createRequest({
    required StaffRequestType requestType,
    String? description,
    int? tableNumber,
    String? venueId,
    String? resourceId,
    String? resourceLabel,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final request = await _repository.createRequest(
        requestType: requestType,
        description: description,
        tableNumber: tableNumber,
        venueId: venueId,
        resourceId: resourceId,
        resourceLabel: resourceLabel,
      );
      state = state.copyWith(
        activeRequest: request,
        isLoading: false,
        successMessage:
            'Đã gửi yêu cầu đến nhân viên. Vui lòng chờ trong giây lát.',
      );
      _startPolling();
    } on Exception catch (e) {
      // 409 conflict: there's already an active request — load it
      if (e.toString().contains('409')) {
        await _loadActiveRequest();
        state = state.copyWith(
          isLoading: false,
          error: 'Bạn đang có yêu cầu chưa hoàn thành.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> cancelRequest() async {
    if (state.activeRequest == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final updated = await _repository.cancelRequest(state.activeRequest!.id);
      state = state.copyWith(
        activeRequest: updated,
        isLoading: false,
        successMessage: 'Đã hủy yêu cầu.',
      );
      _stopPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is Exception ? e.toString() : 'Không thể hủy yêu cầu.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  Future<void> _loadActiveRequest() async {
    try {
      final requests = await _repository.getMyRequests();
      final active = requests
          .where((r) =>
              r.status == StaffRequestStatus.pending ||
              r.status == StaffRequestStatus.accepted)
          .firstOrNull;
      if (active != null) {
        state = state.copyWith(activeRequest: active);
        _startPolling();

        // If already accepted, connect chat WebSocket immediately
        if (active.status == StaffRequestStatus.accepted) {
          _connectChatForNotifications(active.id);
        }
      }
    } catch (_) {
      // Silently fail
    }
  }

  /// Connect the chat WebSocket for a request so we can receive messages
  /// and show notifications even when the customer is outside the chat screen.
  void _connectChatForNotifications(String requestId) {
    if (_connectedRequestId == requestId) return;
    _connectedRequestId = requestId;

    final chatNotifier = _ref.read(staffChatProvider(requestId).notifier);
    chatNotifier.onNewMessageFromOther = (msg) {
      // Only notify for staff messages (customer is the recipient)
      if (msg.senderRole == 'staff') {
        debugPrint(
            '[StaffRequest] New message from staff: ${msg.content}, showing notification');
        LocalNotificationService().showOperationNotification(
          title: msg.senderName.isNotEmpty ? msg.senderName : 'Nhân viên',
          body: msg.content,
        );
      }
    };
  }

  void resetActiveRequest() {
    _stopPolling();
    _connectedRequestId = null;
    state = state.copyWith(clearActiveRequest: true);
  }

  @override
  void dispose() {
    _stopPolling();
    _acceptedController.close();
    super.dispose();
  }
}
