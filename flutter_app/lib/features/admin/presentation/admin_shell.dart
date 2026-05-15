import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';

/// Shell screen for Admin / Staff role.
///
/// Provides a separate bottom-navigation and app-bar from the customer
/// [HomeScreen].  Customer-oriented actions (Đặt sân, Order đồ ăn, Chat AI)
/// are NOT accessible from here.
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;
  bool _notificationsStarted = false;

  static const List<_AdminNavItem> _navItems = [
    _AdminNavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Tổng quát',
      route: '/admin/dashboard',
    ),
    _AdminNavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Đặt sân',
      route: '/admin/bookings',
    ),
    _AdminNavItem(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: 'Thực đơn',
      route: '/admin/menu',
    ),
    _AdminNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Hoá đơn',
      route: '/admin/billing',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartNotifications();
    });
  }

  void _maybeStartNotifications() {
    if (_notificationsStarted) return;
    _notificationsStarted = true;
    ref.read(staffNotificationsProvider.notifier).start();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex || index >= _navItems.length) return;
    setState(() => _currentIndex = index);
    context.go(_navItems[index].route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _navItems.indexWhere((item) => item.route == location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings,
                color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Quản lý'),
          ],
        ),
        actions: [
          // Notifications bell with badge
          _NotificationBell(onTap: () => context.push('/admin/notifications')),
          // Profile menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                (user?.name.isNotEmpty == true)
                    ? user!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'analytics':
                  context.push('/admin/analytics');
                  break;
                case 'profile':
                  context.push('/admin/profile');
                  break;
                case 'logout':
                  _confirmLogout(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'header',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      user?.role.toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'analytics',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Biểu đồ'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Hồ sơ'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text('Đăng xuất',
                      style: TextStyle(color: AppColors.error)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex >= _navItems.length ? 0 : _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _navItems.map((item) {
          final isSelected = _navItems.indexOf(item) == _currentIndex;
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

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

// ─── Notification bell with unread count ────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;

  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(staffNotificationsProvider);
    final count = notifState.unreadCount;

    return IconButton(
      tooltip: 'Thông báo vận hành',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

// ─── Navigation item model ──────────────────────────────────────────────────

class _AdminNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _AdminNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
