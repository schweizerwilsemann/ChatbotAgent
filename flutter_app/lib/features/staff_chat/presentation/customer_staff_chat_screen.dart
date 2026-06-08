import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/domain/auth_repository.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_overlay.dart';
import 'package:sports_venue_chatbot/features/call/presentation/call_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/staff_chat_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/widgets/staff_chat_bubble.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/widgets/staff_chat_input.dart';

class CustomerStaffChatScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String? staffName;
  final String? staffId;

  const CustomerStaffChatScreen({
    super.key,
    required this.requestId,
    this.staffName,
    this.staffId,
  });

  @override
  ConsumerState<CustomerStaffChatScreen> createState() =>
      _CustomerStaffChatScreenState();
}

class _CustomerStaffChatScreenState
    extends ConsumerState<CustomerStaffChatScreen> {
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
    final staffId = widget.staffId ?? '';

    if (staffId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy nhân viên')),
        );
      }
      return;
    }

    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'auth_token') ?? '';

    await ref.read(callProvider.notifier).startCall(
          roomId: widget.requestId,
          calleeId: staffId,
          token: token,
        );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(staffChatProvider(widget.requestId));
    final callState = ref.watch(callProvider);

    ref.listen<StaffChatState>(staffChatProvider(widget.requestId), (_, next) {
      if (next.messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.staffName ?? 'Nhân viên',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
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
                Text(
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
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Đóng chat',
              onPressed: () => _showCloseDialog(),
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
                      'Bắt đầu trò chuyện với nhân viên',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isMine = msg.senderRole == 'customer';
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

  void _showCloseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đóng chat'),
        content: const Text('Bạn có muốn đóng cuộc trò chuyện này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
