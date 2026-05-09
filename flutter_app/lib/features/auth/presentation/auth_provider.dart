import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

/// Provider for the AuthRepository
/// Note: authRepositoryProvider is also declared in auth_repository.dart;
/// this re-export keeps the presentation layer self-contained.
final authRepoProvider = Provider<AuthRepository>((ref) {
  return ref.watch(authRepositoryProvider);
});

// ---------------------------------------------------------------------------
// Auth state – holds the currently logged-in user (or null)
// ---------------------------------------------------------------------------

/// Async provider that exposes the current authentication state.
/// On app start it attempts auto-login from the persisted secure-storage token.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
      return AuthStateNotifier(ref.watch(authRepoProvider));
    });

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;

  AuthStateNotifier(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  /// Try to restore session on construction
  Future<void> _init() async {
    try {
      final user = await _repository.tryAutoLogin();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Log in with [phone] and [password], update state to the logged-in user
  Future<bool> login(String phone, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(phone, password);
      state = AsyncValue.data(user);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Log out and clear the stored session
  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  /// Refresh the user profile from the API
  Future<void> refreshProfile() async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return;

    try {
      final user = await _repository.getProfile(currentUser.id);
      state = AsyncValue.data(user);
    } catch (_) {
      // Silently fail – user is still logged in with stale data
    }
  }
}

// ---------------------------------------------------------------------------
// Login action provider (convenience)
// ---------------------------------------------------------------------------

/// State class for the login action (loading / error feedback)
class LoginState {
  final bool isLoading;
  final String? error;

  const LoginState({this.isLoading = false, this.error});

  LoginState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier wrapping the login flow for UI consumption
class LoginNotifier extends StateNotifier<LoginState> {
  final AuthStateNotifier _authNotifier;

  LoginNotifier(this._authNotifier) : super(const LoginState());

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final success = await _authNotifier.login(phone, password);
    if (!success) {
      state = state.copyWith(
        isLoading: false,
        error: 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.',
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
    return success;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref.watch(authStateProvider.notifier));
});
