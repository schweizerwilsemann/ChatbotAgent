import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';

/// Shell screen for Staff role.
///
/// Provides a limited navigation for staff members:
/// - Đặt sân (Bookings management)
/// - Thực đơn (Menu management)
/// - Thông báo (Notifications/Requests)
///
/// Staff cannot access Dashboard, Analytics, or Billing (revenue data).
class StaffShell extends ConsumerStatefulWidget {
  final Widget child;

  const StaffShell({super.key, required this.child});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  int _currentIndex = 0;
  bool _notificationsStarted = false;

  static const List<_StaffNavItem> _navItems = [
    _StaffNavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Đặt sân',
      route: '/staff/bookings',
    ),
    _StaffNavItem(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: 'Thực đơn',
      route: '/staff/menu',
    ),
    _StaffNavItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Thông báo',
      route: '/staff/notifications',
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
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Nhân viên'),
          ],
        ),
        actions: [
          // Notifications bell with badge
          _NotificationBell(onTap: () => context.go('/staff/notifications')),
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
                case 'profile':
                  context.push('/staff/profile');
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
                    const Text(
                      'NHÂN VIÊN',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Divider(),
                  ],
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

class _StaffNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _StaffNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
