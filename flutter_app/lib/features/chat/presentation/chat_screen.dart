import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/realtime_event_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/chat_provider.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/voice_input_provider.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:sports_venue_chatbot/features/chat/presentation/widgets/voice_input_overlay.dart';
import 'package:sports_venue_chatbot/features/staff_request/presentation/widgets/staff_request_bubble.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_confirm_dialog.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showVoiceOverlay = false;
  StreamSubscription<RealtimeUiEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _startListening();
    });
  }

  void _startListening() {
    final realtimeNotifier = ref.read(realtimeEventProvider.notifier);
    realtimeNotifier.start();
    _realtimeSub = realtimeNotifier.eventStream.listen((event) {
      if (event.type == 'court_status_changed') {
        final bookingId = event.data['booking_id']?.toString();
        final status = event.data['status']?.toString();
        final startTime = event.data['start_time']?.toString();
        final endTime = event.data['end_time']?.toString();
        if (bookingId != null && status != null) {
          debugPrint(
              '[Chat] court_status_changed: booking=$bookingId, status=$status');
          ref.read(chatProvider.notifier).updateBookingStatus(
                bookingId,
                status,
                startTime: startTime,
                endTime: endTime,
              );
        }
      } else if (event.type == 'payment_status_changed') {
        final orderId = event.orderId;
        final paymentStatus = event.data['payment_status']?.toString();
        if (orderId != null && paymentStatus != null) {
          debugPrint(
              '[Chat] payment_status_changed: order=$orderId, status=$paymentStatus');
          ref
              .read(chatProvider.notifier)
              .updatePaymentStatus(orderId, paymentStatus);
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _focusNode.requestFocus();

    ref.read(chatProvider.notifier).sendMessageStream(text);

    // Scroll to bottom after a short delay to allow the message to be added
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authStateProvider);
    final canUseVoiceAgent = _canUseVoiceAgent(authState);

    // Listen for state changes to auto-scroll
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.streamingContent != next.streamingContent) {
        _scrollToBottom();
      }

      // Show error as snackbar
      if (next.error != null && next.error != previous?.error) {
        AppSnackBar.showError(
          context,
          next.error!,
          actionLabel: 'Thử lại',
          onAction: () => ref.read(chatProvider.notifier).retryLastMessage(),
        );
        ref.read(chatProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sports Venue AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    chatState.isLoading || chatState.isStreaming
                        ? 'Đang trả lời...'
                        : 'Trực tuyến',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canUseVoiceAgent)
            IconButton(
              icon: const Icon(Icons.phone_in_talk),
              tooltip: 'Gọi Mimo',
              onPressed: _openVoiceAgentCall,
            ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_comment),
              tooltip: 'Cuộc trò chuyện mới',
              onPressed: () {
                _showNewChatDialog();
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'new_chat':
                  _showNewChatDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.add_comment, size: 20),
                    SizedBox(width: 8),
                    Text('Cuộc trò chuyện mới'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages list
              Expanded(
                child: chatState.messages.isEmpty && !chatState.isLoading
                    ? _buildWelcomeScreen()
                    : _buildMessagesList(chatState),
              ),

              // Input area
              _buildInputArea(chatState),
            ],
          ),

          // Call staff floating bubble
          const Positioned(
            right: 16,
            bottom: 80,
            child: StaffRequestBubble(),
          ),

          // Voice input overlay
          if (_showVoiceOverlay)
            Positioned.fill(
              child: VoiceInputOverlay(
                onClose: _closeVoiceOverlay,
                onTextReady: _onVoiceTextReady,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ResponsiveContainer(
          maxWidth: 500,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_tennis,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Chào mừng bạn!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tôi là trợ lý AI của câu lạc bộ thể thao.\nHỏi tôi bất cứ điều gì!',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              // On tablet, show suggestion chips in a 2-column Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('🎱 Kiểm tra sân bida trống'),
                  _buildSuggestionChip('🏸 Đặt sân cầu lông chiều nay'),
                  _buildSuggestionChip('🏓 Xem thực đơn đồ uống'),
                  _buildSuggestionChip('📋 Đặt bàn bida số 3 lúc 19h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _textController.text = text;
        _handleSend();
      },
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.divider),
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildMessagesList(ChatState chatState) {
    final messageCount = chatState.messages.length +
        (chatState.isLoading ? 1 : 0) +
        (chatState.isStreaming && chatState.streamingContent.isEmpty ? 1 : 0) +
        (chatState.isStreaming && chatState.streamingContent.isNotEmpty
            ? 1
            : 0);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messageCount,
          itemBuilder: (context, index) {
            if (index < chatState.messages.length) {
              return ChatBubble(
                message: chatState.messages[index],
                key: ValueKey(chatState.messages[index].id),
                onPaymentStatusChanged: (orderId, status) {
                  ref
                      .read(chatProvider.notifier)
                      .updatePaymentStatus(orderId, status);
                },
              );
            }

            // Show streaming content in a bubble
            if (chatState.isStreaming &&
                chatState.streamingContent.isNotEmpty) {
              return ChatBubble(
                message: ChatMessage(
                  id: 'streaming',
                  role: 'assistant',
                  content: chatState.streamingContent,
                  timestamp: DateTime.now(),
                ),
                showTimestamp: false,
                isStreaming: true,
              );
            }

            // Show typing indicator when loading or streaming with no content yet
            if (chatState.isLoading ||
                (chatState.isStreaming && chatState.streamingContent.isEmpty)) {
              return const TypingIndicator();
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatState chatState) {
    final isLoading = chatState.isLoading || chatState.isStreaming;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: !isLoading,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: isLoading
                              ? 'Đang chờ phản hồi...'
                              : 'Nhập tin nhắn...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLoading ? AppColors.textHint : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  isLoading
                      ? Icons.hourglass_empty
                      : (_textController.text.trim().isEmpty
                          ? Icons.mic
                          : Icons.send),
                  color: AppColors.textOnPrimary,
                  size: 20,
                ),
                onPressed: isLoading
                    ? null
                    : (_textController.text.trim().isEmpty
                        ? _openVoiceOverlay
                        : _handleSend),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVoiceOverlay() {
    setState(() => _showVoiceOverlay = true);
    _focusNode.unfocus();
  }

  void _closeVoiceOverlay() {
    ref.read(voiceInputProvider.notifier).cancelListening();
    setState(() => _showVoiceOverlay = false);
  }

  void _onVoiceTextReady(String text) {
    setState(() => _showVoiceOverlay = false);
    if (text.isNotEmpty) {
      _textController.text = text;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
      _focusNode.requestFocus();
    }
  }

  void _showNewChatDialog() async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: 'Cuộc trò chuyện mới',
      content:
          'Bạn có muốn bắt đầu cuộc trò chuyện mới?\nLịch sử chat hiện tại sẽ bị xóa.',
      confirmLabel: 'Tạo mới',
    );
    if (confirmed == true && mounted) {
      ref.read(chatProvider.notifier).clearChat();
    }
  }

  void _openVoiceAgentCall() {
    if (!mounted || !_canUseVoiceAgent(ref.read(authStateProvider))) return;

    _focusNode.unfocus();
    context.push('/voice-agent');
  }

  bool _canUseVoiceAgent(AsyncValue<dynamic> authState) {
    final role = authState.valueOrNull?.role.toString().toUpperCase();
    return role != null && role != 'ADMIN' && role != 'STAFF';
  }
}
