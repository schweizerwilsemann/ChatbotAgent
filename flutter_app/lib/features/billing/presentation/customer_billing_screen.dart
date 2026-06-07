import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/realtime_event_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_api.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_provider.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_provider.dart';

final _vndFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

final _billRefreshKeyProvider = StateProvider<int>((ref) => 0);

final _bookingBillProvider =
    FutureProvider.family<BookingBill, String>((ref, bookingId) {
  ref.watch(_billRefreshKeyProvider);
  return ref.watch(bookingApiProvider).getBookingBill(bookingId);
});

class CustomerBillingScreen extends ConsumerStatefulWidget {
  const CustomerBillingScreen({super.key});

  @override
  ConsumerState<CustomerBillingScreen> createState() =>
      _CustomerBillingScreenState();
}

class _CustomerBillingScreenState extends ConsumerState<CustomerBillingScreen> {
  final _bookingScrollController = ScrollController();
  final _orderScrollController = ScrollController();
  StreamSubscription<RealtimeUiEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _bookingScrollController.addListener(_handleBookingScroll);
    _orderScrollController.addListener(_handleOrderScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      final realtimeNotifier = ref.read(realtimeEventProvider.notifier);
      realtimeNotifier.start();
      _realtimeSub = realtimeNotifier.eventStream.listen((event) {
        if (event.type == 'payment_status_changed' ||
            event.type == 'order_changed') {
          debugPrint(
              '[CustomerBilling] Realtime event: ${event.type}, refreshing...');
          ref.read(_billRefreshKeyProvider.notifier).state++;
          _refresh();
        }
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
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
    // Bump refresh key so _bookingBillProvider re-fetches all bills
    ref.read(_billRefreshKeyProvider.notifier).state++;
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
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn đã đặt'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Hóa đơn'),
              Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Đơn lẻ'),
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

  const _BookingBillingList({required this.state, required this.controller});

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
        return _BookingBillCard(booking: booking);
      },
    );
  }
}

class _BookingBillCard extends ConsumerWidget {
  final Booking booking;

  const _BookingBillCard({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(_bookingBillProvider(booking.id));
    return bill.when(
      data: (bill) => _BillCard(bill: bill),
      loading: () => _BillingCard(
        title: booking.resourceLabel ??
            '${booking.courtType.displayName} - Sân ${booking.courtNumber}',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(booking.date)} • ${booking.startTime} - ${booking.endTime}',
        statusLabel: booking.status.displayName,
        paymentStatus: booking.paymentStatus,
        amount: booking.totalPrice,
        icon: Icons.receipt_long_outlined,
      ),
      error: (_, __) => _BillingCard(
        title: booking.resourceLabel ??
            '${booking.courtType.displayName} - Sân ${booking.courtNumber}',
        subtitle:
            '${DateFormat('dd/MM/yyyy').format(booking.date)} • Không thể tải chi tiết bill',
        statusLabel: booking.status.displayName,
        paymentStatus: booking.paymentStatus,
        amount: booking.totalPrice,
        icon: Icons.error_outline,
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final BookingBill bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final booking = bill.booking;
    final title = booking.resourceLabel ??
        '${booking.courtType.displayName} - Sân ${booking.courtNumber}';
    final subtitle =
        '${DateFormat('dd/MM/yyyy').format(booking.date)} • ${booking.startTime} - ${booking.endTime}';

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
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
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
              children: [
                _StatusChip(label: booking.status.displayName),
                _PaymentChip(paymentStatus: booking.paymentStatus),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            _TotalRow(
              label: 'Tiền sân',
              amount: bill.bookingTotal ?? booking.totalPrice ?? 0,
            ),
            if (bill.orders.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Đồ đã gọi', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              ...bill.orders.map((order) {
                final itemSummary = order.items
                    .map((item) => '${item.itemName} x${item.quantity}')
                    .join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemSummary,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (order.isPaid)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _PaidBadge(
                                    method: order.paymentStatus
                                        .replaceFirst('paid_', '')),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _vndFormat.format(order.totalPrice),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              _TotalRow(label: 'Tiền đồ', amount: bill.orderTotal),
            ],
            const Divider(height: AppSpacing.xl),
            _TotalRow(
              label: 'Tổng bill',
              amount: bill.grandTotal,
              isGrandTotal: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _TotalRow(label: 'Đã thanh toán online', amount: bill.paidTotal),
            _TotalRow(
              label: 'Còn cần thanh toán',
              amount: bill.unpaidTotal,
              isGrandTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isGrandTotal;

  const _TotalRow({
    required this.label,
    required this.amount,
    this.isGrandTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          _vndFormat.format(amount),
          style: TextStyle(
            color: isGrandTotal ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderBillingList extends StatelessWidget {
  final OrderHistoryState state;
  final ScrollController controller;

  const _OrderBillingList({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final standaloneOrders =
        state.orders.where((order) => order.bookingId == null).toList();

    if (state.isLoading && standaloneOrders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.error != null && standaloneOrders.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: 'Không thể tải đơn lẻ',
        message: state.error!,
      );
    }
    if (standaloneOrders.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Không có đơn lẻ',
        message:
            'Đơn gọi trong lúc chơi sẽ nằm trong hóa đơn của lượt đặt sân.',
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: standaloneOrders.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= standaloneOrders.length) {
          return const _BottomLoader();
        }
        final order = standaloneOrders[index];
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
              '${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt.toLocal())} • $itemSummary$extraCount',
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
        ? (method.isNotEmpty ? 'Đã thanh toán bằng $method' : 'Đã thanh toán')
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

class _PaidBadge extends StatelessWidget {
  final String method;

  const _PaidBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final label = method.isNotEmpty ? 'Đã TT $method' : 'Đã TT online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 11, color: AppColors.success),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
