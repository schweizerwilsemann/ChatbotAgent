import 'package:json_annotation/json_annotation.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';

part 'booking_models.g.dart';

/// Court type enum
enum CourtType {
  @JsonValue('billiards')
  billiards,
  @JsonValue('pickleball')
  pickleball,
  @JsonValue('badminton')
  badminton,
}

extension CourtTypeExtension on CourtType {
  String get displayName {
    switch (this) {
      case CourtType.billiards:
        return 'Bida';
      case CourtType.pickleball:
        return 'Pickleball';
      case CourtType.badminton:
        return 'Cầu lông';
    }
  }

  String get emoji {
    switch (this) {
      case CourtType.billiards:
        return '🎱';
      case CourtType.pickleball:
        return '🏓';
      case CourtType.badminton:
        return '🏸';
    }
  }
}

/// Booking status enum
enum BookingStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('completed')
  completed,
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Chờ xác nhận';
      case BookingStatus.confirmed:
        return 'Đã xác nhận';
      case BookingStatus.cancelled:
        return 'Đã hủy';
      case BookingStatus.completed:
        return 'Hoàn thành';
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Booking {
  final String id;
  final String userId;
  final String? venueId;
  final String? resourceId;
  final String? resourceLabel;
  final CourtType courtType;
  final int courtNumber;
  final DateTime date;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final String paymentStatus;
  final double? totalPrice;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.userId,
    this.venueId,
    this.resourceId,
    this.resourceLabel,
    required this.courtType,
    required this.courtNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.totalPrice,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);

  Map<String, dynamic> toJson() => _$BookingToJson(this);

  bool get isPaid => paymentStatus.startsWith('paid');

  Booking copyWith({
    String? id,
    String? userId,
    String? venueId,
    String? resourceId,
    String? resourceLabel,
    CourtType? courtType,
    int? courtNumber,
    DateTime? date,
    String? startTime,
    String? endTime,
    BookingStatus? status,
    String? paymentStatus,
    double? totalPrice,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      venueId: venueId ?? this.venueId,
      resourceId: resourceId ?? this.resourceId,
      resourceLabel: resourceLabel ?? this.resourceLabel,
      courtType: courtType ?? this.courtType,
      courtNumber: courtNumber ?? this.courtNumber,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BookingBill {
  final Booking booking;
  final List<Order> orders;
  final double orderTotal;
  final double? bookingTotal;
  final double grandTotal;

  const BookingBill({
    required this.booking,
    required this.orders,
    required this.orderTotal,
    this.bookingTotal,
    required this.grandTotal,
  });

  factory BookingBill.fromJson(Map<String, dynamic> json) {
    return BookingBill(
      booking: Booking.fromJson(json['booking'] as Map<String, dynamic>),
      orders: (json['orders'] as List<dynamic>? ?? const [])
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList(),
      orderTotal: _billToDouble(json['order_total']),
      bookingTotal: json['booking_total'] == null
          ? null
          : _billToDouble(json['booking_total']),
      grandTotal: _billToDouble(json['grand_total']),
    );
  }
}

@JsonSerializable()
class BookingCreate {
  final String? venueId;
  final String? resourceId;
  final String? resourceLabel;
  final CourtType courtType;
  final int courtNumber;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? notes;
  final String? userId;

  const BookingCreate({
    this.venueId,
    this.resourceId,
    this.resourceLabel,
    required this.courtType,
    required this.courtNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.userId,
  });

  factory BookingCreate.fromJson(Map<String, dynamic> json) =>
      _$BookingCreateFromJson(json);

  /// Custom toJson that sends date as yyyy-MM-dd (no time) and notes as
  /// empty string instead of null, matching the backend Pydantic schema.
  Map<String, dynamic> toJson() {
    final d = date;
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return <String, dynamic>{
      'court_type': _$CourtTypeEnumMap[courtType]!,
      'venue_id': venueId,
      'resource_id': resourceId,
      'resource_label': resourceLabel,
      'court_number': courtNumber,
      'date': dateStr,
      'start_time': startTime,
      'end_time': endTime,
      'notes': notes ?? '',
      'user_id': userId,
    };
  }
}

double _billToDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

@JsonSerializable()
class BookingUpdate {
  final String? startTime;
  final String? endTime;
  final BookingStatus? status;
  final String? notes;

  const BookingUpdate({this.startTime, this.endTime, this.status, this.notes});

  factory BookingUpdate.fromJson(Map<String, dynamic> json) =>
      _$BookingUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$BookingUpdateToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isAvailable;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) =>
      _$TimeSlotFromJson(json);

  Map<String, dynamic> toJson() => _$TimeSlotToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AvailabilityResponse {
  final CourtType courtType;
  final DateTime date;
  final List<TimeSlot> slots;
  final List<int> availableCourts;

  const AvailabilityResponse({
    required this.courtType,
    required this.date,
    required this.slots,
    required this.availableCourts,
  });

  factory AvailabilityResponse.fromJson(Map<String, dynamic> json) =>
      _$AvailabilityResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AvailabilityResponseToJson(this);
}
