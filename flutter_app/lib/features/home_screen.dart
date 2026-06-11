import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_model.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/selected_venue_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/floating_bottom_nav.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Khám phá',
      route: '/explore',
    ),
    _NavigationItem(
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
      label: 'Dịch vụ',
      route: '/menu',
    ),
    _NavigationItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Đơn đặt',
      route: '/billing',
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
    final venuesAsync = ref.watch(venuesProvider);
    final selectedVenue = ref.watch(selectedVenueProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: venuesAsync.when(
          loading: () => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, __) => const Text('Chọn sân'),
          data: (venues) {
            if (venues.isEmpty) return const Text('Không có sân');
            // Show loading until auto-select completes
            if (selectedVenue == null) {
              return const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return _VenueDropdown(
              venues: venues,
              selected: selectedVenue,
              onChanged: (venue) {
                ref.read(selectedVenueProvider.notifier).select(venue);
              },
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: 'Quét QR nhận sân',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/scan-qr'),
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
                color: AppColors.primary,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VenueDropdown extends StatelessWidget {
  final List<Venue> venues;
  final Venue? selected;
  final ValueChanged<Venue> onChanged;

  const _VenueDropdown({
    required this.venues,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return const Text('Không có sân nào');
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Venue>(
            value: selected,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 20, color: AppColors.textPrimary),
            dropdownColor: AppColors.surface,
            hint: const Text(
              'Chọn sân',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            items: venues.map((venue) {
              return DropdownMenuItem<Venue>(
                value: venue,
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (venue) {
              if (venue != null) onChanged(venue);
            },
          ),
        ),
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
