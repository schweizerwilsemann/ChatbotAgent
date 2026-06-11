import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';

class MiniAppWebViewScreen extends ConsumerStatefulWidget {
  final String title;
  final String assetPath;

  const MiniAppWebViewScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  ConsumerState<MiniAppWebViewScreen> createState() =>
      _MiniAppWebViewScreenState();
}

class _MiniAppWebViewScreenState extends ConsumerState<MiniAppWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  late final bool _isFnBApp;

  @override
  void initState() {
    super.initState();
    _isFnBApp = widget.assetPath.contains('fnb_partner');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            if (_isFnBApp) {
              _loadPartnerStores();
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'PartnerBridge',
        onMessageReceived: _onJsMessage,
      )
      ..loadFlutterAsset(widget.assetPath);
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      final action = data['action'] as String?;
      if (action == 'placeOrder') {
        _placeOrders(data['orders'] as Map<String, dynamic>);
      } else if (action == 'fetchMenu') {
        _fetchStoreMenu(data['storeId'] as String);
      }
    } catch (e) {
      debugPrint('JS message error: $e');
    }
  }

  Future<void> _loadPartnerStores() async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/partner/stores');
      final stores = response.data as List<dynamic>;
      final jsData = jsonEncode(stores);
      _controller.runJavaScript('loadStores($jsData)');

      // Pre-fetch menu for each store
      for (final store in stores) {
        final storeId = store['id'] as String;
        await _fetchStoreMenu(storeId);
      }
    } catch (e) {
      debugPrint('Load stores error: $e');
    }
  }

  Future<void> _fetchStoreMenu(String storeId) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/partner/stores/$storeId/menu');
      final menu = response.data as List<dynamic>;
      final jsData = jsonEncode(menu);
      _controller.runJavaScript('loadMenu("$storeId", $jsData)');
    } catch (e) {
      debugPrint('Load menu error: $e');
    }
  }

  Future<void> _placeOrders(Map<String, dynamic> ordersByStore) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      String lastOrderId = '';

      for (final entry in ordersByStore.entries) {
        final storeId = entry.key;
        final items = (entry.value as List<dynamic>)
            .map((item) => {
                  'item_id': item['item_id'],
                  'item_name': item['item_name'],
                  'quantity': item['quantity'],
                  'unit_price': item['unit_price'],
                })
            .toList();

        final response = await dio.post(
          '/api/partner/orders',
          data: {
            'store_id': storeId,
            'items': items,
            'delivery_location': 'Sân đang chơi',
            'notes': '',
          },
        );

        lastOrderId = response.data['id'] as String? ?? '';
      }

      _controller.runJavaScript('onOrderSuccess("$lastOrderId")');
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Đặt hàng thất bại';
      _controller.runJavaScript('onOrderError("$msg")');
    } catch (e) {
      _controller.runJavaScript('onOrderError("Đã xảy ra lỗi")');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
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
