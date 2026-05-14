import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/analytics_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_profile_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/dashboard_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/menu_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/billing_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_notifications_screen.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/login_screen.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_screen.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_screen.dart';
import 'package:sports_venue_chatbot/features/home_screen.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_screen.dart';
import 'package:sports_venue_chatbot/features/profile/presentation/profile_screen.dart';
import 'package:sports_venue_chatbot/features/shared/presentation/role_based_shell.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_screen.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final userRole = authState.valueOrNull?.role.toUpperCase();
      final location = state.matchedLocation;
      final isLoginRoute = location == '/login';
      final isAdminRoute = location.startsWith('/admin');
      final isStaffRoute = location.startsWith('/staff');
      final isManagementRoute = isAdminRoute || isStaffRoute;

      // Not logged in → login
      if (!isLoggedIn && !isLoginRoute) return '/login';

      // Logged in on login page → redirect by role
      if (isLoggedIn && isLoginRoute) {
        if (userRole == 'ADMIN') return '/admin/dashboard';
        if (userRole == 'STAFF') return '/staff/notifications';
        return '/home';
      }

      // Staff trying admin routes → staff area
      if (isLoggedIn && userRole == 'STAFF' && isAdminRoute) {
        return '/staff/notifications';
      }

      // Admin trying staff routes → admin area
      if (isLoggedIn && userRole == 'ADMIN' && isStaffRoute) {
        return '/admin/dashboard';
      }

      // Logged-in staff/admin on customer routes → their area
      if (isLoggedIn && !isManagementRoute) {
        if (userRole == 'ADMIN') return '/admin/dashboard';
        if (userRole == 'STAFF') return '/staff/notifications';
      }

      // Customer on management routes → home
      if (isLoggedIn && userRole != 'ADMIN' && userRole != 'STAFF' && isManagementRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Login
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Customer shell
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            pageBuilder: (context, state) => const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: '/booking',
            name: 'booking',
            pageBuilder: (context, state) => const NoTransitionPage(child: BookingScreen()),
          ),
          GoRoute(
            path: '/menu',
            name: 'menu',
            pageBuilder: (context, state) => const NoTransitionPage(child: MenuScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // Management shell (Admin + Staff)
      ShellRoute(
        builder: (context, state, child) => RoleBasedShell(child: child),
        routes: [
          // Admin-only routes
          GoRoute(
            path: '/admin/dashboard',
            name: 'admin_dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/admin/bookings',
            name: 'admin_bookings',
            pageBuilder: (context, state) => const NoTransitionPage(child: BookingManagementScreen()),
          ),
          GoRoute(
            path: '/admin/menu',
            name: 'admin_menu',
            pageBuilder: (context, state) => const NoTransitionPage(child: MenuManagementScreen()),
          ),
          GoRoute(
            path: '/admin/billing',
            name: 'admin_billing',
            pageBuilder: (context, state) => const NoTransitionPage(child: BillingScreen()),
          ),

          // Staff routes
          GoRoute(
            path: '/staff/bookings',
            name: 'staff_bookings',
            pageBuilder: (context, state) => const NoTransitionPage(child: BookingManagementScreen()),
          ),
          GoRoute(
            path: '/staff/menu',
            name: 'staff_menu',
            pageBuilder: (context, state) => const NoTransitionPage(child: MenuManagementScreen()),
          ),
          GoRoute(
            path: '/staff/notifications',
            name: 'staff_notifications',
            pageBuilder: (context, state) => const NoTransitionPage(child: StaffNotificationsScreen()),
          ),
        ],
      ),

      // Top-level routes (own Scaffold)
      GoRoute(
        path: '/admin/analytics',
        name: 'admin_analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/admin/notifications',
        name: 'admin_notifications',
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/profile',
        name: 'admin_profile',
        builder: (context, state) => const AdminProfileScreen(),
      ),
      GoRoute(
        path: '/staff/profile',
        name: 'staff_profile',
        builder: (context, state) => const StaffProfileScreen(),
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
