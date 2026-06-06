import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/staff/data/staff_notification.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_api.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_section_title.dart';
import 'package:sports_venue_chatbot/shared/widgets/pagination_footer.dart';

class StaffNotificationsScreen extends ConsumerStatefulWidget {
  const StaffNotificationsScreen({super.key});

  @override
  ConsumerState<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState
    extends ConsumerState<StaffNotificationsScreen> {
  bool _handlePagination(ScrollNotification scrollInfo) {
    if (scrollInfo.metrics.extentAfter < 360) {
      ref.read(staffNotificationsProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffNotificationsProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vận hành'),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(staffNotificationsProvider.notifier).markAllAsRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đọc tất cả'),
            ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(staffNotificationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _handlePagination,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(staffNotificationsProvider.notifier).refresh(),
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            children: [
              ResponsiveContainer(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ConnectionBanner(isConnected: state.isConnected),
                    const SizedBox(height: 20),
                    const AppSectionTitle('Thông báo mới'),
                    const SizedBox(height: 8),
                    if (state.isLoading && state.notifications.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (state.notifications.isEmpty)
                      const _EmptyNotifications()
                    else ...[
                      ...state.notifications.map(
                        (notification) => _NotificationTile(
                          notification: notification,
                          onMarkRead: () => ref
                              .read(staffNotificationsProvider.notifier)
                              .markAsRead(notification.id),
                        ),
                      ),
                      PaginationFooter(
                        isLoading: state.isLoadingMore,
                        hasMore: state.hasMore,
                        endLabel: 'Đã tải hết thông báo',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final bool isConnected;

  const _ConnectionBanner({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi_tethering : Icons.wifi_off,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected
                  ? 'Đang nhận thông báo realtime'
                  : 'Đang chờ kết nối realtime',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final StaffNotification notification;
  final VoidCallback? onMarkRead;

  const _NotificationTile({required this.notification, this.onMarkRead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isRead;
    final timeText = DateFormat('HH:mm dd/MM', 'vi_VN')
        .format(notification.createdAt.toLocal());
    final isStaffRequest = notification.eventType == 'staff.requested' ||
        notification.eventType == 'staff_request' ||
        notification.eventType == 'staff_request_accepted';
    final isOrder = notification.eventType.startsWith('order');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showCustomerInfo(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.surface
              : AppColors.primarySurface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isRead
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _eventColor(notification.eventType)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    _eventIcon(notification.eventType),
                    color: _eventColor(notification.eventType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.w700,
                                color: isRead
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            timeText,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: isRead
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (notification.payload['resource_label'] != null &&
                          notification.payload['resource_label']
                              .toString()
                              .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            notification.payload['resource_label'].toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (notification.payload['table_number'] != null &&
                          notification.payload['table_number'] != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Bàn ${notification.payload['table_number']}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isOrder)
                        _OrderNotificationSummary(
                          payload: notification.payload,
                        ),
                      if (isStaffRequest)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Xử lý yêu cầu tại tab Yêu cầu.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Mark as read button
                if (!isRead && onMarkRead != null)
                  IconButton(
                    tooltip: 'Đánh dấu đã đọc',
                    icon: const Icon(
                      Icons.done,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onMarkRead,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerInfo(BuildContext context, WidgetRef ref) async {
    final userId = notification.payload['user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin khách hàng')),
        );
      }
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final authApi = ref.read(authApiProvider);
      final user = await authApi.getProfile(userId);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Thông tin khách hàng'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person, 'Tên', user.name),
                const SizedBox(height: 8),
                _infoRow(Icons.phone, 'SĐT', user.phone),
                if (user.email != null && user.email!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.email, 'Email', user.email!),
                ],
                const SizedBox(height: 8),
                _infoRow(Icons.badge, 'Mã KH', user.id),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải thông tin khách hàng')),
        );
      }
    }
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  IconData _eventIcon(String eventType) {
    if (eventType.startsWith('order')) return Icons.shopping_bag_outlined;
    if (eventType.startsWith('booking')) return Icons.sports_tennis;
    if (eventType == 'staff.requested' || eventType == 'staff_request') {
      return Icons.support_agent;
    }
    return Icons.notifications;
  }

  Color _eventColor(String eventType) {
    if (eventType.startsWith('order')) return AppColors.warning;
    if (eventType.startsWith('booking')) return AppColors.info;
    if (eventType == 'staff.requested' || eventType == 'staff_request') {
      return AppColors.primary;
    }
    return AppColors.textSecondary;
  }
}

class _OrderNotificationSummary extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _OrderNotificationSummary({required this.payload});

  @override
  Widget build(BuildContext context) {
    final rawItems = payload['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderId = payload['id']?.toString();
    final shortOrderId = orderId == null || orderId.length <= 8
        ? orderId
        : orderId.substring(0, 8);
    final status = payload['status']?.toString();
    final paymentStatus = payload['payment_status']?.toString();
    final total = _moneyText(payload['total_price']);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((orderId != null && orderId.isNotEmpty) ||
              (status != null && status.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                [
                  if (orderId != null && orderId.isNotEmpty) 'Mã $shortOrderId',
                  if (status != null && status.isNotEmpty) status,
                  if (paymentStatus != null && paymentStatus.isNotEmpty)
                    _paymentLabel(paymentStatus),
                ].join(' · '),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...rawItems.whereType<Map>().map((rawItem) {
            final item = Map<String, dynamic>.from(rawItem);
            final name = item['item_name']?.toString() ?? 'Món';
            final quantity = item['quantity']?.toString() ?? '1';
            final lineTotal = _moneyText(item['total_price']);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$name x$quantity',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (lineTotal != null)
                    Text(
                      lineTotal,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          }),
          if (total != null) ...[
            const Divider(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tổng',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String? _moneyText(Object? raw) {
    final value = _numberValue(raw);
    if (value == null) return null;
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(value);
  }

  static num? _numberValue(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.replaceAll(',', ''));
    return null;
  }

  static String _paymentLabel(String status) {
    if (status.startsWith('paid')) {
      final method =
          status.contains('_') ? status.split('_').last.toUpperCase() : '';
      return method.isNotEmpty ? 'Đã thanh toán ($method)' : 'Đã thanh toán';
    }
    if (status == 'failed') return 'Thanh toán lỗi';
    return 'Chưa thanh toán';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.notifications_none, size: 42, color: AppColors.textHint),
          SizedBox(height: 10),
          Text(
            'Chưa có thông báo vận hành',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
