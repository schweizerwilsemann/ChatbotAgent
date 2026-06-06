import 'package:json_annotation/json_annotation.dart';

part 'staff_chat_models.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String senderRole; // "customer" | "staff"
  final String content;
  final DateTime timestamp;

  const StaffChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.timestamp,
  });

  factory StaffChatMessage.fromJson(Map<String, dynamic> json) =>
      _$StaffChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$StaffChatMessageToJson(this);

  bool get isFromStaff => senderRole == 'staff';
  bool get isFromCustomer => senderRole == 'customer';
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffChatRoomInfo {
  final String requestId;
  final String userId;
  final String? userName;
  final String staffId;
  final String? staffName;
  final String? venueId;
  final String? resourceLabel;
  final String status; // "active" | "closed"
  final DateTime createdAt;

  const StaffChatRoomInfo({
    required this.requestId,
    required this.userId,
    this.userName,
    required this.staffId,
    this.staffName,
    this.venueId,
    this.resourceLabel,
    required this.status,
    required this.createdAt,
  });

  factory StaffChatRoomInfo.fromJson(Map<String, dynamic> json) =>
      _$StaffChatRoomInfoFromJson(json);

  Map<String, dynamic> toJson() => _$StaffChatRoomInfoToJson(this);

  bool get isActive => status == 'active';
}
