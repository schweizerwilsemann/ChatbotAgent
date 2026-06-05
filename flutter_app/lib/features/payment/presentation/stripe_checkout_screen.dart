import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;
  final String orderType;

  const StripeCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
    this.orderType = 'booking',
  });

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('/api/stripe/success')) {
              context.go('/payment/result', extra: {
                'success': true,
                'orderId': widget.orderId,
                'orderType': widget.orderType,
              });
              return NavigationDecision.prevent;
            }
            if (url.contains('/api/stripe/cancel')) {
              context.go('/payment/result', extra: {
                'success': false,
                'orderId': widget.orderId,
                'orderType': widget.orderType,
                'code': 'cancelled',
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán Stripe'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.go('/payment/result', extra: {
              'success': false,
              'orderId': widget.orderId,
              'orderType': widget.orderType,
              'code': 'cancelled',
            });
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
