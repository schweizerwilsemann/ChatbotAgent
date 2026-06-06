// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffChatMessage _$StaffChatMessageFromJson(Map<String, dynamic> json) =>
    StaffChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderRole: json['sender_role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$StaffChatMessageToJson(StaffChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'room_id': instance.roomId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'sender_role': instance.senderRole,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
    };

StaffChatRoomInfo _$StaffChatRoomInfoFromJson(Map<String, dynamic> json) =>
    StaffChatRoomInfo(
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      staffId: json['staff_id'] as String,
      staffName: json['staff_name'] as String?,
      venueId: json['venue_id'] as String?,
      resourceLabel: json['resource_label'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$StaffChatRoomInfoToJson(StaffChatRoomInfo instance) =>
    <String, dynamic>{
      'request_id': instance.requestId,
      'user_id': instance.userId,
      'user_name': instance.userName,
      'staff_id': instance.staffId,
      'staff_name': instance.staffName,
      'venue_id': instance.venueId,
      'resource_label': instance.resourceLabel,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
    };
