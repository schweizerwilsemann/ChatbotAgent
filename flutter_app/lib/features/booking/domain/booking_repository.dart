import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_api.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';

/// Abstract booking repository interface
abstract class IBookingRepository {
  Future<Booking> createBooking(BookingCreate booking);
  Future<Booking> getBookingById(String bookingId);
  Future<List<Booking>> getBookingsByUser(
    String userId, {
    int limit,
    int offset,
  });
  Future<Booking> cancelBooking(String bookingId);
  Future<AvailabilityResponse> checkAvailability({
    required CourtType courtType,
    required DateTime date,
    String? venueId,
  });
  Future<Booking> updateBooking(String bookingId, BookingUpdate update);
}

/// Concrete implementation of the booking repository
class BookingRepository implements IBookingRepository {
  final BookingApi _bookingApi;

  BookingRepository(this._bookingApi);

  @override
  Future<Booking> createBooking(BookingCreate booking) async {
    try {
      // Validate booking data
      if (booking.startTime.compareTo(booking.endTime) >= 0) {
        throw ValidationException(
          message: 'Giờ bắt đầu phải trước giờ kết thúc',
        );
      }
      return await _bookingApi.createBooking(booking);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tạo đặt sân. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Booking> getBookingById(String bookingId) async {
    try {
      return await _bookingApi.getBookingById(bookingId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải thông tin đặt sân.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<List<Booking>> getBookingsByUser(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      return await _bookingApi.getBookingsByUser(
        userId,
        limit: limit,
        offset: offset,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải danh sách đặt sân.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Booking> cancelBooking(String bookingId) async {
    try {
      return await _bookingApi.cancelBooking(bookingId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể hủy đặt sân. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<AvailabilityResponse> checkAvailability({
    required CourtType courtType,
    required DateTime date,
    String? venueId,
  }) async {
    try {
      return await _bookingApi.checkAvailability(
        courtType: courtType,
        date: date,
        venueId: venueId,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể kiểm tra tình trạng sân.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Booking> updateBooking(String bookingId, BookingUpdate update) async {
    try {
      return await _bookingApi.updateBooking(bookingId, update);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể cập nhật đặt sân.',
        statusCode: 500,
      );
    }
  }
}
