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
  static const String staffNotifyEndpoint = '/api/staff/notify';
  static const String authLoginEndpoint = '/api/auth/login';
  static const String authVerifyEndpoint = '/api/auth/verify';
  static const String userProfileEndpoint = '/api/user/profile';

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
