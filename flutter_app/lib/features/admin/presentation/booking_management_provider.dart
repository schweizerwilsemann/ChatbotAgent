import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class BookingManagementState {
  final List<AdminBooking> bookings;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;
  final String? filterType;
  final String? filterStatus;

  const BookingManagementState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
    this.filterType,
    this.filterStatus,
  });

  BookingManagementState copyWith({
    List<AdminBooking>? bookings,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
    String? filterType,
    String? filterStatus,
    bool clearError = false,
    bool clearFilterType = false,
    bool clearFilterStatus = false,
  }) {
    return BookingManagementState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
      filterStatus:
          clearFilterStatus ? null : (filterStatus ?? this.filterStatus),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class BookingManagementNotifier extends StateNotifier<BookingManagementState> {
  final AdminApi _adminApi;

  BookingManagementNotifier(this._adminApi)
      : super(BookingManagementState(selectedDate: DateTime.now()));

  /// Load bookings from the API using current filters.
  Future<void> loadBookings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dateStr = '${state.selectedDate.year.toString().padLeft(4, '0')}-'
          '${state.selectedDate.month.toString().padLeft(2, '0')}-'
          '${state.selectedDate.day.toString().padLeft(2, '0')}';

      final bookings = await _adminApi.getBookings(
        date: dateStr,
        courtType: state.filterType,
        status: state.filterStatus,
      );
      state = state.copyWith(bookings: bookings, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách đặt sân.',
      );
    }
  }

  /// Update a booking's status and refresh the list.
  Future<bool> updateBookingStatus(String id, String newStatus) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _adminApi.updateBookingStatus(id, newStatus);
      final updatedBookings = state.bookings.map((b) {
        return b.id == id ? updated : b;
      }).toList();
      state = state.copyWith(bookings: updatedBookings, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể cập nhật trạng thái đặt sân.',
      );
      return false;
    }
  }

  /// Set the selected date filter and reload.
  Future<void> setDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await loadBookings();
  }

  /// Set the court type filter and reload.
  Future<void> setFilterType(String? type) async {
    if (type == null) {
      state = state.copyWith(clearFilterType: true);
    } else {
      state = state.copyWith(filterType: type);
    }
    await loadBookings();
  }

  /// Set the status filter and reload.
  Future<void> setFilterStatus(String? status) async {
    if (status == null) {
      state = state.copyWith(clearFilterStatus: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
    await loadBookings();
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final bookingManagementProvider =
    StateNotifierProvider<BookingManagementNotifier, BookingManagementState>(
        (ref) {
  return BookingManagementNotifier(ref.watch(adminApiProvider));
});
