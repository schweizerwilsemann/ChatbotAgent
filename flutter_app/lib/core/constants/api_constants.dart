class ApiConstants {
  ApiConstants._();

  // Base URL - configurable per environment
  // 10.0.2.2 is Android emulator's localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

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

  // Timeouts
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
  static const int sendTimeoutMs = 15000;

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String contentTypeHeader = 'Content-Type';
  static const String applicationJson = 'application/json';
}
