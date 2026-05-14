import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class MenuManagementState {
  final List<AdminMenuItem> items;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const MenuManagementState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  MenuManagementState copyWith({
    List<AdminMenuItem>? items,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return MenuManagementState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class MenuManagementNotifier extends StateNotifier<MenuManagementState> {
  final AdminApi _adminApi;

  MenuManagementNotifier(this._adminApi) : super(const MenuManagementState());

  /// Load all menu items from the API.
  Future<void> loadItems({String? categoryKey}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _adminApi.getMenuItems(categoryKey: categoryKey);
      state = state.copyWith(items: items, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách thực đơn.',
      );
    }
  }

  /// Create a new menu item.
  Future<bool> createItem(MenuItemCreate data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newItem = await _adminApi.createMenuItem(data);
      state = state.copyWith(
        items: [...state.items, newItem],
        isLoading: false,
        successMessage: 'Đã thêm "${newItem.name}" thành công.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể thêm món. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Update an existing menu item.
  Future<bool> updateItem(String id, MenuItemUpdate data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _adminApi.updateMenuItem(id, data);
      final updatedItems = state.items.map((item) {
        return item.id == id ? updated : item;
      }).toList();
      state = state.copyWith(
        items: updatedItems,
        isLoading: false,
        successMessage: 'Đã cập nhật "${updated.name}" thành công.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể cập nhật món. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Delete a menu item.
  Future<bool> deleteItem(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _adminApi.deleteMenuItem(id);
      final updatedItems = state.items.where((item) => item.id != id).toList();
      state = state.copyWith(
        items: updatedItems,
        isLoading: false,
        successMessage: 'Đã xoá món thành công.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể xoá món. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Toggle a menu item's availability.
  Future<bool> toggleAvailability(String id, bool isAvailable) async {
    state = state.copyWith(clearError: true);
    try {
      final updated =
          await _adminApi.toggleMenuItemAvailability(id, isAvailable);
      final updatedItems = state.items.map((item) {
        return item.id == id ? updated : item;
      }).toList();
      state = state.copyWith(
        items: updatedItems,
        successMessage: isAvailable
            ? 'Đã bật bán "${updated.name}".'
            : 'Đã tắt bán "${updated.name}".',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        error: 'Không thể thay đổi trạng thái món.',
      );
      return false;
    }
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message.
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final menuManagementProvider =
    StateNotifierProvider<MenuManagementNotifier, MenuManagementState>((ref) {
  return MenuManagementNotifier(ref.watch(adminApiProvider));
});
