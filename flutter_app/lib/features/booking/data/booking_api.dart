import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';

final bookingApiProvider = Provider<BookingApi>((ref) {
  return BookingApi(ref.watch(dioClientProvider));
});

class BookingApi {
  final DioClient _dioClient;

  BookingApi(this._dioClient);

  /// Create a new booking
  Future<Booking> createBooking(BookingCreate booking) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.bookingEndpoint,
        data: booking.toJson(),
      );
      return Booking.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get a booking by ID
  Future<Booking> getBookingById(String bookingId) async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '${ApiConstants.bookingEndpoint}/$bookingId',
      );
      return Booking.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all bookings for a user
  Future<List<Booking>> getBookingsByUser(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.bookingEndpoint,
        queryParameters: {'user_id': userId, 'limit': limit, 'offset': offset},
      );
      if (response.data == null) return [];
      return response.data!
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get the current user's active booking (now between start and end)
  Future<Booking?> getActiveBooking() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '${ApiConstants.bookingEndpoint}/active',
      );
      if (response.data == null) return null;
      return Booking.fromJson(response.data!);
    } catch (e) {
      return null;
    }
  }

  Future<List<BookingBill>> getBookingBills({
    int limit = 10,
    int offset = 0,
  }) async {
    final response = await _dioClient.get<List<dynamic>>(
      '${ApiConstants.bookingEndpoint}/bills',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    if (response.data == null) return [];
    return response.data!
        .map((json) => BookingBill.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<BookingBill> getBookingBill(String bookingId) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      '${ApiConstants.bookingEndpoint}/$bookingId/bill',
    );
    return BookingBill.fromJson(response.data!);
  }

  Future<Booking> confirmCheckIn({
    required String bookingId,
    required String token,
  }) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      '${ApiConstants.bookingEndpoint}/$bookingId/confirm-checkin',
      data: {'token': token},
    );
    return Booking.fromJson(response.data!);
  }

  /// Cancel a booking
  Future<Booking> cancelBooking(String bookingId) async {
    try {
      final response = await _dioClient.patch<Map<String, dynamic>>(
        '${ApiConstants.bookingEndpoint}/$bookingId/cancel',
      );
      return Booking.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Check availability for a court type on a specific date
  Future<AvailabilityResponse> checkAvailability({
    required CourtType courtType,
    required DateTime date,
    String? venueId,
  }) async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        ApiConstants.bookingAvailabilityEndpoint,
        queryParameters: {
          'court_type': courtType.name,
          if (venueId != null) 'venue_id': venueId,
          'date': date.toIso8601String().split('T')[0],
        },
      );
      return AvailabilityResponse.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Update a booking
  Future<Booking> updateBooking(String bookingId, BookingUpdate update) async {
    try {
      final response = await _dioClient.put<Map<String, dynamic>>(
        '${ApiConstants.bookingEndpoint}/$bookingId',
        data: update.toJson(),
      );
      return Booking.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }
}
