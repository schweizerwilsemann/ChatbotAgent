import 'package:json_annotation/json_annotation.dart';

part 'payment_models.g.dart';

enum PaymentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Chờ thanh toán';
      case PaymentStatus.completed:
        return 'Đã thanh toán';
      case PaymentStatus.failed:
        return 'Thanh toán thất bại';
    }
  }
}

@JsonSerializable()
class CreatePaymentBody {
  @JsonKey(name: 'order_id')
  final String orderId;
  final int amount;
  final String description;
  @JsonKey(name: 'order_type')
  final String orderType;

  const CreatePaymentBody({
    required this.orderId,
    required this.amount,
    required this.description,
    this.orderType = 'booking',
  });

  factory CreatePaymentBody.fromJson(Map<String, dynamic> json) =>
      _$CreatePaymentBodyFromJson(json);

  Map<String, dynamic> toJson() => _$CreatePaymentBodyToJson(this);
}

@JsonSerializable()
class CreatePaymentResponse {
  final bool success;
  @JsonKey(name: 'payment_url')
  final String? paymentUrl;
  @JsonKey(name: 'error_message')
  final String? error;

  const CreatePaymentResponse({
    required this.success,
    this.paymentUrl,
    this.error,
  });

  factory CreatePaymentResponse.fromJson(Map<String, dynamic> json) =>
      _$CreatePaymentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreatePaymentResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PaymentTransaction {
  final String id;
  final String orderId;
  final String? vnpTransactionNo;
  final int amount;
  final String orderType;
  final PaymentStatus status;
  final String? responseCode;
  final String? bankCode;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const PaymentTransaction({
    required this.id,
    required this.orderId,
    this.vnpTransactionNo,
    required this.amount,
    required this.orderType,
    required this.status,
    this.responseCode,
    this.bankCode,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      _$PaymentTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentTransactionToJson(this);
}
