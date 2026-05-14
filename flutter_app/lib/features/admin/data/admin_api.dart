import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(dioClientProvider));
});

class AdminApi {
  final DioClient _dioClient;

  AdminApi(this._dioClient);

  // ─── Dashboard ──────────────────────────────────────────────────────────

  /// Fetch dashboard summary stats.
  Future<DashboardStats> getDashboardStats() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        ApiConstants.adminDashboardEndpoint,
      );
      return DashboardStats.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Bookings ───────────────────────────────────────────────────────────

  /// Fetch bookings with optional filters.
  Future<List<AdminBooking>> getBookings({
    String? date,
    String? courtType,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) queryParams['date'] = date;
      if (courtType != null) queryParams['court_type'] = courtType;
      if (status != null) queryParams['status'] = status;

      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.adminBookingsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data == null) return [];
      return response.data!
          .map((json) => AdminBooking.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update a booking's status.
  Future<AdminBooking> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    try {
      final response = await _dioClient.patch<Map<String, dynamic>>(
        '${ApiConstants.adminBookingsEndpoint}/$bookingId/status',
        data: {'status': status},
      );
      return AdminBooking.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Orders ─────────────────────────────────────────────────────────────

  /// Fetch orders with optional status filter.
  Future<List<AdminOrder>> getOrders({String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;

      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.adminOrdersEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data == null) return [];
      return response.data!
          .map((json) => AdminOrder.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update an order's status (uses existing `/api/order/{id}/status`).
  Future<AdminOrder> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _dioClient.put<Map<String, dynamic>>(
        '${ApiConstants.orderEndpoint}/$orderId/status',
        data: {'status': status},
      );
      return AdminOrder.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Menu ───────────────────────────────────────────────────────────────

  /// Fetch menu items with optional category filter.
  Future<List<AdminMenuItem>> getMenuItems({String? categoryKey}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryKey != null) queryParams['category_key'] = categoryKey;

      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.adminMenuEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data == null) return [];
      return response.data!
          .map((json) => AdminMenuItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new menu item.
  Future<AdminMenuItem> createMenuItem(MenuItemCreate data) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.adminMenuEndpoint,
        data: data.toJson(),
      );
      return AdminMenuItem.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing menu item.
  Future<AdminMenuItem> updateMenuItem(String id, MenuItemUpdate data) async {
    try {
      final response = await _dioClient.put<Map<String, dynamic>>(
        '${ApiConstants.adminMenuEndpoint}/$id',
        data: data.toJson(),
      );
      return AdminMenuItem.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a menu item.
  Future<void> deleteMenuItem(String id) async {
    try {
      await _dioClient.delete<void>(
        '${ApiConstants.adminMenuEndpoint}/$id',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle a menu item's availability.
  Future<AdminMenuItem> toggleMenuItemAvailability(
    String id,
    bool isAvailable,
  ) async {
    try {
      final response = await _dioClient.patch<Map<String, dynamic>>(
        '${ApiConstants.adminMenuEndpoint}/$id/availability',
        data: {'is_available': isAvailable},
      );
      return AdminMenuItem.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Analytics ──────────────────────────────────────────────────────────

  /// Fetch analytics data for a given period (e.g. "day", "week", "month").
  Future<AnalyticsData> getAnalytics({String? period}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (period != null) queryParams['period'] = period;

      final response = await _dioClient.get<Map<String, dynamic>>(
        ApiConstants.adminAnalyticsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      return AnalyticsData.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }
}
