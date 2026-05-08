/// Base exception for all API-related errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic data;

  ApiException({required this.message, required this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}

/// Exception thrown when the server returns an error response
class ServerException extends ApiException {
  ServerException({
    required String message,
    required int statusCode,
    dynamic data,
  }) : super(message: message, statusCode: statusCode, data: data);

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Exception thrown when there's a network connectivity issue
class NetworkException extends ApiException {
  NetworkException({required String message, int statusCode = 0})
    : super(message: message, statusCode: statusCode);

  @override
  String toString() => 'NetworkException: $message';

  bool get isTimeout => statusCode == 408;
  bool get isNoConnection => statusCode == 0;
}

/// Exception thrown when authentication fails
class AuthException extends ApiException {
  AuthException({
    String message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    int statusCode = 401,
  }) : super(message: message, statusCode: statusCode);

  @override
  String toString() => 'AuthException: $message';
}

/// Exception thrown when a requested resource is not found
class NotFoundException extends ApiException {
  NotFoundException({
    String message = 'Không tìm thấy dữ liệu yêu cầu.',
    int statusCode = 404,
  }) : super(message: message, statusCode: statusCode);

  @override
  String toString() => 'NotFoundException: $message';
}

/// Exception thrown when validation fails
class ValidationException extends ApiException {
  final Map<String, List<String>>? errors;

  ValidationException({
    String message = 'Dữ liệu không hợp lệ.',
    int statusCode = 422,
    this.errors,
  }) : super(message: message, statusCode: statusCode, data: errors);

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception for timeout scenarios
class TimeoutException extends NetworkException {
  TimeoutException({String message = 'Kết nối quá chậm. Vui lòng thử lại.'})
    : super(message: message, statusCode: 408);

  @override
  String toString() => 'TimeoutException: $message';
}
