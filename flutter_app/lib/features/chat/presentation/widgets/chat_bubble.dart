import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';
import 'package:sports_venue_chatbot/shared/utils/date_utils.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_buildAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.userBubble : AppColors.botBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isUser
                        ? null
                        : Border.all(
                            color: AppColors.botBubbleBorder,
                            width: 1,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isUser
                          ? SelectableText(
                              message.content,
                              style: const TextStyle(
                                color: AppColors.userBubbleText,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            )
                          : MarkdownBody(
                              data: message.content,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                strong: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                em: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                                listBullet: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 15,
                                ),
                                code: TextStyle(
                                  backgroundColor: AppColors.botBubbleBorder
                                      .withOpacity(0.3),
                                  color: AppColors.botBubbleText,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: AppColors.botBubbleBorder
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                h1: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                h2: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                h3: const TextStyle(
                                  color: AppColors.botBubbleText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      if (message.toolsUsed != null &&
                          message.toolsUsed!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildToolBadges(),
                      ],
                    ],
                  ),
                ),
                if (showTimestamp) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      VietnameseDateUtils.formatTime(message.timestamp),
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _buildAvatar()],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: message.isUser ? AppColors.secondary : AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        message.isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildToolBadges() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: message.toolsUsed!.map((tool) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getToolColor(tool).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getToolColor(tool).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getToolIcon(tool), size: 12, color: _getToolColor(tool)),
              const SizedBox(width: 4),
              Text(
                _getToolLabel(tool),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getToolColor(tool),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getToolColor(String tool) {
    switch (tool.toLowerCase()) {
      case 'booking':
      case 'create_booking':
      case 'check_availability':
        return AppColors.toolBadgeText;
      case 'menu':
      case 'get_menu':
      case 'search_menu':
        return AppColors.secondary;
      case 'order':
      case 'create_order':
      case 'notify_staff':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _getToolIcon(String tool) {
    switch (tool.toLowerCase()) {
      case 'booking':
      case 'create_booking':
      case 'check_availability':
        return Icons.calendar_month;
      case 'menu':
      case 'get_menu':
      case 'search_menu':
        return Icons.restaurant_menu;
      case 'order':
      case 'create_order':
        return Icons.shopping_cart;
      case 'notify_staff':
        return Icons.notifications_active;
      default:
        return Icons.build;
    }
  }

  String _getToolLabel(String tool) {
    switch (tool.toLowerCase()) {
      case 'booking':
      case 'create_booking':
        return 'Đặt sân';
      case 'check_availability':
        return 'Kiểm tra';
      case 'menu':
      case 'get_menu':
      case 'search_menu':
        return 'Thực đơn';
      case 'order':
      case 'create_order':
        return 'Đặt hàng';
      case 'notify_staff':
        return 'Thông báo';
      default:
        return tool;
    }
  }
}

/// Typing indicator widget shown when AI is processing
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: -8,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.botBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.botBubbleBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _animations[index].value),
                      child: child,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
