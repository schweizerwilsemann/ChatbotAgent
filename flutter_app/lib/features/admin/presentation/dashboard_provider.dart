import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class DashboardState {
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.stats,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardStats? stats,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearStats = false,
  }) {
    return DashboardState(
      stats: clearStats ? null : (stats ?? this.stats),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class DashboardNotifier extends StateNotifier<DashboardState> {
  final AdminApi _adminApi;

  DashboardNotifier(this._adminApi) : super(const DashboardState());

  /// Load dashboard stats from the API.
  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final stats = await _adminApi.getDashboardStats();
      state = state.copyWith(stats: stats, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải dữ liệu tổng quan.',
      );
    }
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(adminApiProvider));
});
