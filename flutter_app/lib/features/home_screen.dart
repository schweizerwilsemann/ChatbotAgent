import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';

/// Home screen with bottom navigation bar (Material 3 NavigationBar).
///
/// Used as a [ShellRoute] wrapper in [GoRouter].
class HomeScreen extends ConsumerStatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _notificationsStarted = false;

  static const List<_NavigationItem> _customerNavItems = [
    _NavigationItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: 'Chat',
      route: '/chat',
    ),
    _NavigationItem(
      icon: Icons.sports_tennis_outlined,
      selectedIcon: Icons.sports_tennis,
      label: 'Đặt sân',
      route: '/booking',
    ),
    _NavigationItem(
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
      label: 'Thực đơn',
      route: '/menu',
    ),
    _NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Cá nhân',
      route: '/profile',
    ),
  ];

  static const _staffNavItem = _NavigationItem(
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    label: 'Vận hành',
    route: '/staff',
  );

  @override
  void initState() {
    super.initState();
    // Defer provider modification until after the first build frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartNotifications();
    });
  }

  void _maybeStartNotifications() {
    if (_notificationsStarted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (_canUseStaffPanel(user?.role)) {
      _notificationsStarted = true;
      ref.read(staffNotificationsProvider.notifier).start();
    }
  }

  void _onTabTapped(int index) {
    final navItems = _navItems();
    if (index == _currentIndex || index >= navItems.length) return;

    setState(() {
      _currentIndex = index;
    });

    context.go(navItems[index].route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the current index with the router location
    final location = GoRouterState.of(context).matchedLocation;
    final index = _navItems().indexWhere((item) => item.route == location);
    if (index != -1 && index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final navItems = _navItems();
    // Notifications are started in initState via addPostFrameCallback.
    // If the role changes at runtime, try again here (deferred).
    if (!_notificationsStarted && _canUseStaffPanel(user?.role)) {
      _notificationsStarted = true;
      Future.microtask(
        () => ref.read(staffNotificationsProvider.notifier).start(),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex >= navItems.length ? 0 : _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: navItems.map((item) {
          final isSelected = navItems.indexOf(item) == _currentIndex;
          return NavigationDestination(
            icon: Icon(
              item.icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            selectedIcon: Icon(item.selectedIcon, color: AppColors.primary),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  List<_NavigationItem> _navItems() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (_canUseStaffPanel(user?.role)) {
      return [..._customerNavItems, _staffNavItem];
    }
    return _customerNavItems;
  }

  bool _canUseStaffPanel(String? role) {
    final normalized = role?.toUpperCase();
    return normalized == 'STAFF' || normalized == 'ADMIN';
  }
}

class _NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
