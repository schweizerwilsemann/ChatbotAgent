import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_chat_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_inbox_screen.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/staff_request/domain/staff_request_repository.dart';

final staffRequestManagementProvider = StateNotifierProvider<
    StaffRequestManagementNotifier, StaffRequestManagementState>((ref) {
  return StaffRequestManagementNotifier(
    ref.watch(staffRequestRepositoryProvider),
    ref,
  );
});

class StaffRequestManagementState {
  final List<StaffRequest> requests;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const StaffRequestManagementState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  List<StaffRequest> get pendingRequests => requests
      .where((request) => request.status == StaffRequestStatus.pending)
      .toList();

  List<StaffRequest> get acceptedRequests => requests
      .where((request) => request.status == StaffRequestStatus.accepted)
      .toList();

  StaffRequestManagementState copyWith({
    List<StaffRequest>? requests,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return StaffRequestManagementState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class StaffRequestManagementNotifier
    extends StateNotifier<StaffRequestManagementState> {
  final StaffRequestRepository _repository;
  final Ref _ref;

  StaffRequestManagementNotifier(this._repository, this._ref)
      : super(const StaffRequestManagementState());

  Future<void> loadRequests() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final requests = await _repository.getActiveRequests();
      state = state.copyWith(requests: requests, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách yêu cầu.',
      );
    }
  }

  Future<void> acceptRequest(String requestId) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      final updated = await _repository.acceptRequest(requestId);
      _replaceRequest(updated, successMessage: 'Đã tiếp nhận yêu cầu.');
      _ref.invalidate(staffInboxProvider);

      // Connect chat WebSocket immediately so call signaling works
      // even if staff is not on the chat screen yet
      _ref.read(staffChatProvider(requestId));
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (_) {
      state = state.copyWith(error: 'Không thể tiếp nhận yêu cầu.');
    }
  }

  Future<void> completeRequest(String requestId) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      final updated = await _repository.completeRequest(requestId);
      _removeRequest(updated.id, successMessage: 'Đã hoàn thành yêu cầu.');
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (_) {
      state = state.copyWith(error: 'Không thể hoàn thành yêu cầu.');
    }
  }

  Future<void> cancelRequest(String requestId) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      final updated = await _repository.cancelRequest(requestId);
      _removeRequest(updated.id, successMessage: 'Đã huỷ yêu cầu.');
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (_) {
      state = state.copyWith(error: 'Không thể huỷ yêu cầu.');
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void _replaceRequest(StaffRequest updated, {required String successMessage}) {
    final next = [
      for (final request in state.requests)
        if (request.id == updated.id) updated else request,
    ];
    if (!next.any((request) => request.id == updated.id)) {
      next.add(updated);
    }
    state = state.copyWith(requests: next, successMessage: successMessage);
  }

  void _removeRequest(String requestId, {required String successMessage}) {
    state = state.copyWith(
      requests:
          state.requests.where((request) => request.id != requestId).toList(),
      successMessage: successMessage,
    );
  }
}
