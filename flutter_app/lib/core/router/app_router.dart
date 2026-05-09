import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/login_screen.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_screen.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_screen.dart';
import 'package:sports_venue_chatbot/features/home_screen.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_screen.dart';
import 'package:sports_venue_chatbot/features/profile/presentation/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      // If not logged in and not on login page, redirect to login
      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      // If logged in and on login page, redirect to home
      if (isLoggedIn && isLoginRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
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
