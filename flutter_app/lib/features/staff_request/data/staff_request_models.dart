import 'package:json_annotation/json_annotation.dart';

part 'staff_request_models.g.dart';

enum StaffRequestType {
  @JsonValue('order')
  order,
  @JsonValue('payment')
  payment,
  @JsonValue('help')
  help,
  @JsonValue('maintenance')
  maintenance,
  @JsonValue('other')
  other,
}

extension StaffRequestTypeExtension on StaffRequestType {
  String get displayName {
    switch (this) {
      case StaffRequestType.order:
        return 'Gọi đồ uống / thức ăn';
      case StaffRequestType.payment:
        return 'Thanh toán';
      case StaffRequestType.help:
        return 'Hỗ trợ chung';
      case StaffRequestType.maintenance:
        return 'Sự cố kỹ thuật';
      case StaffRequestType.other:
        return 'Yêu cầu khác';
    }
  }

  String get emoji {
    switch (this) {
      case StaffRequestType.order:
        return '🍽️';
      case StaffRequestType.payment:
        return '💳';
      case StaffRequestType.help:
        return '🙋';
      case StaffRequestType.maintenance:
        return '🔧';
      case StaffRequestType.other:
        return '📋';
    }
  }
}

enum StaffRequestStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

extension StaffRequestStatusExtension on StaffRequestStatus {
  String get displayName {
    switch (this) {
      case StaffRequestStatus.pending:
        return 'Đang chờ';
      case StaffRequestStatus.accepted:
        return 'Đã tiếp nhận';
      case StaffRequestStatus.completed:
        return 'Hoàn thành';
      case StaffRequestStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffRequest {
  final String id;
  final String userId;
  final String? userName;
  final StaffRequestType requestType;
  final String? description;
  final int? tableNumber;
  final StaffRequestStatus status;
  final String? acceptedBy;
  final String? acceptedByName;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const StaffRequest({
    required this.id,
    required this.userId,
    this.userName,
    required this.requestType,
    this.description,
    this.tableNumber,
    required this.status,
    this.acceptedBy,
    this.acceptedByName,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory StaffRequest.fromJson(Map<String, dynamic> json) =>
      _$StaffRequestFromJson(json);

  Map<String, dynamic> toJson() => _$StaffRequestToJson(this);

  StaffRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    StaffRequestType? requestType,
    String? description,
    int? tableNumber,
    StaffRequestStatus? status,
    String? acceptedBy,
    String? acceptedByName,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return StaffRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      requestType: requestType ?? this.requestType,
      description: description ?? this.description,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffRequestCreate {
  final StaffRequestType requestType;
  final String? description;
  final int? tableNumber;

  const StaffRequestCreate({
    required this.requestType,
    this.description,
    this.tableNumber,
  });

  factory StaffRequestCreate.fromJson(Map<String, dynamic> json) =>
      _$StaffRequestCreateFromJson(json);

  Map<String, dynamic> toJson() => _$StaffRequestCreateToJson(this);
}
