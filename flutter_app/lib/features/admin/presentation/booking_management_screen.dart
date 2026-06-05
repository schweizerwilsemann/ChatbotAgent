import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/pagination_footer.dart';

// ─── Court type helpers ─────────────────────────────────────────────────────

String _courtTypeDisplay(String type) {
  switch (type) {
    case 'billiards':
      return 'Billiards';
    case 'pickleball':
      return 'Pickleball';
    case 'badminton':
      return 'Cầu lông';
    default:
      return type;
  }
}

Color _courtTypeColor(String type) {
  switch (type) {
    case 'billiards':
      return AppColors.billiardsColor;
    case 'pickleball':
      return AppColors.pickleballColor;
    case 'badminton':
      return AppColors.badmintonColor;
    default:
      return AppColors.primary;
  }
}

// ─── Status color helper ────────────────────────────────────────────────────

Color _statusColor(AdminBookingStatus status) {
  switch (status) {
    case AdminBookingStatus.pending:
      return AppColors.warning;
    case AdminBookingStatus.confirmed:
      return AppColors.info;
    case AdminBookingStatus.cancelled:
      return AppColors.error;
    case AdminBookingStatus.completed:
      return AppColors.success;
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class BookingManagementScreen extends ConsumerStatefulWidget {
  const BookingManagementScreen({super.key});

  @override
  ConsumerState<BookingManagementScreen> createState() =>
      _BookingManagementScreenState();
}

class _BookingManagementScreenState
    extends ConsumerState<BookingManagementScreen> {
  static const _courtTypes = ['Tất cả', 'Billiards', 'Pickleball', 'Cầu lông'];
  static const _statusOptions = [
    'Tất cả',
    'Chờ xác nhận',
    'Đã xác nhận',
    'Đang chơi',
    'Hoàn thành',
    'Đã huỷ',
  ];

  String? _filterTypeToApi(String display) {
    switch (display) {
      case 'Billiards':
        return 'billiards';
      case 'Pickleball':
        return 'pickleball';
      case 'Cầu lông':
        return 'badminton';
      default:
        return null; // 'Tất cả'
    }
  }

  String? _filterStatusToApi(String display) {
    switch (display) {
      case 'Chờ xác nhận':
        return 'pending';
      case 'Đã xác nhận':
      case 'Đang chơi':
        return 'confirmed';
      case 'Hoàn thành':
        return 'completed';
      case 'Đã huỷ':
        return 'cancelled';
      default:
        return null; // 'Tất cả'
    }
  }

  String _selectedCourtTypeDisplay(BookingManagementState state) {
    if (state.filterType == null) return 'Tất cả';
    return _courtTypeDisplay(state.filterType!);
  }

  String _selectedStatusDisplay(BookingManagementState state) {
    if (state.filterStatus == null) return 'Tất cả';
    switch (state.filterStatus) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return 'Tất cả';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingManagementProvider.notifier).loadBookings();
    });
  }

  // ── Date picker ──────────────────────────────────────────────────────────

  bool get _isToday {
    final d = ref.read(bookingManagementProvider).selectedDate;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _pickDate() async {
    final state = ref.read(bookingManagementProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      ref.read(bookingManagementProvider.notifier).setDate(picked);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _updateStatus(String id, String newStatus) async {
    final notifier = ref.read(bookingManagementProvider.notifier);
    final success = await notifier.updateBookingStatus(id, newStatus);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cập nhật trạng thái thành công'
              : 'Không thể cập nhật trạng thái',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showBookingBill(AdminBooking booking) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bill = await ref.read(adminApiProvider).getBookingBill(booking.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => _BookingBillDialog(bill: bill),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể tải bill của lượt đặt sân này'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  bool _handlePagination(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 360) {
      ref.read(bookingManagementProvider.notifier).loadMoreBookings();
    }
    return false;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingManagementProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Quản lý đặt sân'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Cấu hình giá sân',
            icon: const Icon(Icons.attach_money),
            onPressed: () => context.push('/admin/resource-pricing'),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 900,
        child: Column(
          children: [
            _buildFilters(state),
            const Divider(height: 1),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────────────

  Widget _buildFilters(BookingManagementState state) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Date picker row
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final prev =
                      state.selectedDate.subtract(const Duration(days: 1));
                  ref.read(bookingManagementProvider.notifier).setDate(prev);
                },
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textSecondary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isToday
                              ? 'Hôm nay, ${DateFormat('dd/MM/yyyy').format(state.selectedDate)}'
                              : DateFormat('EEEE, dd/MM/yyyy', 'vi')
                                  .format(state.selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final next = state.selectedDate.add(const Duration(days: 1));
                  ref.read(bookingManagementProvider.notifier).setDate(next);
                },
                icon: const Icon(Icons.chevron_right),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  label: 'Loại sân',
                  value: _selectedCourtTypeDisplay(state),
                  options: _courtTypes,
                  onChanged: (val) {
                    ref
                        .read(bookingManagementProvider.notifier)
                        .setFilterType(_filterTypeToApi(val!));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterDropdown(
                  label: 'Trạng thái',
                  value: _selectedStatusDisplay(state),
                  options: _statusOptions,
                  onChanged: (val) {
                    ref
                        .read(bookingManagementProvider.notifier)
                        .setFilterStatus(_filterStatusToApi(val!));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(BookingManagementState state) {
    if (state.isLoading && state.bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(bookingManagementProvider.notifier).loadBookings();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(bookingManagementProvider.notifier).loadBookings(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handlePagination,
        child: state.bookings.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 56,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Không có đặt sân nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Thử thay đổi ngày hoặc bộ lọc',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.bookings.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == state.bookings.length) {
                    return PaginationFooter(
                      isLoading: state.isLoadingMore,
                      hasMore: state.hasMore,
                    );
                  }
                  return _BookingCard(
                    booking: state.bookings[index],
                    onAction: _updateStatus,
                    onShowBill: _showBookingBill,
                  );
                },
              ),
      ),
    );
  }
}

// ─── Filter Dropdown ────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              items: options.map((o) {
                return DropdownMenuItem(value: o, child: Text(o));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Booking Card ───────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final AdminBooking booking;
  final Future<void> Function(String id, String newStatus) onAction;
  final Future<void> Function(AdminBooking booking) onShowBill;

  const _BookingCard({
    required this.booking,
    required this.onAction,
    required this.onShowBill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: type badge + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _courtTypeColor(booking.courtType)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.resourceLabel ??
                      '${_courtTypeDisplay(booking.courtType)} · Sân ${booking.courtNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _courtTypeColor(booking.courtType),
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _statusColor(booking.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(booking.status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PaymentBadge(paymentStatus: booking.paymentStatus),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Customer info
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.userName.isEmpty ? 'Khách hàng' : booking.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (booking.userPhone != null &&
                  booking.userPhone!.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.phone,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.userPhone!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ── Time row
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${booking.startTime} – ${booking.endTime}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (booking.totalPrice != null) ...[
                const Spacer(),
                const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  NumberFormat.currency(
                    locale: 'vi_VN',
                    symbol: '₫',
                    decimalDigits: 0,
                  ).format(booking.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),

          // ── Notes (if any)
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => onShowBill(booking),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Tính tiền'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // ── Action buttons
          if (booking.status == AdminBookingStatus.pending ||
              booking.status == AdminBookingStatus.confirmed) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!booking.isPaid) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onAction(
                          booking.id, AdminBookingStatus.cancelled.apiValue),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Huỷ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Confirm / Complete button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final newStatus =
                          booking.status == AdminBookingStatus.pending
                              ? AdminBookingStatus.confirmed.apiValue
                              : AdminBookingStatus.completed.apiValue;
                      onAction(booking.id, newStatus);
                    },
                    icon: Icon(
                      booking.status == AdminBookingStatus.pending
                          ? Icons.check_circle_outline
                          : Icons.task_alt,
                      size: 18,
                    ),
                    label: Text(
                      booking.status == AdminBookingStatus.pending
                          ? 'Xác nhận'
                          : 'Hoàn thành',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          booking.status == AdminBookingStatus.pending
                              ? AppColors.success
                              : AppColors.info,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingBillDialog extends StatelessWidget {
  final BookingBill bill;

  const _BookingBillDialog({required this.bill});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final booking = bill.booking;

    return AlertDialog(
      title: const Text('Tính tiền lượt chơi'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.userName.isEmpty ? 'Khách hàng' : booking.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (booking.userPhone != null &&
                  booking.userPhone!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  booking.userPhone!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${booking.resourceLabel ?? _courtTypeDisplay(booking.courtType)} · ${booking.startTime} - ${booking.endTime}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const Divider(height: 24),
              _BillLine(
                label: 'Tiền sân',
                value: bill.bookingTotal == null
                    ? 'Chưa cấu hình'
                    : money.format(bill.bookingTotal),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đồ / dịch vụ trong lượt chơi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (bill.orders.isEmpty)
                const Text(
                  'Chưa có order nào trong khung giờ đặt sân.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...bill.orders.expand(
                  (order) => [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('HH:mm dd/MM').format(order.createdAt),
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _PaymentBadge(paymentStatus: order.paymentStatus),
                        ],
                      ),
                    ),
                    ...order.items.map(
                      (item) => _BillLine(
                        label: '${item.itemName} x${item.quantity}',
                        value: money.format(item.totalPrice),
                      ),
                    ),
                  ],
                ),
              const Divider(height: 24),
              _BillLine(
                label: 'Tổng đồ / dịch vụ',
                value: money.format(bill.orderTotal),
              ),
              const SizedBox(height: 6),
              _BillLine(
                label: bill.bookingTotal == null ? 'Tạm tính' : 'Tổng cần thu',
                value: money.format(bill.grandTotal),
                emphasized: true,
              ),
              if (bill.bookingTotal == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa cộng tiền sân vì booking chưa có giá sân.',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String paymentStatus;

  const _PaymentBadge({required this.paymentStatus});

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _BillLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasized ? AppColors.primary : AppColors.textPrimary,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      fontSize: emphasized ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? AppColors.primary : AppColors.textSecondary,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
