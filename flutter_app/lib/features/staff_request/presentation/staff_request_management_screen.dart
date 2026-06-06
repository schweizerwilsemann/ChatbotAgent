import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/staff_request/presentation/staff_request_management_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_section_title.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class StaffRequestManagementScreen extends ConsumerStatefulWidget {
  const StaffRequestManagementScreen({super.key});

  @override
  ConsumerState<StaffRequestManagementScreen> createState() =>
      _StaffRequestManagementScreenState();
}

class _StaffRequestManagementScreenState
    extends ConsumerState<StaffRequestManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffRequestManagementProvider.notifier).loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffRequestManagementProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    ref.listen<StaffRequestManagementState>(
      staffRequestManagementProvider,
      (previous, next) {
        if (next.successMessage != null &&
            next.successMessage != previous?.successMessage) {
          AppSnackBar.showSuccess(context, next.successMessage!);
          ref.read(staffRequestManagementProvider.notifier).clearMessages();
        }
        if (next.error != null && next.error != previous?.error) {
          AppSnackBar.showError(context, next.error!);
          ref.read(staffRequestManagementProvider.notifier).clearMessages();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu khách'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(staffRequestManagementProvider.notifier)
                .loadRequests(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(staffRequestManagementProvider.notifier).loadRequests(),
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
          children: [
            ResponsiveContainer(
              maxWidth: 760,
              child: state.isLoading && state.requests.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionTitle('Đang chờ tiếp nhận'),
                        const SizedBox(height: 8),
                        if (state.pendingRequests.isEmpty)
                          const _EmptyRequestGroup(
                            message: 'Không có yêu cầu đang chờ.',
                          )
                        else
                          ...state.pendingRequests.map(
                            (request) => _StaffRequestCard(
                              request: request,
                              currentUserId: user?.id,
                              onAccept: () => ref
                                  .read(staffRequestManagementProvider.notifier)
                                  .acceptRequest(request.id),
                              onCancel: () => _confirmCancel(context, request),
                            ),
                          ),
                        const SizedBox(height: 20),
                        const AppSectionTitle('Đang xử lý'),
                        const SizedBox(height: 8),
                        if (state.acceptedRequests.isEmpty)
                          const _EmptyRequestGroup(
                            message: 'Chưa có yêu cầu nào đang xử lý.',
                          )
                        else
                          ...state.acceptedRequests.map(
                            (request) => _StaffRequestCard(
                              request: request,
                              currentUserId: user?.id,
                              onComplete: () =>
                                  _confirmComplete(context, request),
                              onOpenChat: () => _openChat(context, request),
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

  Future<void> _confirmCancel(
    BuildContext context,
    StaffRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ yêu cầu'),
        content: Text('Huỷ yêu cầu của ${request.userName ?? 'khách'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Huỷ yêu cầu'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(staffRequestManagementProvider.notifier)
          .cancelRequest(request.id);
    }
  }

  Future<void> _confirmComplete(
    BuildContext context,
    StaffRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn thành yêu cầu'),
        content: Text(
            'Đánh dấu yêu cầu của ${request.userName ?? 'khách'} là xong?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Chưa'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hoàn thành'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(staffRequestManagementProvider.notifier)
          .completeRequest(request.id);
    }
  }

  void _openChat(BuildContext context, StaffRequest request) {
    context.push(
      '/staff-operator-chat/${request.id}',
      extra: {
        'customerName': request.userName,
        'resourceLabel': request.resourceLabel,
      },
    );
  }
}

class _StaffRequestCard extends StatelessWidget {
  final StaffRequest request;
  final String? currentUserId;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final VoidCallback? onOpenChat;

  const _StaffRequestCard({
    required this.request,
    required this.currentUserId,
    this.onAccept,
    this.onCancel,
    this.onComplete,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final timeText =
        DateFormat('HH:mm dd/MM', 'vi_VN').format(request.createdAt.toLocal());
    final isAccepted = request.status == StaffRequestStatus.accepted;
    final isMine = request.acceptedBy == null ||
        currentUserId == null ||
        request.acceptedBy == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.support_agent,
                  color: AppColors.primary,
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
                        Expanded(
                          child: Text(
                            request.userName ?? 'Khách hàng',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
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
                      request.requestType.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request.description != null &&
                        request.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        request.description!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(status: request.status),
                        if (request.resourceLabel != null &&
                            request.resourceLabel!.isNotEmpty)
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            label: request.resourceLabel!,
                          )
                        else if (request.tableNumber != null &&
                            request.tableNumber != 0)
                          _InfoChip(
                            icon: Icons.table_restaurant_outlined,
                            label: 'Bàn ${request.tableNumber}',
                          ),
                        if (isAccepted &&
                            request.acceptedByName != null &&
                            request.acceptedByName!.isNotEmpty)
                          _InfoChip(
                            icon: Icons.person_outline,
                            label: request.acceptedByName!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (request.status == StaffRequestStatus.pending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Huỷ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Tiếp nhận'),
                  ),
                ),
              ],
            )
          else if (isAccepted && isMine)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Hoàn thành'),
                  ),
                ),
              ],
            )
          else if (isAccepted)
            const Text(
              'Yêu cầu này đang được nhân viên khác xử lý.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StaffRequestStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == StaffRequestStatus.pending
        ? AppColors.warning
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequestGroup extends StatelessWidget {
  final String message;

  const _EmptyRequestGroup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
