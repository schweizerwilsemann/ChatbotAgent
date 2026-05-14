import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_shell.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/analytics_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_profile_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/dashboard_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/menu_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/billing_screen.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/login_screen.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_screen.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_screen.dart';
import 'package:sports_venue_chatbot/features/home_screen.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_screen.dart';
import 'package:sports_venue_chatbot/features/profile/presentation/profile_screen.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Don't redirect while auth state is still loading (auto-login in progress)
      if (authState.isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final userRole = authState.valueOrNull?.role.toUpperCase();
      final isLoginRoute = state.matchedLocation == '/login';
      final isAdminRoute = state.matchedLocation.startsWith('/admin');

      // ── Not logged in → force to login ────────────────────────
      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      // ── Logged in on login page → redirect based on role ─────
      if (isLoggedIn && isLoginRoute) {
        if (userRole == 'ADMIN' || userRole == 'STAFF') {
          return '/admin/dashboard';
        }
        return '/home';
      }

      // ── Admin/Staff accessing customer routes → redirect to admin ──
      if (isLoggedIn &&
          (userRole == 'ADMIN' || userRole == 'STAFF') &&
          !isAdminRoute) {
        return '/admin/dashboard';
      }

      // ── Customer accessing admin routes → redirect to home ───
      if (isLoggedIn &&
          userRole != 'ADMIN' &&
          userRole != 'STAFF' &&
          isAdminRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Login ────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Customer shell ───────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: '/booking',
            name: 'booking',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookingScreen()),
          ),
          GoRoute(
            path: '/menu',
            name: 'menu',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MenuScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // ── Admin / Staff shell ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            name: 'admin_dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/admin/bookings',
            name: 'admin_bookings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookingManagementScreen()),
          ),
          GoRoute(
            path: '/admin/menu',
            name: 'admin_menu',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MenuManagementScreen()),
          ),
          GoRoute(
            path: '/admin/billing',
            name: 'admin_billing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BillingScreen()),
          ),
        ],
      ),

      // ── Admin top-level routes (own Scaffold, not inside AdminShell) ──
      GoRoute(
        path: '/admin/analytics',
        name: 'admin_analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/admin/notifications',
        name: 'admin_notifications',
        builder: (context, state) => const StaffNotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/profile',
        name: 'admin_profile',
        builder: (context, state) => const AdminProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy trang',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Đã xảy ra lỗi',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  );
});
