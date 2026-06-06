import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/staff_chat/data/staff_chat_api.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

// ── Models ────────────────────────────────────────────────────────────

class StaffChatRoomItem {
  final String requestId;
  final String userId;
  final String userName;
  final String? resourceLabel;
  final String status;
  final DateTime createdAt;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderRole;

  StaffChatRoomItem({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.resourceLabel,
    required this.status,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageTime,
    this.lastMessageSenderRole,
  });

  factory StaffChatRoomItem.fromJson(Map<String, dynamic> json) {
    final lastMsg = json['last_message'] as Map<String, dynamic>?;
    return StaffChatRoomItem(
      requestId: json['request_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Khách hàng',
      resourceLabel: json['resource_label'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastMessageContent: lastMsg?['content'] as String?,
      lastMessageTime: lastMsg?['timestamp'] != null
          ? DateTime.tryParse(lastMsg!['timestamp'] as String)
          : null,
      lastMessageSenderRole: lastMsg?['sender_role'] as String?,
    );
  }

  bool get isActive => status == 'active';
}

// ── Provider ──────────────────────────────────────────────────────────

final staffInboxProvider =
    StateNotifierProvider<StaffInboxNotifier, StaffInboxState>((ref) {
  return StaffInboxNotifier(ref.watch(staffChatApiProvider));
});

class StaffInboxState {
  final List<StaffChatRoomItem> rooms;
  final bool isLoading;
  final String? error;

  const StaffInboxState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  StaffInboxState copyWith({
    List<StaffChatRoomItem>? rooms,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return StaffInboxState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<StaffChatRoomItem> get activeRooms =>
      rooms.where((r) => r.isActive).toList();

  List<StaffChatRoomItem> get closedRooms =>
      rooms.where((r) => !r.isActive).toList();
}

class StaffInboxNotifier extends StateNotifier<StaffInboxState> {
  final StaffChatApi _api;

  StaffInboxNotifier(this._api) : super(const StaffInboxState()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.getMyRooms();
      final rooms =
          data.map((e) => StaffChatRoomItem.fromJson(e)).toList();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách hội thoại.',
      );
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────

class StaffInboxScreen extends ConsumerStatefulWidget {
  const StaffInboxScreen({super.key});

  @override
  ConsumerState<StaffInboxScreen> createState() => _StaffInboxScreenState();
}

class _StaffInboxScreenState extends ConsumerState<StaffInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffInboxProvider);

    ref.listen<StaffInboxState>(staffInboxProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppSnackBar.showError(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(staffInboxProvider.notifier).loadRooms(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Đang hoạt động (${state.activeRooms.length})'),
            Tab(text: 'Đã kết thúc (${state.closedRooms.length})'),
          ],
        ),
      ),
      body: state.isLoading && state.rooms.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _RoomList(
                  rooms: state.activeRooms,
                  emptyMessage: 'Chưa có cuộc trò chuyện nào',
                ),
                _RoomList(
                  rooms: state.closedRooms,
                  emptyMessage: 'Chưa có cuộc trò chuyện đã kết thúc',
                ),
              ],
            ),
    );
  }
}

// ── Room List ─────────────────────────────────────────────────────────

class _RoomList extends ConsumerWidget {
  final List<StaffChatRoomItem> rooms;
  final String emptyMessage;

  const _RoomList({required this.rooms, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(staffInboxProvider.notifier).loadRooms(),
      child: ListView.separated(
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) => _RoomTile(room: rooms[index]),
      ),
    );
  }
}

// ── Room Tile ─────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final StaffChatRoomItem room;

  const _RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(room.lastMessageTime ?? room.createdAt);

    return ListTile(
      onTap: () {
        context.push(
          '/staff-operator-chat/${room.requestId}',
          extra: {
            'customerName': room.userName,
            'resourceLabel': room.resourceLabel,
          },
        );
      },
      leading: CircleAvatar(
        backgroundColor: room.isActive
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.textHint.withValues(alpha: 0.12),
        child: Icon(
          Icons.person,
          color: room.isActive ? AppColors.primary : AppColors.textHint,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.userName.isEmpty ? 'Khách hàng' : room.userName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: room.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (room.isActive)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (room.resourceLabel != null &&
              room.resourceLabel!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              room.resourceLabel!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            room.lastMessageContent != null
                ? '${_senderPrefix(room.lastMessageSenderRole)}${room.lastMessageContent}'
                : 'Chưa có tin nhắn',
            style: TextStyle(
              fontSize: 13,
              color: room.lastMessageContent != null
                  ? AppColors.textSecondary
                  : AppColors.textHint,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Text(
        timeStr,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textHint,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  static String _senderPrefix(String? role) {
    if (role == 'staff') return 'Bạn: ';
    return '';
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(time);
    if (diff.inDays < 7) return DateFormat('E', 'vi').format(time);
    return DateFormat('dd/MM').format(time);
  }
}
