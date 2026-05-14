import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/analytics_provider.dart';

/// Analytics / Charts screen for admin.
///
/// Features:
/// - Revenue chart (daily / weekly / monthly)
/// - Popular courts chart
/// - Peak hours chart
/// - Order trends
/// - Summary table with computed totals
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  static const _periodLabels = ['Hôm nay', 'Tuần này', 'Tháng này', 'Năm nay'];
  static const _periodValues = ['today', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider.notifier).loadAnalytics();
    });
  }

  String _periodLabel(String value) {
    final idx = _periodValues.indexOf(value);
    return idx >= 0 ? _periodLabels[idx] : value;
  }

  String _dayLabel(String dateStr) {
    final date = DateTime.parse(dateStr);
    const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return days[date.weekday % 7];
  }

  Color _courtTypeColor(String courtType) {
    switch (courtType.toLowerCase()) {
      case 'billiards':
        return AppColors.billiardsColor;
      case 'pickleball':
        return AppColors.pickleballColor;
      case 'badminton':
      case 'cầu lông':
        return AppColors.badmintonColor;
      default:
        return AppColors.primary;
    }
  }

  String _formatRevenue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}tr';
    }
    return '${(value / 1000).toInt()}k';
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(value.round())}đ';
  }

  String _courtTypeDisplayName(String courtType) {
    switch (courtType.toLowerCase()) {
      case 'billiards':
        return 'Billiards';
      case 'pickleball':
        return 'Pickleball';
      case 'badminton':
        return 'Cầu lông';
      default:
        return courtType[0].toUpperCase() + courtType.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);
    final periodLabel = _periodLabel(state.period);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu đồ & Phân tích'),
        actions: [
          // Period selector
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.period,
                isDense: true,
                items: List.generate(
                  _periodValues.length,
                  (i) => DropdownMenuItem(
                    value: _periodValues[i],
                    child: Text(_periodLabels[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(analyticsProvider.notifier).setPeriod(v);
                  }
                },
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
        child: _buildBody(state, periodLabel),
      ),
    );
  }

  Widget _buildBody(AnalyticsState state, String periodLabel) {
    // Loading state (no data yet)
    if (state.isLoading && state.analytics == null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    // Error state (no data)
    if (state.error != null && state.analytics == null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(analyticsProvider.notifier).loadAnalytics(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Empty / null data
    final analytics = state.analytics;
    if (analytics == null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: Text(
                'Chưa có dữ liệu phân tích',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Data loaded — show charts
    return ListView(
      padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
      children: [
        ResponsiveContainer(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Loading overlay indicator ─────────────────────
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),

              // ── Revenue chart ─────────────────────────────────
              _ChartCard(
                title: 'Doanh thu',
                subtitle: periodLabel,
                child: _RevenueBarChart(
                  data: analytics.revenueByDay,
                  dayLabel: _dayLabel,
                  formatRevenue: _formatRevenue,
                ),
              ),
              const SizedBox(height: 16),

              // ── Popular courts ────────────────────────────────
              _ChartCard(
                title: 'Sân phổ biến',
                subtitle: 'Số lượt đặt trong $periodLabel',
                child: _PopularCourtsChart(
                  data: analytics.bookingsByCourt,
                  courtTypeColor: _courtTypeColor,
                  courtTypeName: _courtTypeDisplayName,
                ),
              ),
              const SizedBox(height: 16),

              // ── Peak hours ────────────────────────────────────
              _ChartCard(
                title: 'Giờ cao điểm',
                subtitle: 'Phân bố lượt đặt theo giờ',
                child: _PeakHoursChart(data: analytics.ordersByHour),
              ),
              const SizedBox(height: 16),

              // ── Order trends ──────────────────────────────────
              _ChartCard(
                title: 'Đơn đồ ăn',
                subtitle: 'Số lượng đơn theo ngày',
                child: _OrderTrendChart(
                  data: analytics.orderCountByDay,
                  dayLabel: _dayLabel,
                ),
              ),
              const SizedBox(height: 16),

              // ── Summary table ─────────────────────────────────
              _SummaryTable(
                analytics: analytics,
                formatCurrency: _formatCurrency,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Chart card wrapper ─────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Revenue Bar Chart ──────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<DayRevenue> data;
  final String Function(String) dayLabel;
  final String Function(double) formatRevenue;

  const _RevenueBarChart({
    required this.data,
    required this.dayLabel,
    required this.formatRevenue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Không có dữ liệu doanh thu',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ),
      );
    }

    final maxValue = data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final ratio = maxValue > 0 ? d.revenue / maxValue : 0.0;
          final isHighest = d.revenue == maxValue;
          final color = isHighest ? AppColors.success : AppColors.primary;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatRevenue(d.revenue),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: ratio * 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabel(d.date),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Popular Courts Chart (horizontal bars) ─────────────────────────────────

class _PopularCourtsChart extends StatelessWidget {
  final List<CourtBookingCount> data;
  final Color Function(String) courtTypeColor;
  final String Function(String) courtTypeName;

  const _PopularCourtsChart({
    required this.data,
    required this.courtTypeColor,
    required this.courtTypeName,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Không có dữ liệu đặt sân',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ),
      );
    }

    final maxValue = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map((d) {
        final ratio = maxValue > 0 ? d.count / maxValue : 0.0;
        final color = courtTypeColor(d.courtType);
        final label = '${courtTypeName(d.courtType)} #${d.courtNumber}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${d.count}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Peak Hours Chart ───────────────────────────────────────────────────────

class _PeakHoursChart extends StatelessWidget {
  final List<HourOrderCount> data;

  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Không có dữ liệu giờ cao điểm',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ),
      );
    }

    final maxVal = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final peakThreshold = maxVal * 0.8;

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final d = data[i];
          final ratio = maxVal > 0 ? d.count / maxVal : 0.0;
          final isPeak = d.count >= peakThreshold;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPeak)
                    const Icon(Icons.star, size: 10, color: AppColors.warning),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300 + i * 50),
                    height: ratio * 100,
                    decoration: BoxDecoration(
                      color: isPeak
                          ? AppColors.warning.withValues(alpha: 0.8)
                          : AppColors.info.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.hour}h',
                    style: TextStyle(
                      fontSize: 9,
                      color: isPeak ? AppColors.warning : AppColors.textHint,
                      fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Order Trend Chart (line-like with dots) ────────────────────────────────

class _OrderTrendChart extends StatelessWidget {
  final List<DayOrderCount> data;
  final String Function(String) dayLabel;

  const _OrderTrendChart({
    required this.data,
    required this.dayLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Không có dữ liệu đơn hàng',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ),
      );
    }

    final maxVal = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final d = data[i];
          final ratio = maxVal > 0 ? d.count / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${d.count}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primarySurface,
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: ratio * 100,
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabel(d.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Summary Table ──────────────────────────────────────────────────────────

class _SummaryTable extends StatelessWidget {
  final AnalyticsData analytics;
  final String Function(double) formatCurrency;

  const _SummaryTable({
    required this.analytics,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final totalRevenue = analytics.revenueByDay.fold<double>(
      0,
      (sum, d) => sum + d.revenue,
    );
    final totalBookings = analytics.bookingsByCourt.fold<int>(
      0,
      (sum, d) => sum + d.count,
    );
    final totalOrders = analytics.orderCountByDay.fold<int>(
      0,
      (sum, d) => sum + d.count,
    );
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê tổng quan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Tổng doanh thu',
            value: formatCurrency(totalRevenue),
            icon: Icons.attach_money,
            color: AppColors.success,
          ),
          _SummaryRow(
            label: 'Tổng lượt đặt sân',
            value: '$totalBookings lượt',
            icon: Icons.calendar_today,
            color: AppColors.info,
          ),
          _SummaryRow(
            label: 'Tổng đơn đồ ăn',
            value: '$totalOrders đơn',
            icon: Icons.restaurant,
            color: AppColors.warning,
          ),
          _SummaryRow(
            label: 'Giá trị TB / đơn',
            value: formatCurrency(avgOrderValue),
            icon: Icons.analytics,
            color: AppColors.primary,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool showDivider;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}
