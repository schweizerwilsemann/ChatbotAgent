import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/staff/data/staff_notification.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_api.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_section_title.dart';

class StaffNotificationsScreen extends ConsumerStatefulWidget {
  const StaffNotificationsScreen({super.key});

  @override
  ConsumerState<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState
    extends ConsumerState<StaffNotificationsScreen> {
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
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(staffNotificationsProvider.notifier).refresh(),
        child: ListView(
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
                  else
                    ...state.notifications.map(
                      (notification) => _NotificationTile(
                        notification: notification,
                        onMarkRead: () => ref
                            .read(staffNotificationsProvider.notifier)
                            .markAsRead(notification.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
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

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showCustomerInfo(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.surface
              : AppColors.primarySurface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isRead ? AppColors.border : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  _eventColor(notification.eventType).withValues(alpha: 0.12),
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
                  if (notification.payload['table_number'] != null &&
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
    if (eventType.startsWith('order')) return Icons.restaurant;
    if (eventType.startsWith('booking')) return Icons.sports_tennis;
    return Icons.support_agent;
  }

  Color _eventColor(String eventType) {
    if (eventType.startsWith('order')) return AppColors.warning;
    if (eventType.startsWith('booking')) return AppColors.info;
    return AppColors.primary;
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
