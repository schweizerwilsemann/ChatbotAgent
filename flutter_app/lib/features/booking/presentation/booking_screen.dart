import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_confirm_dialog.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_section_title.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';
import 'package:sports_venue_chatbot/shared/widgets/loading_button.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  CourtType _selectedCourtType = CourtType.billiards;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  final TextEditingController _courtNumberController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
      _checkAvailability();
    });
  }

  @override
  void dispose() {
    _courtNumberController.dispose();
    super.dispose();
  }

  void _loadBookings() {
    ref.read(bookingProvider.notifier).loadBookings(_currentUserId);
  }

  String get _currentUserId =>
      ref.read(authStateProvider).valueOrNull?.id ?? 'current_user';

  void _checkAvailability() {
    ref
        .read(bookingProvider.notifier)
        .checkAvailability(courtType: _selectedCourtType, date: _selectedDate);
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    for (int hour = 8; hour < 22; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
    }
    return slots;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
      _checkAvailability();
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      AppSnackBar.showWarning(
          context, 'Vui lòng chọn giờ bắt đầu và kết thúc.');
      return;
    }

    final courtNumber = int.tryParse(_courtNumberController.text);
    if (courtNumber == null || courtNumber < 1) {
      AppSnackBar.showWarning(context, 'Vui lòng nhập số sân hợp lệ.');
      return;
    }

    final booking = BookingCreate(
      courtType: _selectedCourtType,
      courtNumber: courtNumber,
      date: _selectedDate,
      startTime: _selectedStartTime!,
      endTime: _selectedEndTime!,
      userId: _currentUserId,
    );

    final success =
        await ref.read(bookingProvider.notifier).createBooking(booking);

    if (success && mounted) {
      AppSnackBar.showSuccess(context, 'Đặt sân thành công!');
      setState(() {
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);

    // Listen for errors and success messages
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppSnackBar.showError(context, next.error!);
        ref.read(bookingProvider.notifier).clearError();
      }
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        AppSnackBar.showSuccess(context, next.successMessage!);
        ref.read(bookingProvider.notifier).clearSuccess();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt sân')),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadBookings();
          _checkAvailability();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
          child: ResponsiveContainer(
            maxWidth: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Court type selector
                const AppSectionTitle('Loại sân'),
                const SizedBox(height: 8),
                _buildCourtTypeSelector(),
                const SizedBox(height: 24),

                // Date picker
                const AppSectionTitle('Ngày đặt'),
                const SizedBox(height: 8),
                _buildDatePicker(),
                const SizedBox(height: 24),

                // Time slot selection
                const AppSectionTitle('Giờ chơi'),
                const SizedBox(height: 8),
                _buildTimeSlotSelection(),
                const SizedBox(height: 24),

                // Court number input
                const AppSectionTitle('Số sân'),
                const SizedBox(height: 8),
                _buildCourtNumberInput(),
                const SizedBox(height: 32),

                // Confirm button
                LoadingButton(
                  onPressed: _confirmBooking,
                  isLoading: bookingState.isCreating,
                  icon: Icons.check_circle_outline,
                  label: bookingState.isCreating
                      ? 'Đang xử lý...'
                      : 'Xác nhận đặt sân',
                  backgroundColor: _getCourtTypeColor(_selectedCourtType),
                ),
                const SizedBox(height: 32),

                // Existing bookings list
                const AppSectionTitle('Lịch đặt sân của bạn'),
                const SizedBox(height: 8),
                _buildBookingsList(bookingState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourtTypeSelector() {
    return Row(
      children: CourtType.values.map((type) {
        final isSelected = _selectedCourtType == type;
        final color = _getCourtTypeColor(type);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type != CourtType.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCourtType = type;
                  _selectedStartTime = null;
                  _selectedEndTime = null;
                });
                _checkAvailability();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color:
                      isSelected ? color.withOpacity(0.1) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCourtTypeColor(CourtType type) {
    switch (type) {
      case CourtType.billiards:
        return AppColors.billiardsColor;
      case CourtType.pickleball:
        return AppColors.pickleballColor;
      case CourtType.badminton:
        return AppColors.badmintonColor;
    }
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDate),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection() {
    final timeSlots = _generateTimeSlots();
    final availability = ref.watch(bookingProvider).availability;
    final courtColor = _getCourtTypeColor(_selectedCourtType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start time
        const Text(
          'Giờ bắt đầu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timeSlots.map((slot) {
            final isSelected = _selectedStartTime == slot;
            final isAvailable = _isSlotAvailable(slot, availability);

            return ChoiceChip(
              label: Text(slot),
              selected: isSelected,
              onSelected: isAvailable
                  ? (selected) {
                      setState(() {
                        _selectedStartTime = selected ? slot : null;
                        // Auto-set end time to next hour
                        if (selected) {
                          final hour = int.parse(slot.split(':')[0]);
                          final endHour = hour + 1;
                          if (endHour <= 22) {
                            _selectedEndTime =
                                '${endHour.toString().padLeft(2, '0')}:00';
                          } else {
                            _selectedEndTime = null;
                          }
                        } else {
                          _selectedEndTime = null;
                        }
                      });
                    }
                  : null,
              selectedColor: courtColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: !isAvailable
                    ? AppColors.textHint
                    : isSelected
                        ? courtColor
                        : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: !isAvailable
                    ? AppColors.divider
                    : isSelected
                        ? courtColor
                        : AppColors.divider,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // End time
        const Text(
          'Giờ kết thúc',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timeSlots.map((slot) {
            final isSelected = _selectedEndTime == slot;
            final canSelect = _selectedStartTime != null &&
                slot.compareTo(_selectedStartTime!) > 0;

            return ChoiceChip(
              label: Text(slot),
              selected: isSelected,
              onSelected: canSelect
                  ? (selected) {
                      setState(() {
                        _selectedEndTime = selected ? slot : null;
                      });
                    }
                  : null,
              selectedColor: courtColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: !canSelect
                    ? AppColors.textHint
                    : isSelected
                        ? courtColor
                        : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: !canSelect
                    ? AppColors.divider
                    : isSelected
                        ? courtColor
                        : AppColors.divider,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _isSlotAvailable(String slot, AvailabilityResponse? availability) {
    if (availability == null) return true;
    final matchingSlot = availability.slots.where((s) => s.startTime == slot);
    if (matchingSlot.isEmpty) return true;
    return matchingSlot.first.isAvailable;
  }

  Widget _buildCourtNumberInput() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            final current = int.tryParse(_courtNumberController.text) ?? 1;
            if (current > 1) {
              _courtNumberController.text = (current - 1).toString();
            }
          },
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.primary,
        ),
        Expanded(
          child: TextField(
            controller: _courtNumberController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Số sân',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final current = int.tryParse(_courtNumberController.text) ?? 1;
            _courtNumberController.text = (current + 1).toString();
          },
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildBookingsList(BookingState bookingState) {
    if (bookingState.isLoading && bookingState.bookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (bookingState.bookings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.event_note, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                'Chưa có lịch đặt sân',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookingState.bookings.length,
      itemBuilder: (context, index) {
        final booking = bookingState.bookings[index];
        return _BookingCard(
          booking: booking,
          onCancel: () {
            _showCancelDialog(booking);
          },
        );
      },
    );
  }

  void _showCancelDialog(Booking booking) async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Hủy đặt sân',
      content: 'Bạn có chắc muốn hủy đặt sân ${booking.courtType.displayName} '
          'số ${booking.courtNumber}?',
      confirmLabel: 'Hủy đặt sân',
      isDestructive: true,
      cancelLabel: 'Không',
    );
    if (confirmed == true) {
      ref.read(bookingProvider.notifier).cancelBooking(booking.id);
    }
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;

  const _BookingCard({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  booking.courtType.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${booking.courtType.displayName} - Sân ${booking.courtNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(booking.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.startTime} - ${booking.endTime}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (booking.status == BookingStatus.pending ||
                    booking.status == BookingStatus.confirmed)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Hủy'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.confirmed:
        return AppColors.success;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.info;
    }
  }
}
