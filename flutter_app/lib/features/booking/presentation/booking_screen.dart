import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_models.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_provider.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/payment_provider.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/stripe_provider.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/selected_venue_provider.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/venue_provider.dart';
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
  VenueResource? _selectedResource;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _courtNumberController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
      _syncCourtTypeWithVenue();
      _checkAvailability();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _courtNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() {
    return ref.read(bookingProvider.notifier).loadBookings(_currentUserId);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(bookingProvider.notifier).loadMoreBookings(_currentUserId);
    }
  }

  String get _currentUserId =>
      ref.read(authStateProvider).valueOrNull?.id ?? 'current_user';

  VenueResource? _resourceForCourtType(
    List<VenueResource> resources,
    CourtType courtType,
  ) {
    final matching = resources
        .where((resource) => resource.sportType == courtType.name)
        .toList();
    final selectedResourceId = _selectedResource?.id;
    if (selectedResourceId != null) {
      for (final resource in matching) {
        if (resource.id == selectedResourceId) return resource;
      }
    }
    return matching.isEmpty ? null : matching.first;
  }

  bool _syncCourtTypeWithVenue([List<VenueResource>? resourcesOverride]) {
    final resources =
        resourcesOverride ?? ref.read(venueResourcesProvider).valueOrNull ?? [];
    if (resources.isEmpty) return false;

    final sportTypes =
        resources.map((r) => r.sportType).whereType<String>().toSet();
    final availableTypes =
        CourtType.values.where((ct) => sportTypes.contains(ct.name)).toList();
    if (availableTypes.isEmpty) return false;

    final nextType = availableTypes.contains(_selectedCourtType)
        ? _selectedCourtType
        : availableTypes.first;
    final nextResource = _resourceForCourtType(resources, nextType);
    final shouldUpdate = nextType != _selectedCourtType ||
        nextResource?.id != _selectedResource?.id;

    if (shouldUpdate) {
      setState(() {
        _selectedCourtType = nextType;
        _selectedResource = nextResource;
        if (nextResource != null) {
          _courtNumberController.text = nextResource.number.toString();
        }
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
    }

    return shouldUpdate;
  }

  /// Returns only the court types available at the selected venue.
  List<CourtType> _availableCourtTypes() {
    final resourcesAsync = ref.read(venueResourcesProvider);
    // Return empty list while loading to prevent flash
    if (resourcesAsync.isLoading || resourcesAsync.hasError) return [];
    final resources = resourcesAsync.valueOrNull ?? [];
    if (resources.isEmpty) return CourtType.values;
    final sportTypes =
        resources.map((r) => r.sportType).whereType<String>().toSet();
    final available =
        CourtType.values.where((ct) => sportTypes.contains(ct.name)).toList();
    return available.isEmpty ? CourtType.values : available;
  }

  void _checkAvailability() {
    final selectedVenue = ref.read(selectedVenueProvider);
    ref.read(bookingProvider.notifier).checkAvailability(
          courtType: _selectedCourtType,
          date: _selectedDate,
          venueId: selectedVenue?.id,
        );
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

    final resources = ref.read(venueResourcesProvider).valueOrNull ?? [];
    final selectedVenue = ref.read(selectedVenueProvider);
    final selectedResource = _selectedResource ??
        _resourceForCourtType(resources, _selectedCourtType);
    final courtNumber =
        selectedResource?.number ?? int.tryParse(_courtNumberController.text);
    if (courtNumber == null || courtNumber < 1) {
      AppSnackBar.showWarning(context, 'Vui lòng chọn bàn / sân hợp lệ.');
      return;
    }

    final booking = BookingCreate(
      venueId: selectedResource?.venueId ?? selectedVenue?.id,
      resourceId: selectedResource?.id,
      resourceLabel: selectedResource?.displayLabel,
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
      _showPaymentDialog(booking);
    }
  }

  void _showPaymentDialog(BookingCreate bookingData) async {
    final bookingState = ref.read(bookingProvider);
    final createdBooking = bookingState.lastCreatedBooking;
    final totalPrice = createdBooking?.totalPrice;
    if (totalPrice == null || totalPrice <= 0) return;

    final amount = totalPrice.round();
    final label = createdBooking?.resourceLabel ??
        '${createdBooking?.courtType.displayName ?? bookingData.courtType.displayName} - Sân ${createdBooking?.courtNumber ?? bookingData.courtNumber}';

    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Thanh toán ngay',
      content:
          'Bạn có muốn thanh toán $label?\nTổng: ${NumberFormat('#,###', 'vi_VN').format(amount)}đ',
      confirmLabel: 'Thanh toán',
      cancelLabel: 'Để sau',
    );

    if (confirmed == true && mounted) {
      final orderId = createdBooking?.id;
      if (orderId == null) {
        AppSnackBar.showError(context, 'Không tìm thấy thông tin đặt sân.');
        return;
      }

      if (!mounted) return;
      final paymentMethod = await _showPaymentMethodDialog();
      if (paymentMethod == null) return;

      if (paymentMethod == 'stripe') {
        await _processStripePayment(orderId, amount, label);
      } else {
        await _processVnpayPayment(orderId, amount, label);
      }
    }
  }

  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn phương thức thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.primary),
              title: const Text('Stripe (Thẻ quốc tế)'),
              subtitle: const Text('Visa, Mastercard, JCB'),
              onTap: () => Navigator.pop(context, 'stripe'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.account_balance, color: AppColors.success),
              title: const Text('VNPay (Ngân hàng VN)'),
              subtitle: const Text('ATM, Internet Banking, QR'),
              onTap: () => Navigator.pop(context, 'vnpay'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processStripePayment(
      String orderId, int amount, String label) async {
    final stripeNotifier = ref.read(stripeProvider.notifier);
    final success = await stripeNotifier.pay(
      orderId: orderId,
      amount: amount,
      description: 'Dat san $label',
      orderType: 'booking',
    );

    if (success && mounted) {
      context.go('/payment/result', extra: {
        'success': true,
        'orderId': orderId,
        'orderType': 'booking',
      });
    } else if (mounted) {
      final error = ref.read(stripeProvider).error;
      if (error != null) {
        AppSnackBar.showError(context, error);
      }
    }
  }

  Future<void> _processVnpayPayment(
      String orderId, int amount, String label) async {
    final notifier = ref.read(paymentProvider.notifier);
    final paymentSuccess = await notifier.createPayment(
      orderId: orderId,
      amount: amount,
      description: 'Dat san $label',
      orderType: 'booking',
    );

    if (paymentSuccess && mounted) {
      final paymentState = ref.read(paymentProvider);
      if (paymentState.paymentUrl != null) {
        context.push('/payment', extra: {
          'paymentUrl': paymentState.paymentUrl!,
          'orderId': orderId,
          'orderType': 'booking',
        });
      }
    } else if (mounted) {
      final error = ref.read(paymentProvider).error;
      if (error != null) {
        AppSnackBar.showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(venuesProvider);
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

    // Sync court type when venue changes
    ref.listen(selectedVenueProvider, (previous, next) {
      if (previous?.id != next?.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedResource = null;
            _selectedStartTime = null;
            _selectedEndTime = null;
          });
        });
      }
    });

    ref.listen<AsyncValue<List<VenueResource>>>(venueResourcesProvider, (
      previous,
      next,
    ) {
      final resources = next.valueOrNull;
      if (resources == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncCourtTypeWithVenue(resources);
        _checkAvailability();
      });
    });

    final availableTypes = _availableCourtTypes();
    final showCourtTypeSelector = availableTypes.length > 1;
    final isResourcesLoading = ref.watch(venueResourcesProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt sân')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadBookings();
          _syncCourtTypeWithVenue();
          _checkAvailability();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
          child: ResponsiveContainer(
            maxWidth: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Loading state while resources are being fetched
                if (isResourcesLoading) ...[
                  const SizedBox(height: 32),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Đang tải thông tin sân...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Court type selector (only when multiple types available)
                if (!isResourcesLoading && showCourtTypeSelector) ...[
                  const AppSectionTitle('Loại sân'),
                  const SizedBox(height: 8),
                  _buildCourtTypeSelector(availableTypes),
                  const SizedBox(height: 24),
                ],

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

                // Court/resource selector
                const AppSectionTitle('Bàn / sân'),
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
                  backgroundColor: AppColors.primary,
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

  Widget _buildCourtTypeSelector(List<CourtType> availableTypes) {
    return Row(
      children: availableTypes.map((type) {
        final isSelected = _selectedCourtType == type;
        final color = _getCourtTypeColor(type);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type != availableTypes.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCourtType = type;
                  _selectedResource = null;
                  _selectedStartTime = null;
                  _selectedEndTime = null;
                });
                _checkAvailability();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
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
              selectedColor: courtColor.withValues(alpha: 0.2),
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
              selectedColor: courtColor.withValues(alpha: 0.2),
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
    final resourcesAsync = ref.watch(venueResourcesProvider);
    return resourcesAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => _buildLegacyCourtNumberInput(),
      data: (resources) {
        final filtered = resources
            .where((resource) => resource.sportType == _selectedCourtType.name)
            .toList();
        if (filtered.isEmpty) return _buildLegacyCourtNumberInput();
        final selected = _resourceForCourtType(filtered, _selectedCourtType);
        return DropdownButtonFormField<VenueResource>(
          key: ValueKey('${_selectedCourtType.name}-${selected?.id ?? 'none'}'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Chọn bàn / sân',
            prefixIcon: Icon(Icons.location_on_outlined),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: filtered
              .map(
                (resource) => DropdownMenuItem(
                  value: resource,
                  child: Text(
                    resource.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (resource) {
            setState(() {
              _selectedResource = resource;
              if (resource != null) {
                _courtNumberController.text = resource.number.toString();
              }
            });
          },
        );
      },
    );
  }

  Widget _buildLegacyCourtNumberInput() {
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
            decoration: const InputDecoration(
              labelText: 'Số bàn / sân',
              contentPadding: EdgeInsets.symmetric(
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.event_note, size: 48, color: AppColors.textHint),
              SizedBox(height: 16),
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
      itemCount:
          bookingState.bookings.length + (bookingState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= bookingState.bookings.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
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
    final bookingLabel = booking.resourceLabel ??
        '${booking.courtType.displayName} số ${booking.courtNumber}';
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Hủy đặt sân',
      content: 'Bạn có chắc muốn hủy $bookingLabel?',
      confirmLabel: 'Hủy đặt sân',
      isDestructive: true,
      cancelLabel: 'Không',
    );
    if (confirmed == true) {
      ref.read(bookingProvider.notifier).cancelBooking(booking.id);
    }
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
                        booking.resourceLabel ??
                            '${booking.courtType.displayName} - Sân ${booking.courtNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(booking.date),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
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
                    const SizedBox(height: 4),
                    _PaymentBadge(paymentStatus: booking.paymentStatus),
                  ],
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
                if (!booking.isPaid &&
                    (booking.status == BookingStatus.pending ||
                        booking.status == BookingStatus.confirmed))
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
