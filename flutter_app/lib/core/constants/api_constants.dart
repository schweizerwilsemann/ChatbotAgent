import 'package:sports_venue_chatbot/core/config/flavor_config.dart';

class ApiConstants {
  ApiConstants._();

  /// Base URL resolved from the active FlavorConfig.
  static String get baseUrl => FlavorConfig.apiBaseUrl;

  // API Endpoints
  static const String chatEndpoint = '/api/chat';
  static const String chatStreamEndpoint = '/api/chat/stream';
  static const String bookingEndpoint = '/api/booking';
  static const String bookingAvailabilityEndpoint = '/api/booking/availability';
  static const String orderEndpoint = '/api/order';
  static const String menuEndpoint = '/api/menu';
  static const String venuesEndpoint = '/api/venues';
  static const String venueResourcesEndpoint = '/api/venues/resources';
  static const String staffNotifyEndpoint = '/api/staff/notify';
  static const String staffRequestEndpoint = '/api/staff/requests';
  static const String staffChatEndpoint = '/api/staff/chat';

  static String staffChatWsEndpoint(String requestId) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri
        .replace(
          scheme: scheme,
          path: '/api/staff/chat/$requestId/ws',
          query: '',
        )
        .toString();
  }

  static const String realtimeNotificationsEndpoint =
      '/api/realtime/notifications';
  static const String realtimeNotificationsReadAllEndpoint =
      '/api/realtime/notifications/read-all';
  static const String authRegisterEndpoint = '/api/auth/register';
  static const String authLoginEndpoint = '/api/auth/login';
  static const String authVerifyEndpoint = '/api/auth/verify';
  static const String authChangePasswordEndpoint = '/api/auth/change-password';
  static const String userProfileEndpoint = '/api/user/profile';

  // Payment endpoints
  static const String paymentCreateEndpoint = '/api/payment/create';
  static const String paymentCallbackEndpoint = '/api/payment/callback';

  // Admin endpoints
  static const String adminDashboardEndpoint = '/api/admin/dashboard';
  static const String adminBookingsEndpoint = '/api/admin/bookings';
  static const String adminOrdersEndpoint = '/api/admin/orders';
  static const String adminStaffOrdersEndpoint = '/api/admin/orders/staff';
  static const String adminMenuEndpoint = '/api/admin/menu';
  static const String adminAnalyticsEndpoint = '/api/admin/analytics';
  static const String adminRecentActivityEndpoint =
      '/api/admin/recent-activity';
  static const String adminResourcesEndpoint = '/api/admin/resources';
  static const String adminStaffEndpoint = '/api/admin/staff';
  static const String adminStaffAssignmentsEndpoint =
      '/api/admin/staff-assignments';
  static const String adminStaffAssignmentsAllEndpoint =
      '/api/admin/staff-assignments/all';
  static const String adminCamerasEndpoint = '/api/admin/cameras';
  static const String staffCamerasEndpoint = '/api/staff/cameras';

  static String get realtimeNotificationsWsEndpoint {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri
        .replace(
          scheme: scheme,
          path: realtimeNotificationsEndpoint,
          query: '',
        )
        .toString();
  }

  // Timeouts. Keep dev receive timeout effectively open-ended for local LLMs,
  // but keep connect/send finite so unreachable backends fail quickly.
  static Duration get connectTimeout => FlavorConfig.flavor == Flavor.appDev
      ? const Duration(seconds: 30)
      : const Duration(seconds: 15);

  static Duration get receiveTimeout => FlavorConfig.flavor == Flavor.appDev
      ? const Duration(hours: 24)
      : const Duration(seconds: 60);

  static Duration get sendTimeout => FlavorConfig.flavor == Flavor.appDev
      ? const Duration(seconds: 30)
      : const Duration(seconds: 15);

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String contentTypeHeader = 'Content-Type';
  static const String applicationJson = 'application/json';
}
