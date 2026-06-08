import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/realtime_event_provider.dart';

// ─── Staff Billing Provider ──────────────────────────────────────────────────

class StaffBillingState {
  final List<AdminBooking> bookings;
  final Map<String, List<AdminOrder>> ordersByBooking;
  final List<AdminOrder> standaloneOrders;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;
  final String? filterStatus;

  const StaffBillingState({
    this.bookings = const [],
    this.ordersByBooking = const {},
    this.standaloneOrders = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
    this.filterStatus,
  });

  StaffBillingState copyWith({
    List<AdminBooking>? bookings,
    Map<String, List<AdminOrder>>? ordersByBooking,
    List<AdminOrder>? standaloneOrders,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
    String? filterStatus,
    bool clearError = false,
    bool clearFilter = false,
  }) {
    return StaffBillingState(
      bookings: bookings ?? this.bookings,
      ordersByBooking: ordersByBooking ?? this.ordersByBooking,
      standaloneOrders: standaloneOrders ?? this.standaloneOrders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  List<AdminBooking> get filteredBookings {
    if (filterStatus == null) return bookings;
    return bookings.where((booking) {
      final orders = ordersByBooking[booking.id] ?? [];
      return orders.any((o) => o.status.apiValue == filterStatus);
    }).toList();
  }

  List<AdminOrder> get filteredStandaloneOrders {
    if (filterStatus == null) return standaloneOrders;
    return standaloneOrders
        .where((o) => o.status.apiValue == filterStatus)
        .toList();
  }
}

class StaffBillingNotifier extends StateNotifier<StaffBillingState> {
  final AdminApi _adminApi;

  StaffBillingNotifier(this._adminApi)
      : super(StaffBillingState(selectedDate: DateTime.now()));

  Future<void> loadBillingData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dateStr = '${state.selectedDate.year.toString().padLeft(4, '0')}-'
          '${state.selectedDate.month.toString().padLeft(2, '0')}-'
          '${state.selectedDate.day.toString().padLeft(2, '0')}';

      // Load bookings for the day
      final bookings = await _adminApi.getBookings(
        date: dateStr,
        limit: 50,
        offset: 0,
      );

      // Load orders for each booking
      final ordersByBooking = <String, List<AdminOrder>>{};
      for (final booking in bookings) {
        try {
          final bill = await _adminApi.getBookingBill(booking.id);
          if (bill.orders.isNotEmpty) {
            ordersByBooking[booking.id] = bill.orders;
          }
        } catch (_) {
          // Skip if bill fetch fails
        }
      }

      // Load standalone orders (not linked to any booking)
      List<AdminOrder> standaloneOrders = [];
      try {
        standaloneOrders = await _adminApi.getStaffOrders(
          status: state.filterStatus,
          limit: 100,
          offset: 0,
        );
        // Filter to only show orders without a booking_id
        standaloneOrders =
            standaloneOrders.where((o) => o.bookingId == null).toList();
      } catch (_) {
        // Skip if standalone orders fetch fails
      }

      state = state.copyWith(
        bookings: bookings,
        ordersByBooking: ordersByBooking,
        standaloneOrders: standaloneOrders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải dữ liệu hoá đơn.',
      );
    }
  }

  Future<void> setDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await loadBillingData();
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final updated = await _adminApi.updateOrderStatus(orderId, newStatus);

      // Update in ordersByBooking
      final newOrdersByBooking = <String, List<AdminOrder>>{};
      for (final entry in state.ordersByBooking.entries) {
        newOrdersByBooking[entry.key] = entry.value.map((o) {
          return o.id == orderId ? updated : o;
        }).toList();
      }

      // Update in standaloneOrders
      final newStandaloneOrders = state.standaloneOrders.map((o) {
        return o.id == orderId ? updated : o;
      }).toList();

      state = state.copyWith(
        ordersByBooking: newOrdersByBooking,
        standaloneOrders: newStandaloneOrders,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void setFilterStatus(String? status) {
    state = state.copyWith(
      filterStatus: status,
      clearFilter: status == null,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final staffBillingProvider =
    StateNotifierProvider<StaffBillingNotifier, StaffBillingState>((ref) {
  return StaffBillingNotifier(ref.watch(adminApiProvider));
});

// ─── Staff Billing Screen ────────────────────────────────────────────────────

class StaffBillingScreen extends ConsumerStatefulWidget {
  const StaffBillingScreen({super.key});

  @override
  ConsumerState<StaffBillingScreen> createState() => _StaffBillingScreenState();
}

class _StaffBillingScreenState extends ConsumerState<StaffBillingScreen>
    with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');
  StreamSubscription<RealtimeUiEvent>? _realtimeSub;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffBillingProvider.notifier).loadBillingData();
      final realtimeNotifier = ref.read(realtimeEventProvider.notifier);
      realtimeNotifier.start();
      _realtimeSub = realtimeNotifier.eventStream.listen((event) {
        if (event.type == 'order_changed' ||
            event.type == 'payment_status_changed') {
          debugPrint(
              '[StaffBilling] Realtime event: ${event.type}, refreshing...');
          ref.read(staffBillingProvider.notifier).loadBillingData();
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final state = ref.read(staffBillingProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      ref.read(staffBillingProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffBillingProvider);

    return Column(
      children: [
        // ── Header with date picker ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: AppColors.primary, size: 22),
               const SizedBox(width: 8),
               const Flexible(
                 child: Text(
                   'Quản lý hoá đơn',
                   style: TextStyle(
                     fontWeight: FontWeight.w700,
                     fontSize: 16,
                   ),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
              const Spacer(),
              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy').format(state.selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () =>
                    ref.read(staffBillingProvider.notifier).loadBillingData(),
              ),
            ],
          ),
        ),

        // ── Error banner ────────────────────────────────────────
        if (state.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.error.withValues(alpha: 0.08),
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
                  onPressed: () =>
                      ref.read(staffBillingProvider.notifier).clearError(),
                ),
              ],
            ),
          ),

        // ── Tab bar + Filter ────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month, size: 16),
                        const SizedBox(width: 6),
                        Text('Đơn đặt sân (${state.filteredBookings.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                            'Đơn lẻ (${state.filteredStandaloneOrders.length})'),
                      ],
                    ),
                  ),
                ],
              ),
              // Filter row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Lọc trạng thái:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(null, 'Tất cả', state),
                            _buildFilterChip('pending', 'Chờ xử lý', state),
                            _buildFilterChip(
                                'preparing', 'Đang chuẩn bị', state),
                            _buildFilterChip('ready', 'Sẵn sàng', state),
                            _buildFilterChip('delivered', 'Đã giao', state),
                            _buildFilterChip('cancelled', 'Đã hủy', state),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Content ─────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Booking orders
                    _buildBookingOrdersTab(state),
                    // Tab 2: Standalone orders
                    _buildStandaloneOrdersTab(state),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
      String? status, String label, StaffBillingState state) {
    final isSelected = state.filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          ref.read(staffBillingProvider.notifier).setFilterStatus(status);
        },
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        checkmarkColor: AppColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildBookingOrdersTab(StaffBillingState state) {
    final filteredBookings = state.filteredBookings;

    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.filterStatus != null
                  ? Icons.filter_list_off
                  : Icons.calendar_month_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              state.filterStatus != null
                  ? 'Không có đơn nào ở trạng thái này'
                  : 'Không có đặt sân nào trong ngày',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(staffBillingProvider.notifier).loadBillingData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          final orders = state.ordersByBooking[booking.id] ?? [];
          return _BookingBillCard(
            booking: booking,
            orders: orders,
            currencyFormat: _currencyFormat,
            onOrderStatusUpdate: (orderId, newStatus) async {
              final success = await ref
                  .read(staffBillingProvider.notifier)
                  .updateOrderStatus(orderId, newStatus);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật trạng thái'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildStandaloneOrdersTab(StaffBillingState state) {
    final filteredOrders = state.filteredStandaloneOrders;

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.filterStatus != null
                  ? Icons.filter_list_off
                  : Icons.shopping_bag_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              state.filterStatus != null
                  ? 'Không có đơn nào ở trạng thái này'
                  : 'Không có đơn lẻ nào',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(staffBillingProvider.notifier).loadBillingData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _StandaloneOrderCard(
            order: order,
            currencyFormat: _currencyFormat,
            onOrderStatusUpdate: (orderId, newStatus) async {
              final success = await ref
                  .read(staffBillingProvider.notifier)
                  .updateOrderStatus(orderId, newStatus);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật trạng thái'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ─── Booking Bill Card ───────────────────────────────────────────────────────

class _BookingBillCard extends StatelessWidget {
  final AdminBooking booking;
  final List<AdminOrder> orders;
  final NumberFormat currencyFormat;
  final Function(String orderId, String newStatus) onOrderStatusUpdate;

  const _BookingBillCard({
    required this.booking,
    required this.orders,
    required this.currencyFormat,
    required this.onOrderStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final courtTotal = booking.totalPrice ?? 0;
    final isCourtPaid = booking.paymentStatus != 'unpaid';

    final unpaidOrders =
        orders.where((o) => o.paymentStatus == 'unpaid').toList();
    final paidOrders =
        orders.where((o) => o.paymentStatus != 'unpaid').toList();

    final unpaidOrdersTotal =
        unpaidOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final paidOrdersTotal =
        paidOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);

    final totalPaid = (isCourtPaid ? courtTotal : 0) + paidOrdersTotal;
    final totalUnpaid = (isCourtPaid ? 0 : courtTotal) + unpaidOrdersTotal;
    final grandTotal = courtTotal + paidOrdersTotal + unpaidOrdersTotal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: _buildStatusIcon(),
        title: Text(
          booking.resourceLabel ?? 'Sân ${booking.courtNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${booking.userName} · ${booking.startTime} - ${booking.endTime}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildBadge(
                  _statusLabel(booking.status),
                  _statusColor(booking.status),
                ),
                const SizedBox(width: 6),
                _buildBadge(
                  _paymentLabel(booking.paymentStatus),
                  _paymentColor(booking.paymentStatus),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${currencyFormat.format(grandTotal.round())}đ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            if (totalUnpaid > 0)
              Text(
                'Cần thu: ${currencyFormat.format(totalUnpaid.round())}đ',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                  SizedBox(width: 3),
                  Text(
                    'Đã thanh toán',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        children: [
          const Divider(height: 1),

          // ── Unpaid items (cần thanh toán) ──────────────────────
          if (totalUnpaid > 0) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.payment, size: 16, color: AppColors.error),
                  SizedBox(width: 6),
                  Text(
                    'Cần thanh toán',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            // Unpaid court fee
            if (!isCourtPaid)
              _buildBillRow(
                'Tiền sân',
                '${currencyFormat.format(courtTotal.round())}đ',
                false,
              ),
            // Unpaid orders
            for (final order in unpaidOrders) _buildOrderSection(order),
            // Unpaid total
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cần thu',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    '${currencyFormat.format(totalUnpaid.round())}đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Paid items (đã thanh toán online) ──────────────────
          if (totalPaid > 0) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Đã thanh toán online',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            // Paid court fee
            if (isCourtPaid)
              _buildBillRow(
                'Tiền sân',
                '${currencyFormat.format(courtTotal.round())}đ',
                true,
              ),
            // Paid orders
            for (final order in paidOrders) _buildOrderSection(order),
          ],

          // ── Summary ───────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _summaryRow('Tổng bill',
                    '${currencyFormat.format(grandTotal.round())}đ'),
                _summaryRow(
                  'Đã thanh toán online',
                  '${currencyFormat.format(totalPaid.round())}đ',
                  color: AppColors.success,
                ),
                const Divider(height: 8),
                _summaryRow(
                  'Cần thu tại quầy',
                  '${currencyFormat.format(totalUnpaid.round())}đ',
                  color: totalUnpaid > 0 ? AppColors.error : AppColors.success,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = _statusColor(booking.status);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _statusIcon(booking.status),
        color: color,
        size: 18,
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String amount, bool isPaid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isPaid ? AppColors.success : AppColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isPaid ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: isPaid ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isPaid ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(AdminOrder order) {
    final isPaid = order.paymentStatus != 'unpaid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đơn #${order.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              _buildBadge(
                _orderStatusLabel(order.status),
                _orderStatusColor(order.status),
              ),
              const SizedBox(width: 4),
              _buildBadge(
                _paymentLabel(order.paymentStatus),
                _paymentColor(order.paymentStatus),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    '${item.quantity}x ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${currencyFormat.format((item.unitPrice * item.quantity).round())}đ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 8),
          Row(
            children: [
              const Spacer(),
              Text(
                '${currencyFormat.format(order.totalPrice.round())}đ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPaid ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          // Order status action buttons
          if (order.status != AdminOrderStatus.delivered &&
              order.status != AdminOrderStatus.cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.status == AdminOrderStatus.pending)
                    _buildActionButton(
                      'Chuẩn bị',
                      Icons.restaurant,
                      () => onOrderStatusUpdate(order.id, 'preparing'),
                    ),
                  if (order.status == AdminOrderStatus.preparing)
                    _buildActionButton(
                      'Sẵn sàng',
                      Icons.check_circle_outline,
                      () => onOrderStatusUpdate(order.id, 'ready'),
                    ),
                  if (order.status == AdminOrderStatus.ready)
                    _buildActionButton(
                      'Đã giao',
                      Icons.delivery_dining,
                      () => onOrderStatusUpdate(order.id, 'delivered'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _statusLabel(AdminBookingStatus status) {
    switch (status) {
      case AdminBookingStatus.pending:
        return 'Chờ xác nhận';
      case AdminBookingStatus.confirmed:
        return 'Đã xác nhận';
      case AdminBookingStatus.checkedIn:
        return 'Đã nhận sân';
      case AdminBookingStatus.completed:
        return 'Hoàn thành';
      case AdminBookingStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  Color _statusColor(AdminBookingStatus status) {
    switch (status) {
      case AdminBookingStatus.pending:
        return AppColors.warning;
      case AdminBookingStatus.confirmed:
        return AppColors.info;
      case AdminBookingStatus.checkedIn:
        return AppColors.success;
      case AdminBookingStatus.completed:
        return AppColors.success;
      case AdminBookingStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _statusIcon(AdminBookingStatus status) {
    switch (status) {
      case AdminBookingStatus.pending:
        return Icons.schedule;
      case AdminBookingStatus.confirmed:
        return Icons.check_circle_outline;
      case AdminBookingStatus.checkedIn:
        return Icons.login;
      case AdminBookingStatus.completed:
        return Icons.check_circle;
      case AdminBookingStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid_stripe':
        return 'Stripe';
      case 'paid_vnpay':
        return 'VNPay';
      case 'unpaid':
        return 'Chưa TT';
      default:
        return status;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid_stripe':
      case 'paid_vnpay':
        return AppColors.success;
      case 'unpaid':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _orderStatusLabel(AdminOrderStatus status) {
    switch (status) {
      case AdminOrderStatus.pending:
        return 'Chờ xử lý';
      case AdminOrderStatus.preparing:
        return 'Đang chuẩn bị';
      case AdminOrderStatus.ready:
        return 'Sẵn sàng';
      case AdminOrderStatus.delivered:
        return 'Đã giao';
      case AdminOrderStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  Color _orderStatusColor(AdminOrderStatus status) {
    switch (status) {
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

// ─── Standalone Order Card ──────────────────────────────────────────────────

class _StandaloneOrderCard extends StatelessWidget {
  final AdminOrder order;
  final NumberFormat currencyFormat;
  final Function(String orderId, String newStatus) onOrderStatusUpdate;

  const _StandaloneOrderCard({
    required this.order,
    required this.currencyFormat,
    required this.onOrderStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = order.paymentStatus != 'unpaid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                _buildBadge(
                  _orderStatusLabel(order.status),
                  _orderStatusColor(order.status),
                ),
                const SizedBox(width: 4),
                _buildBadge(
                  _paymentLabel(order.paymentStatus),
                  _paymentColor(order.paymentStatus),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity}x ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${currencyFormat.format((item.unitPrice * item.quantity).round())}đ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 8),
            Row(
              children: [
                const Spacer(),
                Text(
                  '${currencyFormat.format(order.totalPrice.round())}đ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
            if (order.status != AdminOrderStatus.delivered &&
                order.status != AdminOrderStatus.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (order.status == AdminOrderStatus.pending)
                      _buildActionButton(
                        'Chuẩn bị',
                        Icons.restaurant,
                        () => onOrderStatusUpdate(order.id, 'preparing'),
                      ),
                    if (order.status == AdminOrderStatus.preparing)
                      _buildActionButton(
                        'Sẵn sàng',
                        Icons.check_circle_outline,
                        () => onOrderStatusUpdate(order.id, 'ready'),
                      ),
                    if (order.status == AdminOrderStatus.ready)
                      _buildActionButton(
                        'Đã giao',
                        Icons.delivery_dining,
                        () => onOrderStatusUpdate(order.id, 'delivered'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid_stripe':
        return 'Stripe';
      case 'paid_vnpay':
        return 'VNPay';
      case 'unpaid':
        return 'Chưa TT';
      default:
        return status;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid_stripe':
      case 'paid_vnpay':
        return AppColors.success;
      case 'unpaid':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _orderStatusLabel(AdminOrderStatus status) {
    switch (status) {
      case AdminOrderStatus.pending:
        return 'Chờ xử lý';
      case AdminOrderStatus.preparing:
        return 'Đang chuẩn bị';
      case AdminOrderStatus.ready:
        return 'Sẵn sàng';
      case AdminOrderStatus.delivered:
        return 'Đã giao';
      case AdminOrderStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  Color _orderStatusColor(AdminOrderStatus status) {
    switch (status) {
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
