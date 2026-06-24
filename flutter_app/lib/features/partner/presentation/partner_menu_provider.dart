import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_api.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class PartnerMenuState {
  final List<PartnerMenuItem> items;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const PartnerMenuState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  PartnerMenuState copyWith({
    List<PartnerMenuItem>? items,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PartnerMenuState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class PartnerMenuNotifier extends StateNotifier<PartnerMenuState> {
  final PartnerApi _partnerApi;

  PartnerMenuNotifier(this._partnerApi) : super(const PartnerMenuState());

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _partnerApi.getMenuItems(includeUnavailable: true);
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

  Future<bool> createItem(PartnerMenuItemCreateData data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newItem = await _partnerApi.createMenuItem(data);
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

  Future<bool> updateItem(String id, PartnerMenuItemUpdateData data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _partnerApi.updateMenuItem(id, data);
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

  Future<bool> deleteItem(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _partnerApi.deleteMenuItem(id);
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

  Future<bool> toggleAvailability(String id, bool isAvailable) async {
    state = state.copyWith(clearError: true);
    try {
      final updated = await _partnerApi.updateMenuItem(
        id,
        PartnerMenuItemUpdateData(isAvailable: isAvailable),
      );
      final updatedItems = state.items.map((item) {
        return item.id == id ? updated : item;
      }).toList();
      state = state.copyWith(
        items: updatedItems,
        successMessage: isAvailable
            ? 'Đã bật bán "${updated.name}".'
            : 'Đã ẩn "${updated.name}".',
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

  void clearError() => state = state.copyWith(clearError: true);
  void clearSuccess() => state = state.copyWith(clearSuccess: true);
}

// ─── Provider ───────────────────────────────────────────────────────────────

final partnerMenuProvider =
    StateNotifierProvider<PartnerMenuNotifier, PartnerMenuState>((ref) {
  return PartnerMenuNotifier(ref.watch(partnerApiProvider));
});
