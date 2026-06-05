import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_provider.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_provider.dart';

final _vndFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class CustomerBillingScreen extends ConsumerStatefulWidget {
  const CustomerBillingScreen({super.key});

  @override
  ConsumerState<CustomerBillingScreen> createState() =>
      _CustomerBillingScreenState();
}

class _CustomerBillingScreenState extends ConsumerState<CustomerBillingScreen> {
  final _bookingScrollController = ScrollController();
  final _orderScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bookingScrollController.addListener(_handleBookingScroll);
    _orderScrollController.addListener(_handleOrderScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _bookingScrollController
      ..removeListener(_handleBookingScroll)
      ..dispose();
    _orderScrollController
      ..removeListener(_handleOrderScroll)
      ..dispose();
    super.dispose();
  }

  void _handleBookingScroll() {
    if (!_isNearBottom(_bookingScrollController)) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    ref.read(bookingProvider.notifier).loadMoreBookings(user.id);
  }

  void _handleOrderScroll() {
    if (!_isNearBottom(_orderScrollController)) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    ref.read(orderHistoryProvider.notifier).loadMoreOrders(user.id);
  }

  bool _isNearBottom(ScrollController controller) {
    if (!controller.hasClients) return false;
    final position = controller.position;
    return position.pixels >= position.maxScrollExtent - 220;
  }

  Future<void> _refresh() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await Future.wait([
      ref.read(bookingProvider.notifier).loadBookings(user.id),
      ref.read(orderHistoryProvider.notifier).loadOrders(user.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final bookings = ref.watch(bookingProvider);
    final orderHistory = ref.watch(orderHistoryProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa đăng nhập')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn đã đặt'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sports_tennis_outlined), text: 'Đặt sân'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Đơn hàng'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: TabBarView(
            children: [
              _BookingBillingList(
                state: bookings,
                controller: _bookingScrollController,
              ),
              _OrderBillingList(
                state: orderHistory,
                controller: _orderScrollController,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingBillingList extends StatelessWidget {
  final BookingState state;
  final ScrollController controller;

  const _BookingBillingList({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.bookings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.error != null && state.bookings.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: 'Không thể tải đặt sân',
        message: state.error!,
      );
    }
    if (state.bookings.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Chưa có đặt sân',
        message: 'Các lượt đặt sân của bạn sẽ hiển thị ở đây.',
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.bookings.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.bookings.length) {
          return const _BottomLoader();
        }
        final booking = state.bookings[index];
        return _BillingCard(
          title: booking.resourceLabel ??
              '${booking.courtType.displayName} - Sân ${booking.courtNumber}',
          subtitle:
              '${DateFormat('dd/MM/yyyy').format(booking.date)} • ${booking.startTime} - ${booking.endTime}',
          statusLabel: booking.status.displayName,
          paymentStatus: booking.paymentStatus,
          amount: booking.totalPrice,
          icon: Icons.sports_tennis_outlined,
        );
      },
    );
  }
}

class _OrderBillingList extends StatelessWidget {
  final OrderHistoryState state;
  final ScrollController controller;

  const _OrderBillingList({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.error != null && state.orders.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: 'Không thể tải đơn hàng',
        message: state.error!,
      );
    }
    if (state.orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hàng',
        message: 'Các sản phẩm và dịch vụ bạn đã đặt sẽ hiển thị ở đây.',
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.orders.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.orders.length) {
          return const _BottomLoader();
        }
        final order = state.orders[index];
        final itemSummary = order.items
            .take(3)
            .map((item) => '${item.itemName} x${item.quantity}')
            .join(', ');
        final extraCount = order.items.length > 3
            ? ' +${order.items.length - 3} sản phẩm'
            : '';
        return _BillingCard(
          title: order.resourceLabel != null
              ? 'Đơn tại ${order.resourceLabel}'
              : 'Đơn hàng ${order.items.length} sản phẩm',
          subtitle:
              '${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)} • $itemSummary$extraCount',
          statusLabel: order.status.displayName,
          paymentStatus: order.paymentStatus,
          amount: order.totalPrice,
          icon: Icons.shopping_bag_outlined,
        );
      },
    );
  }
}

class _BottomLoader extends StatelessWidget {
  const _BottomLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _BillingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusLabel;
  final String paymentStatus;
  final double? amount;
  final IconData icon;

  const _BillingCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.paymentStatus,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(label: statusLabel),
                _PaymentChip(paymentStatus: paymentStatus),
                if (amount != null && amount! > 0)
                  Text(
                    _vndFormat.format(amount),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String paymentStatus;

  const _PaymentChip({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    final isPaid = paymentStatus.startsWith('paid');
    final isFailed = paymentStatus == 'failed';
    final color = isPaid
        ? AppColors.success
        : isFailed
            ? AppColors.error
            : AppColors.textHint;
    final method = isPaid && paymentStatus.contains('_')
        ? paymentStatus.split('_').last.toUpperCase()
        : '';
    final label = isPaid
        ? (method.isNotEmpty ? 'Đã thanh toán ($method)' : 'Đã thanh toán')
        : isFailed
            ? 'Thanh toán lỗi'
            : 'Chưa thanh toán';

    return Chip(
      avatar: Icon(
        isPaid ? Icons.verified_outlined : Icons.payments_outlined,
        size: 16,
        color: color,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(icon, size: 56, color: AppColors.textHint),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
