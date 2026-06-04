import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/shared/widgets/loading_button.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String orderId;
  final String? code;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.orderId,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 96,
                  color: success ? AppColors.success : AppColors.error,
                ),
                const SizedBox(height: 24),
                Text(
                  success ? 'Thanh toán thành công!' : 'Thanh toán thất bại',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: success ? AppColors.success : AppColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  success
                      ? 'Đơn hàng $orderId đã được xác nhận.'
                      : _getErrorMessage(code),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                LoadingButton(
                  onPressed: () => context.go('/home'),
                  isLoading: false,
                  icon: Icons.home,
                  label: 'Về trang chủ',
                  backgroundColor: AppColors.primary,
                ),
                if (!success) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/booking'),
                    child: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(String? code) {
    switch (code) {
      case 'cancelled':
        return 'Bạn đã hủy thanh toán.';
      case '24':
        return 'Giao dịch đã bị hủy bởi người dùng.';
      case '51':
        return 'Tài khoản không đủ số dư.';
      case '65':
        return 'Vượt hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng đang bảo trì. Vui lòng thử lại sau.';
      case 'invalid_signature':
        return 'Chữ ký không hợp lệ. Vui lòng liên hệ hỗ trợ.';
      default:
        return 'Đã xảy ra lỗi trong quá trình thanh toán.';
    }
  }
}
