import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/payment_provider.dart';
import 'package:sports_venue_chatbot/features/payment/presentation/stripe_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

/// A card widget embedded in the chat that displays booking/order info
/// with "Thanh toán" (Pay) and "Để sau" (Later) action buttons.
class OrderCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> metadata;

  const OrderCard({super.key, required this.metadata});

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _dismissed = false;

  String get _type => widget.metadata['type'] as String? ?? '';
  String get _id => widget.metadata['id'] as String? ?? '';
  double get _totalPrice =>
      (widget.metadata['total_price'] as num?)?.toDouble() ?? 0;
  String get _paymentStatus =>
      widget.metadata['payment_status'] as String? ?? 'unpaid';
  bool get _isPaid => _paymentStatus.startsWith('paid');

  @override
  Widget build(BuildContext context) {
    if (_isPaid) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _dismissed ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.divider),
            _buildBody(),
            const Divider(height: 1, color: AppColors.divider),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isBooking = _type == 'booking';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isBooking
                  ? AppColors.toolBadgeBooking
                  : AppColors.toolBadgeOrder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isBooking ? Icons.calendar_month : Icons.shopping_bag,
              size: 18,
              color: isBooking ? AppColors.billiardsColor : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBooking ? 'Đặt sân' : 'Đặt hàng',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_id.isNotEmpty)
                  Text(
                    'Mã: ${_id.length > 12 ? '${_id.substring(0, 12)}...' : _id}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Chờ thanh toán',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.warning,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_type == 'booking') return _buildBookingBody();
    if (_type == 'order') return _buildOrderBody();
    return const SizedBox.shrink();
  }

  Widget _buildBookingBody() {
    final label = widget.metadata['label'] as String? ?? '';
    final time = widget.metadata['time'] as String? ?? '';
    final venueName = widget.metadata['venue_name'] as String? ?? '';
    final customerName = widget.metadata['customer_name'] as String? ?? '';
    final customerPhone = widget.metadata['customer_phone'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerInfo(customerName, customerPhone),
          if (venueName.isNotEmpty) ...[
            _infoRow(Icons.store, venueName),
            const SizedBox(height: 6),
          ],
          if (label.isNotEmpty) ...[
            _infoRow(Icons.sports_tennis, label),
            const SizedBox(height: 6),
          ],
          if (time.isNotEmpty) ...[
            _infoRow(Icons.access_time, time),
            const SizedBox(height: 8),
          ],
          _priceRow(),
        ],
      ),
    );
  }

  Widget _buildOrderBody() {
    final items = widget.metadata['items'] as List<dynamic>? ?? [];
    final venueName = widget.metadata['venue_name'] as String? ?? '';
    final resourceLabel = widget.metadata['resource_label'] as String? ?? '';
    final tableNumber = widget.metadata['table_number'] as int? ?? 0;
    final notes = widget.metadata['notes'] as String? ?? '';
    final customerName = widget.metadata['customer_name'] as String? ?? '';
    final customerPhone = widget.metadata['customer_phone'] as String? ?? '';

    final tableText = resourceLabel.isNotEmpty
        ? resourceLabel
        : (tableNumber > 0 ? 'Bàn số $tableNumber' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerInfo(customerName, customerPhone),
          if (venueName.isNotEmpty) ...[
            _infoRow(Icons.store, venueName),
            const SizedBox(height: 6),
          ],
          if (tableText.isNotEmpty) ...[
            _infoRow(Icons.table_restaurant, tableText),
            const SizedBox(height: 6),
          ],
          if (items.isNotEmpty) ...[
            ...items.map((item) => _orderItemRow(item)),
            const SizedBox(height: 4),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            _infoRow(Icons.note, 'Ghi chú: $notes'),
          ],
          const SizedBox(height: 6),
          _priceRow(),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(String name, String phone) {
    if (name.isEmpty && phone.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderItemRow(dynamic item) {
    final name = item['name'] as String? ?? '';
    final qty = item['quantity'] as int? ?? 0;
    final price = (item['total_price'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              '$name x$qty',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Text(
            NumberFormat('#,###', 'vi_VN').format(price.round()),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Tổng cộng',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${NumberFormat('#,###', 'vi_VN').format(_totalPrice.round())}đ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _dismissed ? null : _handleDismiss,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Để sau', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _handlePay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Thanh toán',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDismiss() {
    setState(() => _dismissed = true);
  }

  void _handlePay() async {
    if (!mounted) return;

    final method = await _showPaymentMethodDialog();
    if (method == null || !mounted) return;

    final amount = _totalPrice.round();
    final orderId = _id;
    final label = _type == 'booking'
        ? (widget.metadata['label'] as String? ?? 'Đặt sân')
        : 'Đặt hàng';

    if (method == 'stripe') {
      await _processStripePayment(orderId, amount, label);
    } else {
      await _processVnpayPayment(orderId, amount, label);
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
    final orderType = _type == 'booking' ? 'booking' : 'order';
    final success = await stripeNotifier.createCheckout(
      orderId: orderId,
      amount: amount,
      description: label,
      orderType: orderType,
    );

    if (success && mounted) {
      final stripeState = ref.read(stripeProvider);
      if (stripeState.checkoutUrl != null) {
        context.push('/stripe-checkout', extra: {
          'checkoutUrl': stripeState.checkoutUrl!,
          'orderId': orderId,
          'orderType': orderType,
        });
      }
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
    final orderType = _type == 'booking' ? 'booking' : 'order';
    final paymentSuccess = await notifier.createPayment(
      orderId: orderId,
      amount: amount,
      description: label,
      orderType: orderType,
    );

    if (paymentSuccess && mounted) {
      final paymentState = ref.read(paymentProvider);
      if (paymentState.paymentUrl != null) {
        context.push('/payment', extra: {
          'paymentUrl': paymentState.paymentUrl!,
          'orderId': orderId,
          'orderType': orderType,
        });
      }
    } else if (mounted) {
      final error = ref.read(paymentProvider).error;
      if (error != null) {
        AppSnackBar.showError(context, error);
      }
    }
  }
}
