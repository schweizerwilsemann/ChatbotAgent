import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_api.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class PartnerOrderState {
  final List<PartnerOrder> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? statusFilter;
  final String? error;
  final String? successMessage;

  const PartnerOrderState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.statusFilter,
    this.error,
    this.successMessage,
  });

  PartnerOrderState copyWith({
    List<PartnerOrder>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? statusFilter,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearStatusFilter = false,
  }) {
    return PartnerOrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class PartnerOrderNotifier extends StateNotifier<PartnerOrderState> {
  static const int _pageSize = 20;

  final PartnerApi _partnerApi;

  PartnerOrderNotifier(this._partnerApi) : super(const PartnerOrderState());

  Future<void> loadOrders({
    String? status,
    bool clearStatus = false,
    bool reset = true,
  }) async {
    if (!reset) {
      if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        hasMore: true,
        statusFilter: status,
        clearStatusFilter: clearStatus,
        clearError: true,
      );
    }

    try {
      final orders = await _partnerApi.getOrders(
        status: state.statusFilter,
        limit: _pageSize,
        offset: reset ? 0 : state.orders.length,
      );
      state = state.copyWith(
        orders: reset ? orders : [...state.orders, ...orders],
        isLoading: false,
        isLoadingMore: false,
        hasMore: orders.length == _pageSize,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Không thể tải danh sách đơn hàng.',
      );
    }
  }

  Future<void> loadMore() => loadOrders(reset: false);

  Future<bool> updateOrderStatus(
    String orderId,
    PartnerOrderStatus newStatus,
  ) async {
    state = state.copyWith(clearError: true);
    try {
      final updated = await _partnerApi.updateOrderStatus(
        orderId,
        newStatus.apiValue,
      );
      final updatedOrders = state.orders.map((o) {
        return o.id == orderId ? updated : o;
      }).toList();
      state = state.copyWith(
        orders: updatedOrders,
        successMessage: 'Đã cập nhật trạng thái đơn hàng.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Không thể cập nhật trạng thái. Vui lòng thử lại.',
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
  void clearSuccess() => state = state.copyWith(clearSuccess: true);
}

// ─── Provider ───────────────────────────────────────────────────────────────

final partnerOrderProvider =
    StateNotifierProvider<PartnerOrderNotifier, PartnerOrderState>((ref) {
  return PartnerOrderNotifier(ref.watch(partnerApiProvider));
});
