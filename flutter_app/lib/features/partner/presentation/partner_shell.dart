import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/floating_bottom_nav.dart';

class PartnerShell extends ConsumerStatefulWidget {
  final Widget child;

  const PartnerShell({super.key, required this.child});

  @override
  ConsumerState<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends ConsumerState<PartnerShell> {
  int _currentIndex = 0;

  static const List<_PartnerNavItem> _navItems = [
    _PartnerNavItem(
      icon: Icons.store_outlined,
      selectedIcon: Icons.store,
      label: 'Cửa hàng',
      route: '/partner/dashboard',
    ),
    _PartnerNavItem(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: 'Thực đơn',
      route: '/partner/menu',
    ),
    _PartnerNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Đơn hàng',
      route: '/partner/orders',
    ),
  ];

  @override
  void initState() {
    super.initState();
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
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.storefront, color: Color(0xFFE67E22), size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                user?.name ?? 'Đối tác',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE67E22).withOpacity(0.15),
              child: Text(
                (user?.name.isNotEmpty == true)
                    ? user!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFFE67E22),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _confirmLogout(context, ref);
              } else if (value == 'settings') {
                context.push('/partner/settings');
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
                      'ĐỐI TÁC',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE67E22),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Cài đặt'),
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
        ],
      ),
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
                color: const Color(0xFFE67E22),
              ),
            )
            .toList(),
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
              foregroundColor: AppColors.textOnPrimary,
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

class _PartnerNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _PartnerNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
