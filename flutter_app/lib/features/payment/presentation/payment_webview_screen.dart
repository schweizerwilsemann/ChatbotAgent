import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/config/flavor_config.dart';
import 'package:sports_venue_chatbot/features/payment/data/vnpay_native.dart';

class PaymentWebviewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const PaymentWebviewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends State<PaymentWebviewScreen> {
  bool _isLoading = true;
  bool _sdkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openVNPaySdk();
    });
  }

  Future<void> _openVNPaySdk() async {
    if (_sdkStarted) return;
    _sdkStarted = true;

    try {
      final tmnCode = FlavorConfig.vnpayTmnCode;
      final isSandbox = FlavorConfig.isSandbox;

      final result = await VNPayNative.openSdk(
        paymentUrl: widget.paymentUrl,
        tmnCode: tmnCode,
        isSandbox: isSandbox,
      );

      if (!mounted) return;

      switch (result) {
        case 'success':
          context.go('/payment/result', extra: {
            'success': true,
            'orderId': widget.orderId,
          });
          break;
        case 'failed':
          context.go('/payment/result', extra: {
            'success': false,
            'orderId': widget.orderId,
            'code': 'failed',
          });
          break;
        case 'cancelled':
          context.go('/payment/result', extra: {
            'success': false,
            'orderId': widget.orderId,
            'code': 'cancelled',
          });
          break;
        case 'processing':
          context.go('/payment/result', extra: {
            'success': false,
            'orderId': widget.orderId,
            'code': 'processing',
          });
          break;
        default:
          context.go('/payment/result', extra: {
            'success': false,
            'orderId': widget.orderId,
            'code': 'unknown',
          });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      context.go('/payment/result', extra: {
        'success': false,
        'orderId': widget.orderId,
        'code': 'error',
      });
    } catch (e) {
      if (!mounted) return;
      context.go('/payment/result', extra: {
        'success': false,
        'orderId': widget.orderId,
        'code': 'error',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VNPay'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.go('/payment/result', extra: {
              'success': false,
              'orderId': widget.orderId,
              'code': 'cancelled',
            });
          },
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Đang mở VNPay...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
