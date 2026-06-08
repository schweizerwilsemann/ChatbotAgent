import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_provider.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/realtime_event_provider.dart';
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
    case AdminBookingStatus.checkedIn:
      return AppColors.success;
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
    'Đã nhận sân',
    'Hoàn thành',
    'Đã huỷ',
  ];

  StreamSubscription<RealtimeUiEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingManagementProvider.notifier).loadBookings();
      final realtimeNotifier = ref.read(realtimeEventProvider.notifier);
      realtimeNotifier.start();
      _realtimeSub = realtimeNotifier.eventStream.listen((event) {
        if (event.type == 'court_status_changed' ||
            event.type == 'order_changed' ||
            event.type == 'payment_status_changed') {
          debugPrint(
              '[BookingMgmt] Realtime event: ${event.type}, refreshing...');
          ref.read(bookingManagementProvider.notifier).loadBookings();
        }
      });
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

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
        return 'confirmed';
      case 'Đã nhận sân':
        return 'checked_in';
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
      case 'checked_in':
        return 'Đã nhận sân';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return 'Tất cả';
    }
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

  Future<void> _checkIn(AdminBooking booking) async {
    final success = await ref
        .read(bookingManagementProvider.notifier)
        .checkInBooking(booking.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã xác nhận khách nhận sân'
              : 'Không thể xác nhận nhận sân',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showCheckInQr(AdminBooking booking) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await ref
          .read(adminApiProvider)
          .createBookingCheckInToken(booking.id);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => _CheckInQrDialog(token: token),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể tạo mã QR nhận sân'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _showReschedule(AdminBooking booking) async {
    final result = await showDialog<_RescheduleResult>(
      context: context,
      builder: (_) => _RescheduleDialog(booking: booking),
    );
    if (result == null) return;

    final success =
        await ref.read(bookingManagementProvider.notifier).rescheduleBooking(
              id: booking.id,
              date: result.date,
              startTime: result.startTime,
              endTime: result.endTime,
            );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã đổi giờ đặt sân' : 'Không thể đổi giờ'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
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
                    onCheckIn: _checkIn,
                    onShowQr: _showCheckInQr,
                    onReschedule: _showReschedule,
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
  final Future<void> Function(AdminBooking booking) onCheckIn;
  final Future<void> Function(AdminBooking booking) onShowQr;
  final Future<void> Function(AdminBooking booking) onReschedule;

  const _BookingCard({
    required this.booking,
    required this.onAction,
    required this.onShowBill,
    required this.onCheckIn,
    required this.onShowQr,
    required this.onReschedule,
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
              Flexible(
                child: Container(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _courtTypeColor(booking.courtType),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                Flexible(
                  child: Text(
                    booking.userPhone!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
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
              Flexible(
                child: Text(
                  '${booking.startTime} – ${booking.endTime}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (booking.totalPrice != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
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
                    overflow: TextOverflow.ellipsis,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => onShowBill(booking),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Tính tiền'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              if (booking.status == AdminBookingStatus.confirmed)
                OutlinedButton.icon(
                  onPressed: () => onReschedule(booking),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Đổi giờ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              if (booking.status == AdminBookingStatus.confirmed)
                OutlinedButton.icon(
                  onPressed: () => onShowQr(booking),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Mã QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
            ],
          ),

          // ── Action buttons
          if (booking.status == AdminBookingStatus.pending ||
              booking.status == AdminBookingStatus.confirmed ||
              booking.status == AdminBookingStatus.checkedIn) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!booking.isPaid &&
                    booking.status != AdminBookingStatus.checkedIn) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onAction(
                          booking.id, AdminBookingStatus.cancelled.apiValue),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Huỷ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
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
                      if (booking.status == AdminBookingStatus.confirmed) {
                        onCheckIn(booking);
                        return;
                      }
                      final newStatus =
                          booking.status == AdminBookingStatus.pending
                              ? AdminBookingStatus.confirmed.apiValue
                              : AdminBookingStatus.completed.apiValue;
                      onAction(booking.id, newStatus);
                    },
                    icon: Icon(
                      booking.status == AdminBookingStatus.pending
                          ? Icons.check_circle_outline
                          : booking.status == AdminBookingStatus.confirmed
                              ? Icons.login
                              : Icons.task_alt,
                      size: 18,
                    ),
                    label: Text(
                      booking.status == AdminBookingStatus.pending
                          ? 'Xác nhận'
                          : booking.status == AdminBookingStatus.confirmed
                              ? 'Nhận sân'
                              : 'Hoàn thành',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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

class _CheckInQrDialog extends StatelessWidget {
  final BookingCheckInToken token;

  const _CheckInQrDialog({required this.token});

  @override
  Widget build(BuildContext context) {
    final booking = token.booking;
    return AlertDialog(
      title: const Text('Mã QR nhận sân'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              booking.resourceLabel ??
                  '${_courtTypeDisplay(booking.courtType)} · Sân ${booking.courtNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${booking.startTime} - ${booking.endTime}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: token.qrPayload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              token.token,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Khách quét mã này bằng tài khoản đã đặt sân để xác nhận đã nhận sân.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
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

class _RescheduleResult {
  final DateTime date;
  final String startTime;
  final String endTime;

  const _RescheduleResult({
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

class _RescheduleDialog extends StatefulWidget {
  final AdminBooking booking;

  const _RescheduleDialog({required this.booking});

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _date;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.booking.date;
    _startController = TextEditingController(text: widget.booking.startTime);
    _endController = TextEditingController(text: widget.booking.endTime);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Chọn giờ',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  void _submit() {
    final start = _startController.text.trim();
    final end = _endController.text.trim();
    final pattern = RegExp(r'^\d{2}:\d{2}$');
    if (!pattern.hasMatch(start) || !pattern.hasMatch(end)) {
      setState(() => _error = 'Giờ phải có dạng HH:mm.');
      return;
    }
    if (start.compareTo(end) >= 0) {
      setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    Navigator.of(context).pop(
      _RescheduleResult(
        date: _date,
        startTime: start,
        endTime: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi giờ đặt sân'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Đổi ngày'),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    readOnly: true,
                    onTap: () => _pickTime(_startController),
                    decoration: const InputDecoration(
                      labelText: 'Bắt đầu',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    readOnly: true,
                    onTap: () => _pickTime(_endController),
                    decoration: const InputDecoration(
                      labelText: 'Kết thúc',
                      prefixIcon: Icon(Icons.access_time_filled),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: const Text('Lưu đổi giờ'),
        ),
      ],
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
                            DateFormat('HH:mm dd/MM')
                                .format(order.createdAt.toLocal()),
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
              const SizedBox(height: 6),
              _BillLine(
                label: 'Đã thanh toán online',
                value: money.format(bill.paidTotal),
              ),
              const SizedBox(height: 6),
              _BillLine(
                label: 'Còn thu tại quầy',
                value: money.format(bill.unpaidTotal),
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
        ? (method.isNotEmpty ? 'Đã thanh toán bằng $method' : 'Đã thanh toán')
        : isFailed
            ? 'Thanh toán lỗi'
            : 'Chưa thanh toán';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.verified_outlined : Icons.payments_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
