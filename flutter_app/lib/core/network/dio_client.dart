import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref);
});

class DioClient {
  late final Dio _dio;
  final Ref _ref;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  DioClient(this._ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiConstants.connectTimeoutMs,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiConstants.receiveTimeoutMs,
        ),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeoutMs),
        headers: {
          ApiConstants.contentTypeHeader: ApiConstants.applicationJson,
          'Accept': ApiConstants.applicationJson,
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_secureStorage),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Kết nối mạng quá chậm. Vui lòng thử lại.',
          statusCode: 408,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Không thể kết nối đến máy chủ. Kiểm tra lại kết nối mạng.',
          statusCode: 0,
        );
      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);
      case DioExceptionType.cancel:
        return ApiException(message: 'Yêu cầu đã bị hủy.', statusCode: 0);
      case DioExceptionType.unknown:
        if (error.error != null &&
            error.error.toString().contains('SocketException')) {
          return NetworkException(
            message: 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
            statusCode: 0,
          );
        }
        return ServerException(
          message: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
          statusCode: 500,
        );
      default:
        return ServerException(
          message: 'Đã xảy ra lỗi không xác định.',
          statusCode: 500,
        );
    }
  }

  ApiException _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode ?? 500;
    String message;

    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        message = data['detail'] ?? data['message'] ?? 'Đã xảy ra lỗi';
      } else if (data is String) {
        message = data;
      } else {
        message = 'Đã xảy ra lỗi';
      }
    } catch (_) {
      message = 'Đã xảy ra lỗi';
    }

    switch (statusCode) {
      case 400:
        return ServerException(
          message: 'Yêu cầu không hợp lệ: $message',
          statusCode: 400,
        );
      case 401:
        return ServerException(
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401,
        );
      case 403:
        return ServerException(
          message: 'Bạn không có quyền thực hiện thao tác này.',
          statusCode: 403,
        );
      case 404:
        return ServerException(
          message: 'Không tìm thấy dữ liệu yêu cầu.',
          statusCode: 404,
        );
      case 409:
        return ServerException(
          message: 'Xung đột dữ liệu: $message',
          statusCode: 409,
        );
      case 422:
        return ServerException(
          message: 'Dữ liệu không hợp lệ: $message',
          statusCode: 422,
        );
      case 500:
        return ServerException(
          message: 'Lỗi máy chủ nội bộ. Vui lòng thử lại sau.',
          statusCode: 500,
        );
      case 502:
        return ServerException(
          message: 'Máy chủ tạm thời không phản hồi.',
          statusCode: 502,
        );
      case 503:
        return ServerException(
          message: 'Dịch vụ tạm thời bảo trì.',
          statusCode: 503,
        );
      default:
        return ServerException(message: message, statusCode: statusCode);
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers[ApiConstants.authHeader] =
          '${ApiConstants.bearerPrefix}$token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _storage.delete(key: 'auth_token');
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────');
    print('│ REQUEST: ${options.method} ${options.uri}');
    print('│ Headers: ${options.headers}');
    if (options.data != null) {
      print('│ Body: ${options.data}');
    }
    if (options.queryParameters.isNotEmpty) {
      print('│ Query: ${options.queryParameters}');
    }
    print('└─────────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────');
    print('│ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
    print('│ Data: ${response.data}');
    print('└─────────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('┌─────────────────────────────────────────────────');
    print('│ ERROR: ${err.response?.statusCode} ${err.requestOptions.uri}');
    print('│ Message: ${err.message}');
    if (err.response?.data != null) {
      print('│ Data: ${err.response?.data}');
    }
    print('└─────────────────────────────────────────────────');
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
