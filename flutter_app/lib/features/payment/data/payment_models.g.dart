// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePaymentBody _$CreatePaymentBodyFromJson(Map<String, dynamic> json) =>
    CreatePaymentBody(
      orderId: json['order_id'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      orderType: json['order_type'] as String? ?? 'booking',
    );

Map<String, dynamic> _$CreatePaymentBodyToJson(CreatePaymentBody instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'amount': instance.amount,
      'description': instance.description,
      'order_type': instance.orderType,
    };

CreatePaymentResponse _$CreatePaymentResponseFromJson(
        Map<String, dynamic> json) =>
    CreatePaymentResponse(
      success: json['success'] as bool,
      paymentUrl: json['payment_url'] as String?,
      error: json['error_message'] as String?,
    );

Map<String, dynamic> _$CreatePaymentResponseToJson(
        CreatePaymentResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'payment_url': instance.paymentUrl,
      'error_message': instance.error,
    };

PaymentTransaction _$PaymentTransactionFromJson(Map<String, dynamic> json) =>
    PaymentTransaction(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      vnpTransactionNo: json['vnp_transaction_no'] as String?,
      amount: json['amount'] as int,
      orderType: json['order_type'] as String,
      status: $enumDecode(_$PaymentStatusEnumMap, json['status']),
      responseCode: json['response_code'] as String?,
      bankCode: json['bank_code'] as String?,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentTransactionToJson(PaymentTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'vnp_transaction_no': instance.vnpTransactionNo,
      'amount': instance.amount,
      'order_type': instance.orderType,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'response_code': instance.responseCode,
      'bank_code': instance.bankCode,
      'paid_at': instance.paidAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.completed: 'completed',
  PaymentStatus.failed: 'failed',
};
