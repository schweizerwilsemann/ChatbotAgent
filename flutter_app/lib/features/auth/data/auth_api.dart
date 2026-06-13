import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider));
});

class AuthApi {
  final DioClient _dioClient;

  AuthApi(this._dioClient);

  /// Register a customer account and return its authenticated session.
  Future<AuthResponse> register({
    required String phone,
    required String name,
    required String password,
  }) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiConstants.authRegisterEndpoint,
      data: {
        'phone': phone,
        'name': name,
        'password': password,
      },
    );
    return AuthResponse.fromJson(response.data!);
  }

  /// Login with phone number and password, returns auth response with token
  Future<AuthResponse> login(String phone, String password) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.authLoginEndpoint,
        data: {'phone': phone, 'password': password},
      );
      return AuthResponse.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get the user profile by user ID
  Future<User> getProfile(String userId) async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '${ApiConstants.userProfileEndpoint}/$userId',
      );
      return User.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Verify the current token is still valid
  Future<User> verifyToken() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        ApiConstants.authVerifyEndpoint,
      );
      return User.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.authChangePasswordEndpoint,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}
