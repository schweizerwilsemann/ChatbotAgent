import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_api.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/domain/vietnam_phone_number.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(secureStorageProvider),
  );
});

/// Abstract auth repository interface
abstract class IAuthRepository {
  Future<User> register({
    required String phone,
    required String name,
    required String password,
  });
  Future<User> login(String phone, String password);
  Future<User> getProfile(String userId);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<User?> tryAutoLogin();
}

/// Concrete implementation of the auth repository
class AuthRepository implements IAuthRepository {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';

  final AuthApi _authApi;
  final FlutterSecureStorage _secureStorage;

  AuthRepository(this._authApi, this._secureStorage);

  @override
  Future<User> register({
    required String phone,
    required String name,
    required String password,
  }) async {
    try {
      final phoneError = VietnamPhoneNumber.validateForRegistration(phone);
      if (phoneError != null) {
        throw ValidationException(message: phoneError);
      }
      if (name.trim().isEmpty) {
        throw ValidationException(message: 'Vui lòng nhập họ và tên');
      }
      if (password.length < 8) {
        throw ValidationException(message: 'Mật khẩu tối thiểu 8 ký tự');
      }

      final authResponse = await _authApi.register(
        phone: VietnamPhoneNumber.normalize(phone),
        name: name.trim(),
        password: password,
      );
      await _persistSession(authResponse);
      return authResponse.user;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ServerException(
        message: 'Đăng ký thất bại. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<User> login(String phone, String password) async {
    try {
      if (phone.trim().isEmpty) {
        throw ValidationException(message: 'Vui lòng nhập số điện thoại');
      }
      if (password.isEmpty) {
        throw ValidationException(message: 'Vui lòng nhập mật khẩu');
      }

      final authResponse = await _authApi.login(
        VietnamPhoneNumber.normalize(phone),
        password,
      );
      await _persistSession(authResponse);

      return authResponse.user;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Đăng nhập thất bại. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<User> getProfile(String userId) async {
    try {
      return await _authApi.getProfile(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải thông tin người dùng.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (currentPassword.isEmpty) {
        throw ValidationException(message: 'Vui lòng nhập mật khẩu hiện tại');
      }
      if (newPassword.length < 8) {
        throw ValidationException(message: 'Mật khẩu mới tối thiểu 8 ký tự');
      }
      await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể đổi mật khẩu. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Attempt to auto-login using the stored token.
  /// Returns the [User] if the token is still valid, otherwise `null`.
  @override
  Future<User?> tryAutoLogin() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final userId = await _secureStorage.read(key: _userIdKey);

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }

    try {
      // Verify token by fetching the user profile
      final user = await _authApi.getProfile(userId);
      return user;
    } on ApiException {
      // Token expired or invalid – clean up
      await logout();
      return null;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _secureStorage.write(key: _tokenKey, value: authResponse.token);
    await _secureStorage.write(key: _userIdKey, value: authResponse.user.id);
  }
}
