import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/staff_request/presentation/staff_request_provider.dart';
import 'package:sports_venue_chatbot/features/staff_request/presentation/widgets/call_staff_dialog.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class StaffRequestBubble extends ConsumerWidget {
  const StaffRequestBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffRequestProvider);

    ref.listen<StaffRequestState>(staffRequestProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppSnackBar.showError(context, next.error!);
        Future.microtask(
            () => ref.read(staffRequestProvider.notifier).clearMessages());
      }
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        AppSnackBar.showSuccess(context, next.successMessage!);
        Future.microtask(
            () => ref.read(staffRequestProvider.notifier).clearMessages());
      }
    });

    if (state.hasActiveRequest) {
      return _ActiveRequestChip(
        state: state,
        onCancel: () => _handleCancelRequest(context, ref),
        onShowInfo: () => _showActiveRequestInfo(context, ref, state),
      );
    }

    return _CallButton(
      onTap: () => _handleCallStaff(context, ref),
    );
  }

  Future<void> _handleCallStaff(BuildContext context, WidgetRef ref) async {
    final result = await CallStaffDialog.show(context);
    if (result != null && context.mounted) {
      await ref.read(staffRequestProvider.notifier).createRequest(
            requestType: result.requestType,
            description: result.description,
            tableNumber: result.tableNumber,
          );
    }
  }

  Future<void> _handleCancelRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await CallStaffDialog.showCancelConfirm(context);
    if (confirmed && context.mounted) {
      await ref.read(staffRequestProvider.notifier).cancelRequest();
    }
  }

  void _showActiveRequestInfo(
      BuildContext context, WidgetRef ref, StaffRequestState state) {
    final request = state.activeRequest!;
    final isAccepted = request.status == StaffRequestStatus.accepted;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAccepted ? 'Nhân viên đang đến' : 'Đang chờ nhân viên'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.category, 'Loại yêu cầu',
                request.requestType.displayName),
            if (request.description != null &&
                request.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.notes, 'Ghi chú', request.description!),
            ],
            if (request.tableNumber != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.table_restaurant, 'Bàn / sân',
                  '${request.tableNumber}'),
            ],
            if (isAccepted && request.acceptedByName != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.person, 'Nhân viên', request.acceptedByName!),
            ],
          ],
        ),
        actions: [
          if (!isAccepted)
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _handleCancelRequest(context, ref);
              },
              child: const Text('Hủy yêu cầu',
                  style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Extracted widgets to avoid rebuild issues ──────────────────────────

class _CallButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: AppColors.primary,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.support_agent,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ActiveRequestChip extends StatelessWidget {
  final StaffRequestState state;
  final VoidCallback onCancel;
  final VoidCallback onShowInfo;

  const _ActiveRequestChip({
    required this.state,
    required this.onCancel,
    required this.onShowInfo,
  });

  @override
  Widget build(BuildContext context) {
    final request = state.activeRequest!;
    final isAccepted = request.status == StaffRequestStatus.accepted;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(26),
      color: isAccepted ? AppColors.success : AppColors.warning,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onShowInfo,
        onLongPress: state.isLoading ? null : onCancel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  isAccepted ? Icons.person : Icons.hourglass_top,
                  color: Colors.white,
                  size: 18,
                ),
              const SizedBox(width: 8),
              Text(
                isAccepted
                    ? '${request.acceptedByName ?? "Nhân viên"} đang đến'
                    : 'Đang chờ nhân viên...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
