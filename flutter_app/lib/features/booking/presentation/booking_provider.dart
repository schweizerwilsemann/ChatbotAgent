import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_api.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';
import 'package:sports_venue_chatbot/features/booking/domain/booking_repository.dart';

/// State class for booking management
class BookingState {
  final List<Booking> bookings;
  final AvailabilityResponse? availability;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isCreating;
  final String? error;
  final String? successMessage;
  final Booking? lastCreatedBooking;

  const BookingState({
    this.bookings = const [],
    this.availability,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.isCreating = false,
    this.error,
    this.successMessage,
    this.lastCreatedBooking,
  });

  BookingState copyWith({
    List<Booking>? bookings,
    AvailabilityResponse? availability,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isCreating,
    String? error,
    String? successMessage,
    Booking? lastCreatedBooking,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearAvailability = false,
    bool clearLastCreated = false,
  }) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      availability:
          clearAvailability ? null : (availability ?? this.availability),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      lastCreatedBooking: clearLastCreated
          ? null
          : (lastCreatedBooking ?? this.lastCreatedBooking),
    );
  }
}

/// Booking StateNotifier managing the booking state
class BookingNotifier extends StateNotifier<BookingState> {
  static const int _pageSize = 10;

  final BookingRepository _repository;

  BookingNotifier(this._repository) : super(const BookingState());

  /// Load user's bookings
  Future<void> loadBookings(String userId, {bool reset = true}) async {
    if (!reset) {
      if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        hasMore: true,
        clearError: true,
      );
    }

    try {
      final bookings = await _repository.getBookingsByUser(
        userId,
        limit: _pageSize,
        offset: reset ? 0 : state.bookings.length,
      );
      state = state.copyWith(
        bookings: reset ? bookings : [...state.bookings, ...bookings],
        isLoading: false,
        isLoadingMore: false,
        hasMore: bookings.length == _pageSize,
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
        error: 'Không thể tải danh sách đặt sân.',
      );
    }
  }

  Future<void> loadMoreBookings(String userId) {
    return loadBookings(userId, reset: false);
  }

  /// Check availability for a court type and date
  Future<void> checkAvailability({
    required CourtType courtType,
    required DateTime date,
    String? venueId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearAvailability: true,
    );
    try {
      final availability = await _repository.checkAvailability(
        courtType: courtType,
        date: date,
        venueId: venueId,
      );
      state = state.copyWith(availability: availability, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể kiểm tra tình trạng sân.',
      );
    }
  }

  /// Create a new booking
  Future<bool> createBooking(BookingCreate booking) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final newBooking = await _repository.createBooking(booking);
      state = state.copyWith(
        isCreating: false,
        bookings: [newBooking, ...state.bookings],
        successMessage: 'Đặt sân thành công!',
        lastCreatedBooking: newBooking,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isCreating: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Không thể tạo đặt sân. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updatedBooking = await _repository.cancelBooking(bookingId);
      final updatedBookings = state.bookings.map((b) {
        return b.id == bookingId ? updatedBooking : b;
      }).toList();
      state = state.copyWith(
        bookings: updatedBookings,
        isLoading: false,
        successMessage: 'Đã hủy đặt sân thành công.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Không thể hủy đặt sân.');
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}

/// Provider for the BookingRepository
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(bookingApiProvider));
});

/// Provider for the BookingNotifier
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((
  ref,
) {
  return BookingNotifier(ref.watch(bookingRepositoryProvider));
});
