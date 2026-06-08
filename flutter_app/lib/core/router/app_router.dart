import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/analytics_screen.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/payment_webview_screen.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/payment_result_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_profile_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/dashboard_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/menu_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/billing_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/staff_management_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_notifications_screen.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/resource_pricing_screen.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/billing/presentation/customer_billing_screen.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/login_screen.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_screen.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_qr_scan_screen.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_agent_call_screen.dart';
import 'package:sports_venue_chatbot/features/call/presentation/incoming_call_screen.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_screen.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/customer_staff_chat_screen.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_chat_screen.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_inbox_screen.dart';
import 'package:sports_venue_chatbot/features/staff_request/presentation/staff_request_management_screen.dart';
import 'package:sports_venue_chatbot/features/home_screen.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_screen.dart';
import 'package:sports_venue_chatbot/features/profile/presentation/profile_screen.dart';
import 'package:sports_venue_chatbot/features/settings/presentation/settings_screen.dart';
import 'package:sports_venue_chatbot/features/shared/presentation/role_based_shell.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_screen.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_billing_screen.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_profile_screen.dart';
import 'package:sports_venue_chatbot/shared/widgets/loading_widget.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final userRole = authState.valueOrNull?.role.toUpperCase();
      final location = state.matchedLocation;
      final isSplashRoute = location == '/splash';
      final isLoginRoute = location == '/login';
      final isAdminRoute =
          location == '/admin' || location.startsWith('/admin/');
      final isStaffRoute = location == '/staff' ||
          location.startsWith('/staff/') ||
          location.startsWith('/staff-operator-chat/');
      final isManagementRoute = isAdminRoute || isStaffRoute;

      if (authState.isLoading) {
        return isSplashRoute ? null : '/splash';
      }

      if (isSplashRoute) {
        if (!isLoggedIn) return '/login';
        if (userRole == 'ADMIN') return '/admin/dashboard';
        if (userRole == 'STAFF') return '/staff/requests';
        return '/home';
      }

      // Not logged in → login
      if (!isLoggedIn && !isLoginRoute) return '/login';

      // Logged in on login page → redirect by role
      if (isLoggedIn && isLoginRoute) {
        if (userRole == 'ADMIN') return '/admin/dashboard';
        if (userRole == 'STAFF') return '/staff/requests';
        return '/home';
      }

      // Staff trying admin routes → staff area
      if (isLoggedIn && userRole == 'STAFF' && isAdminRoute) {
        return '/staff/requests';
      }

      // Admin trying staff routes → admin area
      if (isLoggedIn && userRole == 'ADMIN' && isStaffRoute) {
        return '/admin/dashboard';
      }

      // Logged-in staff/admin on customer routes → their area
      // Exception: allow call, voice-agent, and staff-chat routes for all roles
      final isCallRoute = location == '/call' || location == '/voice-agent';
      final isStaffChatRoute = location.startsWith('/staff-chat/') ||
          location.startsWith('/staff-operator-chat/');
      if (isLoggedIn &&
          !isManagementRoute &&
          !isCallRoute &&
          !isStaffChatRoute) {
        if (userRole == 'ADMIN') return '/admin/dashboard';
        if (userRole == 'STAFF') return '/staff/requests';
      }

      // Customer on management routes → home
      if (isLoggedIn &&
          userRole != 'ADMIN' &&
          userRole != 'STAFF' &&
          isManagementRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const Scaffold(
            body: LoadingWidget(message: 'Đang kiểm tra phiên đăng nhập...')),
      ),

      // Login
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/scan-qr',
        name: 'scan_qr',
        builder: (context, state) => const BookingQrScanScreen(),
      ),

      // Customer shell
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
            path: '/billing',
            name: 'customer_billing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CustomerBillingScreen()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
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
          GoRoute(
            path: '/admin/staff',
            name: 'admin_staff',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StaffManagementScreen()),
          ),

          // Staff routes
          GoRoute(
            path: '/staff/bookings',
            name: 'staff_bookings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BookingManagementScreen()),
          ),
          GoRoute(
            path: '/staff/menu',
            name: 'staff_menu',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MenuManagementScreen()),
          ),
          GoRoute(
            path: '/staff/billing',
            name: 'staff_billing',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StaffBillingScreen()),
          ),
          GoRoute(
            path: '/staff/requests',
            name: 'staff_requests',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StaffRequestManagementScreen()),
          ),
          GoRoute(
            path: '/staff/notifications',
            name: 'staff_notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StaffNotificationsScreen()),
          ),
          GoRoute(
            path: '/staff/inbox',
            name: 'staff_inbox',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StaffInboxScreen()),
          ),
          GoRoute(
            path: '/admin/settings',
            name: 'admin_settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/staff/settings',
            name: 'staff_settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
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
        path: '/admin/resource-pricing',
        name: 'admin_resource_pricing',
        builder: (context, state) => const ResourcePricingScreen(),
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
      GoRoute(
        path: '/payment',
        name: 'payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymentWebviewScreen(
            paymentUrl: extra['paymentUrl'] as String,
            orderId: extra['orderId'] as String,
            orderType: extra['orderType'] as String? ?? 'booking',
          );
        },
      ),
      GoRoute(
        path: '/payment/result',
        name: 'payment_result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PaymentResultScreen(
            success: extra['success'] as bool? ?? false,
            orderId: extra['orderId'] as String? ?? '',
            orderType: extra['orderType'] as String? ?? 'booking',
            code: extra['code'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/voice-agent',
        name: 'voice_agent',
        builder: (context, state) => const VoiceAgentCallScreen(),
      ),
      GoRoute(
        path: '/call',
        name: 'call',
        builder: (context, state) => const IncomingCallScreen(),
      ),
      GoRoute(
        path: '/staff-chat/:requestId',
        name: 'staff_chat',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return CustomerStaffChatScreen(
            requestId: requestId,
            staffName: extra?['staffName'] as String?,
            staffId: extra?['staffId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/staff-operator-chat/:requestId',
        name: 'staff_operator_chat',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return StaffChatScreen(
            requestId: requestId,
            customerName: extra?['customerName'] as String?,
            resourceLabel: extra?['resourceLabel'] as String?,
            customerId: extra?['customerId'] as String?,
          );
        },
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
