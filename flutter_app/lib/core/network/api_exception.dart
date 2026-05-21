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
    required super.message,
    required super.statusCode,
    super.data,
  });

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Exception thrown when there's a network connectivity issue
class NetworkException extends ApiException {
  NetworkException({required super.message, super.statusCode = 0});

  @override
  String toString() => 'NetworkException: $message';

  bool get isTimeout => statusCode == 408;
  bool get isNoConnection => statusCode == 0;
}

/// Exception thrown when authentication fails
class AuthException extends ApiException {
  AuthException({
    super.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    super.statusCode = 401,
  });

  @override
  String toString() => 'AuthException: $message';
}

/// Exception thrown when a requested resource is not found
class NotFoundException extends ApiException {
  NotFoundException({
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    super.statusCode = 404,
  });

  @override
  String toString() => 'NotFoundException: $message';
}

/// Exception thrown when validation fails
class ValidationException extends ApiException {
  final Map<String, List<String>>? errors;

  ValidationException({
    super.message = 'Dữ liệu không hợp lệ.',
    super.statusCode = 422,
    this.errors,
  }) : super(data: errors);

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception for timeout scenarios
class TimeoutException extends NetworkException {
  TimeoutException({super.message = 'Kết nối quá chậm. Vui lòng thử lại.'})
      : super(statusCode: 408);

  @override
  String toString() => 'TimeoutException: $message';
}
