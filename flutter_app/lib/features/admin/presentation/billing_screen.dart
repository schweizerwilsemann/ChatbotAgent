import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/billing_provider.dart';

/// Screen for admin/staff to view billing and transactions.
///
/// Features:
/// - Summary cards (today's revenue, total orders, average order value)
/// - Transaction list with status filters
/// - Pull-to-refresh
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billingProvider.notifier).loadOrders();
    });
  }

  Future<void> _updateOrderStatus(
    BuildContext context,
    String orderId,
    String newStatus,
  ) async {
    final statusLabel = {
          'preparing': 'Chuẩn bị',
          'ready': 'Sẵn sàng',
          'delivered': 'Đã giao',
          'cancelled': 'Huỷ',
        }[newStatus] ??
        newStatus;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Text('Đánh dấu đơn hàng "$statusLabel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(billingProvider.notifier)
          .updateOrderStatus(orderId, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Đã cập nhật trạng thái: $statusLabel'
                  : 'Cập nhật thất bại',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingProvider);

    return Column(
      children: [
        // ── Summary cards ───────────────────────────────────────
        _buildSummary(state.orders),

        // ── Filter ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: ResponsiveContainer(
            maxWidth: 900,
            child: Row(
              children: [
                const Text(
                  'Lịch sử giao dịch',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: state.filterStatus,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Tất cả'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Chờ xử lý'),
                        ),
                        DropdownMenuItem(
                          value: 'preparing',
                          child: Text('Đang chuẩn bị'),
                        ),
                        DropdownMenuItem(
                          value: 'ready',
                          child: Text('Sẵn sàng'),
                        ),
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('Đã giao'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Đã hủy'),
                        ),
                      ],
                      onChanged: (v) {
                        ref.read(billingProvider.notifier).setFilterStatus(v);
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
          ),
        ),

        // ── Error banner ────────────────────────────────────────
        if (state.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.error.withOpacity(0.08),
            child: ResponsiveContainer(
              maxWidth: 900,
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.error,
                    onPressed: () {
                      ref.read(billingProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),
          ),

        // ── Transactions list ───────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(billingProvider.notifier).loadOrders(),
            child: _buildTransactionsList(context, state),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<AdminOrder> orders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayOrders = orders.where((o) => o.createdAt.isAfter(todayStart));
    final todayRevenue = todayOrders
        .where((o) =>
            o.status == AdminOrderStatus.delivered ||
            o.status == AdminOrderStatus.ready)
        .fold<double>(0, (sum, o) => sum + o.totalPrice);

    final totalOrders = orders.length;
    final avgOrder = totalOrders > 0
        ? orders.fold<double>(0, (sum, o) => sum + o.totalPrice) / totalOrders
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: AppColors.surface,
      child: ResponsiveContainer(
        maxWidth: 900,
        child: Row(
          children: [
            Expanded(
              child: _SummaryMiniCard(
                label: 'Doanh thu hôm nay',
                value: '${_currencyFormat.format(todayRevenue.round())}đ',
                icon: Icons.attach_money,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryMiniCard(
                label: 'Tổng đơn',
                value: '$totalOrders',
                icon: Icons.receipt,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryMiniCard(
                label: 'TB / đơn',
                value: '${_currencyFormat.format(avgOrder.round())}đ',
                icon: Icons.trending_up,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, BillingState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply client-side filter if a status filter is set
    final orders = state.filterStatus == null
        ? state.orders
        : state.orders
            .where((o) => o.status.name == state.filterStatus)
            .toList();

    if (orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có giao dịch nào',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
      itemCount: orders.length,
      itemBuilder: (context, index) => ResponsiveContainer(
        maxWidth: 900,
        child: _OrderCard(
          order: orders[index],
          currencyFormat: _currencyFormat,
          onStatusUpdate: (newStatus) => _updateOrderStatus(
            context,
            orders[index].id,
            newStatus,
          ),
        ),
      ),
    );
  }
}

// ─── Summary mini card ──────────────────────────────────────────────────────

class _SummaryMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Order card ─────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final AdminOrder order;
  final NumberFormat currencyFormat;
  final void Function(String newStatus)? onStatusUpdate;

  const _OrderCard({
    required this.order,
    required this.currencyFormat,
    this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('HH:mm • dd/MM').format(order.createdAt);

    final shortId = order.id.length > 8
        ? '#${order.id.substring(order.id.length - 8)}'
        : '#${order.id}';

    final itemsDescription = order.items
        .map((item) => '${item.quantity}x ${item.itemName}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: status badge, order id, time
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.displayName,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  shortId,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer userId
            Row(
              children: [
                const Icon(Icons.person,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  order.userId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (order.tableNumber > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.table_restaurant,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'Bàn ${order.tableNumber}',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Items description
            if (itemsDescription.isNotEmpty)
              Text(
                itemsDescription,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),

            // Notes
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${order.notes}',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            // Total price
            Row(
              children: [
                Text(
                  '${currencyFormat.format(order.totalPrice.round())}đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.items.length} món',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // ── Action buttons ─────────────────────────────────
            ..._buildActionButtons(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final buttons = <Widget>[];

    switch (order.status) {
      case AdminOrderStatus.pending:
        buttons.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => onStatusUpdate?.call('cancelled'),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Huỷ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => onStatusUpdate?.call('preparing'),
                icon: const Icon(Icons.kitchen, size: 16),
                label: const Text('Chuẩn bị'),
              ),
            ],
          ),
        );
        break;
      case AdminOrderStatus.preparing:
        buttons.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => onStatusUpdate?.call('cancelled'),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Huỷ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => onStatusUpdate?.call('ready'),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Sẵn sàng'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
            ],
          ),
        );
        break;
      case AdminOrderStatus.ready:
        buttons.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () => onStatusUpdate?.call('delivered'),
                icon: const Icon(Icons.delivery_dining, size: 16),
                label: const Text('Đã giao'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
            ],
          ),
        );
        break;
      case AdminOrderStatus.delivered:
      case AdminOrderStatus.cancelled:
        // Terminal states — no actions
        break;
    }

    if (buttons.isNotEmpty) {
      return [const Divider(height: 20), buttons.first];
    }
    return [];
  }

  Color get _statusColor {
    switch (order.status) {
      case AdminOrderStatus.pending:
        return AppColors.warning;
      case AdminOrderStatus.preparing:
        return AppColors.info;
      case AdminOrderStatus.ready:
        return AppColors.success;
      case AdminOrderStatus.delivered:
        return AppColors.success;
      case AdminOrderStatus.cancelled:
        return AppColors.error;
    }
  }
}
