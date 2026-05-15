// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Booking _$BookingFromJson(Map<String, dynamic> json) => Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courtType: $enumDecode(_$CourtTypeEnumMap, json['court_type']),
      courtNumber: json['court_number'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$BookingToJson(Booking instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'court_type': _$CourtTypeEnumMap[instance.courtType]!,
      'court_number': instance.courtNumber,
      'date': instance.date.toIso8601String(),
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'total_price': instance.totalPrice,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$CourtTypeEnumMap = {
  CourtType.billiards: 'billiards',
  CourtType.pickleball: 'pickleball',
  CourtType.badminton: 'badminton',
};

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'pending',
  BookingStatus.confirmed: 'confirmed',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.completed: 'completed',
};

BookingCreate _$BookingCreateFromJson(Map<String, dynamic> json) =>
    BookingCreate(
      courtType: $enumDecode(_$CourtTypeEnumMap, json['courtType']),
      courtNumber: json['courtNumber'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      notes: json['notes'] as String?,
      userId: json['userId'] as String?,
    );

Map<String, dynamic> _$BookingCreateToJson(BookingCreate instance) =>
    <String, dynamic>{
      'courtType': _$CourtTypeEnumMap[instance.courtType]!,
      'courtNumber': instance.courtNumber,
      'date': instance.date.toIso8601String(),
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'notes': instance.notes,
      'userId': instance.userId,
    };

BookingUpdate _$BookingUpdateFromJson(Map<String, dynamic> json) =>
    BookingUpdate(
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      status: $enumDecodeNullable(_$BookingStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$BookingUpdateToJson(BookingUpdate instance) =>
    <String, dynamic>{
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'status': _$BookingStatusEnumMap[instance.status],
      'notes': instance.notes,
    };

TimeSlot _$TimeSlotFromJson(Map<String, dynamic> json) => TimeSlot(
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isAvailable: json['is_available'] as bool,
    );

Map<String, dynamic> _$TimeSlotToJson(TimeSlot instance) => <String, dynamic>{
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'is_available': instance.isAvailable,
    };

AvailabilityResponse _$AvailabilityResponseFromJson(
        Map<String, dynamic> json) =>
    AvailabilityResponse(
      courtType: $enumDecode(_$CourtTypeEnumMap, json['court_type']),
      date: DateTime.parse(json['date'] as String),
      slots: (json['slots'] as List<dynamic>)
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableCourts: (json['available_courts'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
    );

Map<String, dynamic> _$AvailabilityResponseToJson(
        AvailabilityResponse instance) =>
    <String, dynamic>{
      'court_type': _$CourtTypeEnumMap[instance.courtType]!,
      'date': instance.date.toIso8601String(),
      'slots': instance.slots,
      'available_courts': instance.availableCourts,
    };
