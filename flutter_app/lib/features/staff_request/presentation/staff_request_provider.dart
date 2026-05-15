import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/staff_request/domain/staff_request_repository.dart';

// ── Customer-side provider ─────────────────────────────────────────────

final staffRequestProvider =
    StateNotifierProvider<StaffRequestNotifier, StaffRequestState>((ref) {
  return StaffRequestNotifier(
    ref.watch(staffRequestRepositoryProvider),
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
  Timer? _pollTimer;

  StaffRequestNotifier(this._repository) : super(const StaffRequestState());

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
        state = state.copyWith(activeRequest: match);
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
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final request = await _repository.createRequest(
        requestType: requestType,
        description: description,
        tableNumber: tableNumber,
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
      }
    } catch (_) {
      // Silently fail
    }
  }

  void resetActiveRequest() {
    _stopPolling();
    state = state.copyWith(clearActiveRequest: true);
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
