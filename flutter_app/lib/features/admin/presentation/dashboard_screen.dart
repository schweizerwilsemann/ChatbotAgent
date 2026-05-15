import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/dashboard_provider.dart';

/// Dashboard / Tổng quát screen for admin.
///
/// Shows daily summary: revenue, bookings, orders, active courts,
/// recent activity feed and quick-action buttons.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load dashboard data on first build
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final today =
        DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardProvider.notifier).loadDashboard();
      },
      child: ListView(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        children: [
          ResponsiveContainer(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Date header ─────────────────────────────────
                Text(
                  today,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tổng quát hôm nay',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),

                // ── Loading / Error / Stats grid ────────────────
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(dashboardProvider.notifier)
                                .loadDashboard();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                else if (state.stats != null)
                  _StatsGrid(stats: state.stats!),
                const SizedBox(height: 24),

                // ── Quick actions ───────────────────────────────
                const _QuickActions(),
                const SizedBox(height: 24),

                // ── Recent activity ─────────────────────────────
                const _RecentActivitySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ─────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'vi_VN');

    final statCards = [
      _StatData(
        icon: Icons.attach_money,
        label: 'Doanh thu',
        value: '${currencyFormat.format(stats.totalRevenue)}đ',
        color: AppColors.success,
        trend: '', // No trend data from API yet
        trendUp: true,
      ),
      _StatData(
        icon: Icons.calendar_today,
        label: 'Lượt đặt sân',
        value: '${stats.bookingsToday}',
        color: AppColors.info,
        trend: '', // No trend data from API yet
        trendUp: true,
      ),
      _StatData(
        icon: Icons.restaurant,
        label: 'Đơn đồ ăn',
        value: '${stats.ordersToday}',
        color: AppColors.warning,
        trend: '', // No trend data from API yet
        trendUp: true,
      ),
      _StatData(
        icon: Icons.sports_tennis,
        label: 'Sân đang dùng',
        value: '${stats.activeCourts}/${stats.totalCourts}',
        color: AppColors.primary,
        trend: '', // No trend data from API yet
        trendUp: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: statCards.length,
          itemBuilder: (context, index) => _StatCard(data: statCards[index]),
        );
      },
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String trend;
  final bool trendUp;

  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
    required this.trendUp,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              const Spacer(),
              if (data.trend.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (data.trendUp ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data.trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: data.trendUp ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            data.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thao tác nhanh',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickActionChip(
              icon: Icons.add_circle_outline,
              label: 'Thêm đặt sân',
              color: AppColors.info,
              onTap: () => context.go('/admin/bookings'),
            ),
            _QuickActionChip(
              icon: Icons.edit_note,
              label: 'Sửa thực đơn',
              color: AppColors.warning,
              onTap: () => context.go('/admin/menu'),
            ),
            _QuickActionChip(
              icon: Icons.bar_chart,
              label: 'Xem biểu đồ',
              color: AppColors.primary,
              onTap: () => context.push('/admin/analytics'),
            ),
            _QuickActionChip(
              icon: Icons.receipt_long,
              label: 'Hoá đơn',
              color: AppColors.success,
              onTap: () => context.go('/admin/billing'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

// ─── Recent Activity ────────────────────────────────────────────────────────

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with real activity data from API
    final activities = [
      _ActivityItem(
        icon: Icons.sports_tennis,
        title: 'Đặt sân Billiards #3',
        subtitle: 'Khách: Nguyễn Văn A • 14:00 - 16:00',
        time: '5 phút trước',
        color: AppColors.billiardsColor,
      ),
      _ActivityItem(
        icon: Icons.restaurant,
        title: 'Order đồ ăn - Bàn #5',
        subtitle: '2x Cà phê sữa, 1x Bánh mì',
        time: '12 phút trước',
        color: AppColors.warning,
      ),
      _ActivityItem(
        icon: Icons.sports_tennis,
        title: 'Đặt sân Pickleball #1',
        subtitle: 'Khách: Trần Thị B • 16:00 - 18:00',
        time: '25 phút trước',
        color: AppColors.pickleballColor,
      ),
      _ActivityItem(
        icon: Icons.payment,
        title: 'Thanh toán #INV-0042',
        subtitle: 'Tổng: 350.000đ • Đã thanh toán',
        time: '1 giờ trước',
        color: AppColors.success,
      ),
      _ActivityItem(
        icon: Icons.cancel_outlined,
        title: 'Huỷ đặt sân Badminton #2',
        subtitle: 'Khách: Lê Văn C • Lý do: Bận',
        time: '2 giờ trước',
        color: AppColors.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hoạt động gần đây',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () => context.push('/admin/notifications'),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...activities.map((a) => _ActivityTile(activity: a)),
      ],
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: activity.color.withValues(alpha: 0.12),
            child: Icon(activity.icon, color: activity.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
