import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_models.dart';
import 'package:sports_venue_chatbot/features/partner/presentation/partner_order_provider.dart';

class PartnerOrderManagementScreen extends ConsumerStatefulWidget {
  const PartnerOrderManagementScreen({super.key});

  @override
  ConsumerState<PartnerOrderManagementScreen> createState() =>
      _PartnerOrderManagementScreenState();
}

class _PartnerOrderManagementScreenState
    extends ConsumerState<PartnerOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statusTabs = [
    (label: 'Tất cả', status: null),
    (label: 'Chờ xử lý', status: 'pending'),
    (label: 'Đang xử lý', status: 'accepted'),
    (label: 'Sẵn sàng', status: 'ready'),
    (label: 'Hoàn thành', status: 'delivered'),
    (label: 'Đã huỷ', status: 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(partnerOrderProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = _statusTabs[_tabController.index];
    ref.read(partnerOrderProvider.notifier).loadOrders(
          status: tab.status,
          clearStatus: tab.status == null,
        );
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(price.round())}đ';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('HH:mm - dd/MM').format(dt);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleStatusUpdate(
    PartnerOrder order,
    PartnerOrderStatus newStatus,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Text(
          'Chuyển đơn hàng sang "${newStatus.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(partnerOrderProvider.notifier)
          .updateOrderStatus(order.id, newStatus);
    }
  }

  void _showOrderDetail(PartnerOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OrderDetailSheet(
        order: order,
        formatPrice: _formatPrice,
        formatTime: _formatTime,
        onStatusUpdate: (newStatus) {
          Navigator.pop(ctx);
          _handleStatusUpdate(order, newStatus);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerOrderProvider);

    ref.listen<PartnerOrderState>(partnerOrderProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        _showSnackBar(next.successMessage!);
        ref.read(partnerOrderProvider.notifier).clearSuccess();
      }
      if (next.error != null && next.error != prev?.error) {
        _showSnackBar(next.error!, isError: true);
        ref.read(partnerOrderProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFE67E22),
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: const Color(0xFFE67E22),
          tabs: _statusTabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: state.isLoading && state.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(partnerOrderProvider.notifier).loadOrders(
                        status: _statusTabs[_tabController.index].status,
                        clearStatus:
                            _statusTabs[_tabController.index].status == null,
                      ),
              child: state.orders.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long,
                                  size: 64,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'Chưa có đơn hàng nào',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.orders.length,
                      itemBuilder: (ctx, i) {
                        return _PartnerOrderCard(
                          order: state.orders[i],
                          formatPrice: _formatPrice,
                          formatTime: _formatTime,
                          onTap: () => _showOrderDetail(state.orders[i]),
                          onStatusUpdate: (newStatus) => _handleStatusUpdate(
                            state.orders[i],
                            newStatus,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─── Order Card ─────────────────────────────────────────────────────────────

class _PartnerOrderCard extends StatelessWidget {
  final PartnerOrder order;
  final String Function(double) formatPrice;
  final String Function(DateTime?) formatTime;
  final VoidCallback onTap;
  final void Function(PartnerOrderStatus) onStatusUpdate;

  const _PartnerOrderCard({
    required this.order,
    required this.formatPrice,
    required this.formatTime,
    required this.onTap,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardBackground,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: customer + status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName ?? 'Khách hàng',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (order.customerPhone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.customerPhone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: order.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: order.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Items summary
              ...order.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.itemName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatPrice(item.totalPrice),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (order.items.length > 3)
                Text(
                  '... và ${order.items.length - 3} món khác',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const Divider(height: 16),

              // Footer: total + time + delivery
              Row(
                children: [
                  Text(
                    formatPrice(order.totalPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE67E22),
                    ),
                  ),
                  const Spacer(),
                  if (order.deliveryLocation != null) ...[
                    const Icon(Icons.location_on,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order.deliveryLocation!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    formatTime(order.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),

              // Quick action buttons for pending/accepted/preparing
              if (order.status.validNextTransitions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    ...order.status.validNextTransitions.map(
                      (nextStatus) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () => onStatusUpdate(nextStatus),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: nextStatus.color,
                            side: BorderSide(
                              color: nextStatus.color.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            nextStatus == PartnerOrderStatus.cancelled
                                ? 'Huỷ đơn'
                                : nextStatus.displayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Order Detail Sheet ─────────────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final PartnerOrder order;
  final String Function(double) formatPrice;
  final String Function(DateTime?) formatTime;
  final void Function(PartnerOrderStatus) onStatusUpdate;

  const _OrderDetailSheet({
    required this.order,
    required this.formatPrice,
    required this.formatTime,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Order ID + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đơn #${order.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: order.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: order.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Customer info
              _DetailSection(
                title: 'Khách hàng',
                children: [
                  _DetailRow(
                    label: 'Tên',
                    value: order.customerName ?? 'N/A',
                  ),
                  if (order.customerPhone != null)
                    _DetailRow(label: 'SĐT', value: order.customerPhone!),
                  if (order.deliveryLocation != null)
                    _DetailRow(
                      label: 'Giao đến',
                      value: order.deliveryLocation!,
                    ),
                ],
              ),

              // Items
              _DetailSection(
                title: 'Chi tiết đơn (${order.items.length} món)',
                children: order.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.itemName)),
                            Text(formatPrice(item.totalPrice)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),

              // Totals
              _DetailSection(
                title: 'Thanh toán',
                children: [
                  _DetailRow(
                    label: 'Tạm tính',
                    value: formatPrice(order.subtotal),
                  ),
                  _DetailRow(
                    label: 'Phí giao hàng',
                    value: formatPrice(order.deliveryFee),
                  ),
                  const Divider(),
                  _DetailRow(
                    label: 'Tổng cộng',
                    value: formatPrice(order.totalPrice),
                    isBold: true,
                  ),
                  _DetailRow(
                    label: 'Trạng thái',
                    value: order.paymentStatus == 'paid'
                        ? 'Đã thanh toán'
                        : 'Chưa thanh toán',
                  ),
                ],
              ),

              // Notes
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                _DetailSection(
                  title: 'Ghi chú',
                  children: [Text(order.notes!)],
                ),
              ],

              // Time
              _DetailSection(
                title: 'Thời gian',
                children: [
                  _DetailRow(
                    label: 'Đặt lúc',
                    value: formatTime(order.createdAt),
                  ),
                ],
              ),

              // Action buttons
              if (order.status.validNextTransitions.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...order.status.validNextTransitions.map(
                  (nextStatus) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onStatusUpdate(nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              nextStatus == PartnerOrderStatus.cancelled
                                  ? AppColors.error
                                  : nextStatus.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          nextStatus == PartnerOrderStatus.cancelled
                              ? 'Huỷ đơn'
                              : 'Chuyển sang: ${nextStatus.displayName}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold ? const Color(0xFFE67E22) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
