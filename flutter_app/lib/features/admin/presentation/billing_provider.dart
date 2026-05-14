import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class BillingState {
  final List<AdminOrder> orders;
  final bool isLoading;
  final String? error;
  final String? filterStatus;

  const BillingState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus,
  });

  BillingState copyWith({
    List<AdminOrder>? orders,
    bool? isLoading,
    String? error,
    String? filterStatus,
    bool clearError = false,
    bool clearFilterStatus = false,
  }) {
    return BillingState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      filterStatus:
          clearFilterStatus ? null : (filterStatus ?? this.filterStatus),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class BillingNotifier extends StateNotifier<BillingState> {
  final AdminApi _adminApi;

  BillingNotifier(this._adminApi) : super(const BillingState());

  /// Load orders from the API using the current status filter.
  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _adminApi.getOrders(
        status: state.filterStatus,
      );
      state = state.copyWith(orders: orders, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách đơn hàng.',
      );
    }
  }

  /// Update an order's status and refresh the list.
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _adminApi.updateOrderStatus(orderId, newStatus);
      final updatedOrders = state.orders.map((o) {
        return o.id == orderId ? updated : o;
      }).toList();
      state = state.copyWith(orders: updatedOrders, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể cập nhật trạng thái đơn hàng.',
      );
      return false;
    }
  }

  /// Set the status filter and reload.
  Future<void> setFilterStatus(String? status) async {
    if (status == null) {
      state = state.copyWith(clearFilterStatus: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
    await loadOrders();
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final billingProvider =
    StateNotifierProvider<BillingNotifier, BillingState>((ref) {
  return BillingNotifier(ref.watch(adminApiProvider));
});
