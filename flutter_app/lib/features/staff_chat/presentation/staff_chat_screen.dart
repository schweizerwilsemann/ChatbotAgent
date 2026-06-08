import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_overlay.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_api.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_chat_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/widgets/staff_chat_bubble.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/widgets/staff_chat_input.dart';
import 'package:sports_venue_chatbot/features/staff_request/domain/staff_request_repository.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class StaffChatScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String? customerName;
  final String? resourceLabel;
  final String? customerId;

  const StaffChatScreen({
    super.key,
    required this.requestId,
    this.customerName,
    this.resourceLabel,
    this.customerId,
  });

  @override
  ConsumerState<StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends ConsumerState<StaffChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initiateCall() async {
    final room = await _getRoomInfo();
    final customerId = widget.customerId ?? room?['user_id'] as String? ?? '';

    if (customerId.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(context, 'Không tìm thấy khách hàng');
      }
      return;
    }

    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'auth_token') ?? '';

    await ref.read(callProvider.notifier).startCall(
          roomId: widget.requestId,
          calleeId: customerId,
          token: token,
        );
  }

  Future<Map<String, dynamic>?> _getRoomInfo() async {
    try {
      final api = ref.read(staffChatApiProvider);
      final rooms = await api.getMyRooms();
      for (final room in rooms) {
        if (room['request_id'] == widget.requestId) {
          return room;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(staffChatProvider(widget.requestId));
    final callState = ref.watch(callProvider);

    ref.listen<StaffChatState>(staffChatProvider(widget.requestId), (_, next) {
      if (next.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customerName ?? 'Khách hàng',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                if (widget.resourceLabel != null) ...[
                  const Icon(Icons.location_on,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      widget.resourceLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chatState.isOtherOnline
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    chatState.isRoomClosed
                        ? 'Đã kết thúc'
                        : chatState.isOtherOnline
                            ? 'Đang trực tuyến'
                            : 'Ngoại tuyến',
                    style: TextStyle(
                      fontSize: 11,
                      color: chatState.isRoomClosed
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!chatState.isRoomClosed)
            CallButton(
              enabled: !callState.isActive && chatState.isOtherOnline,
              onPressed: _initiateCall,
            ),
          if (!chatState.isRoomClosed)
            TextButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Hoàn thành'),
              style: TextButton.styleFrom(foregroundColor: AppColors.success),
              onPressed: () => _completeRequest(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.isRoomClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.warning.withValues(alpha: 0.12),
              child: const Text(
                'Cuộc trò chuyện đã kết thúc',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: chatState.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Bắt đầu trò chuyện với khách hàng',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isMine = msg.senderRole == 'staff';
                      return StaffChatBubble(
                        message: msg,
                        isMine: isMine,
                      );
                    },
                  ),
          ),
          if (chatState.isOtherTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Đang nhập...',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          StaffChatInput(
            enabled: !chatState.isRoomClosed,
            onSend: (text) {
              ref
                  .read(staffChatProvider(widget.requestId).notifier)
                  .sendMessage(text);
            },
            onTyping: () {
              ref
                  .read(staffChatProvider(widget.requestId).notifier)
                  .sendTyping();
            },
          ),
        ],
      ),
    );
  }

  void _completeRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn thành yêu cầu'),
        content: const Text(
            'Xác nhận đã phục vụ xong? Cuộc trò chuyện sẽ kết thúc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(staffChatApiProvider).closeRoom(widget.requestId);
        try {
          await ref
              .read(staffRequestRepositoryProvider)
              .completeRequest(widget.requestId);
        } catch (_) {
          // Request may already be completed — ignore
        }
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Đã hoàn thành yêu cầu.');
        }
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(context, 'Không thể hoàn thành.');
        }
      }
    }
  }
}
