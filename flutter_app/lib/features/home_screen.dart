import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/shared/widgets/floating_bottom_nav.dart';

/// Home screen with bottom navigation bar for **customers only**.
///
/// Admin / Staff users are redirected to [AdminShell] by the router
/// and never see this screen.
///
/// Used as a [ShellRoute] wrapper in [GoRouter].
class HomeScreen extends StatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<_NavigationItem> _navItems = [
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

  void _onTabTapped(int index) {
    if (index == _currentIndex || index >= _navItems.length) return;

    setState(() {
      _currentIndex = index;
    });

    context.go(_navItems[index].route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the current index with the router location
    final location = GoRouterState.of(context).matchedLocation;
    final index = _navItems.indexWhere((item) => item.route == location);
    if (index != -1 && index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: FloatingBottomNav(
        selectedIndex: _currentIndex >= _navItems.length ? 0 : _currentIndex,
        onTap: _onTabTapped,
        items: _navItems
            .map(
              (item) => FloatingBottomNavItem(
                icon: item.icon,
                selectedIcon: item.selectedIcon,
                label: item.label,
                color: AppColors.primary,
              ),
            )
            .toList(),
      ),
    );
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
