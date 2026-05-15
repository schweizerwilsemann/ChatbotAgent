// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_request_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffRequest _$StaffRequestFromJson(Map<String, dynamic> json) => StaffRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      requestType: $enumDecode(_$StaffRequestTypeEnumMap, json['request_type']),
      description: json['description'] as String?,
      tableNumber: json['table_number'] as int?,
      status: $enumDecode(_$StaffRequestStatusEnumMap, json['status']),
      acceptedBy: json['accepted_by'] as String?,
      acceptedByName: json['accepted_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );

Map<String, dynamic> _$StaffRequestToJson(StaffRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'user_name': instance.userName,
      'request_type': _$StaffRequestTypeEnumMap[instance.requestType]!,
      'description': instance.description,
      'table_number': instance.tableNumber,
      'status': _$StaffRequestStatusEnumMap[instance.status]!,
      'accepted_by': instance.acceptedBy,
      'accepted_by_name': instance.acceptedByName,
      'created_at': instance.createdAt.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
    };

const _$StaffRequestTypeEnumMap = {
  StaffRequestType.order: 'order',
  StaffRequestType.payment: 'payment',
  StaffRequestType.help: 'help',
  StaffRequestType.maintenance: 'maintenance',
  StaffRequestType.other: 'other',
};

const _$StaffRequestStatusEnumMap = {
  StaffRequestStatus.pending: 'pending',
  StaffRequestStatus.accepted: 'accepted',
  StaffRequestStatus.completed: 'completed',
  StaffRequestStatus.cancelled: 'cancelled',
};

StaffRequestCreate _$StaffRequestCreateFromJson(Map<String, dynamic> json) =>
    StaffRequestCreate(
      requestType: $enumDecode(_$StaffRequestTypeEnumMap, json['request_type']),
      description: json['description'] as String?,
      tableNumber: json['table_number'] as int?,
    );

Map<String, dynamic> _$StaffRequestCreateToJson(StaffRequestCreate instance) =>
    <String, dynamic>{
      'request_type': _$StaffRequestTypeEnumMap[instance.requestType]!,
      'description': instance.description,
      'table_number': instance.tableNumber,
    };
