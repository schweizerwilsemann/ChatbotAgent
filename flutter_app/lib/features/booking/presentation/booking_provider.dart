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
  final bool isCreating;
  final String? error;
  final String? successMessage;

  const BookingState({
    this.bookings = const [],
    this.availability,
    this.isLoading = false,
    this.isCreating = false,
    this.error,
    this.successMessage,
  });

  BookingState copyWith({
    List<Booking>? bookings,
    AvailabilityResponse? availability,
    bool? isLoading,
    bool? isCreating,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearAvailability = false,
  }) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      availability: clearAvailability
          ? null
          : (availability ?? this.availability),
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

/// Booking StateNotifier managing the booking state
class BookingNotifier extends StateNotifier<BookingState> {
  final BookingRepository _repository;

  BookingNotifier(this._repository) : super(const BookingState());

  /// Load user's bookings
  Future<void> loadBookings(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final bookings = await _repository.getBookingsByUser(userId);
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

  /// Check availability for a court type and date
  Future<void> checkAvailability({
    required CourtType courtType,
    required DateTime date,
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
        bookings: [...state.bookings, newBooking],
        successMessage: 'Đặt sân thành công!',
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
