import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class AnalyticsState {
  final AnalyticsData? analytics;
  final bool isLoading;
  final String? error;
  final String period;

  const AnalyticsState({
    this.analytics,
    this.isLoading = false,
    this.error,
    this.period = 'week',
  });

  AnalyticsState copyWith({
    AnalyticsData? analytics,
    bool? isLoading,
    String? error,
    String? period,
    bool clearError = false,
    bool clearAnalytics = false,
  }) {
    return AnalyticsState(
      analytics: clearAnalytics ? null : (analytics ?? this.analytics),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      period: period ?? this.period,
    );
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final AdminApi _adminApi;

  AnalyticsNotifier(this._adminApi) : super(const AnalyticsState());

  /// Load analytics data from the API for the current period.
  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final analytics = await _adminApi.getAnalytics(period: state.period);
      state = state.copyWith(analytics: analytics, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải dữ liệu phân tích.',
      );
    }
  }

  /// Set the analytics period and reload.
  Future<void> setPeriod(String period) async {
    state = state.copyWith(period: period);
    await loadAnalytics();
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref.watch(adminApiProvider));
});
