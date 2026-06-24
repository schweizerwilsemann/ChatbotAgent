import 'package:flutter/material.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.parse(v);
  throw FormatException('Expected num or String, got ${v.runtimeType}');
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw FormatException('Expected num or String, got ${v.runtimeType}');
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.parse(v as String);
}

// ─── Partner Store ─────────────────────────────────────────────────────────

class PartnerStore {
  final String id;
  final String ownerUserId;
  final String? venueId;
  final String name;
  final String description;
  final String category;
  final String? logoUrl;
  final String? phone;
  final String? address;
  final String status;
  final bool isOpen;
  final double rating;
  final int totalOrders;
  final double deliveryFee;
  final int estimatedDeliveryMinutes;
  final DateTime? createdAt;

  const PartnerStore({
    required this.id,
    required this.ownerUserId,
    this.venueId,
    required this.name,
    this.description = '',
    this.category = 'food',
    this.logoUrl,
    this.phone,
    this.address,
    this.status = 'active',
    this.isOpen = true,
    this.rating = 5.0,
    this.totalOrders = 0,
    this.deliveryFee = 15000,
    this.estimatedDeliveryMinutes = 20,
    this.createdAt,
  });

  factory PartnerStore.fromJson(Map<String, dynamic> json) {
    return PartnerStore(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      venueId: json['venue_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'food',
      logoUrl: json['logo_url'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      status: json['status'] as String? ?? 'active',
      isOpen: json['is_open'] as bool? ?? true,
      rating: _toDouble(json['rating']),
      totalOrders: _toInt(json['total_orders']),
      deliveryFee: _toDouble(json['delivery_fee']),
      estimatedDeliveryMinutes: _toInt(json['estimated_delivery_minutes']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  PartnerStore copyWith({
    String? name,
    String? description,
    String? category,
    String? logoUrl,
    String? phone,
    String? address,
    bool? isOpen,
    double? deliveryFee,
    int? estimatedDeliveryMinutes,
  }) {
    return PartnerStore(
      id: id,
      ownerUserId: ownerUserId,
      venueId: venueId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      logoUrl: logoUrl ?? this.logoUrl,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      status: status,
      isOpen: isOpen ?? this.isOpen,
      rating: rating,
      totalOrders: totalOrders,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      estimatedDeliveryMinutes:
          estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      createdAt: createdAt,
    );
  }
}

// ─── Partner Menu Item ─────────────────────────────────────────────────────

class PartnerMenuItem {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final int salesCount;
  final DateTime? createdAt;

  const PartnerMenuItem({
    required this.id,
    required this.storeId,
    required this.name,
    this.description = '',
    required this.price,
    this.category = 'food',
    this.imageUrl,
    this.isAvailable = true,
    this.salesCount = 0,
    this.createdAt,
  });

  factory PartnerMenuItem.fromJson(Map<String, dynamic> json) {
    return PartnerMenuItem(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: _toDouble(json['price']),
      category: json['category'] as String? ?? 'food',
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      salesCount: _toInt(json['sales_count']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  PartnerMenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return PartnerMenuItem(
      id: id,
      storeId: storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      salesCount: salesCount,
      createdAt: createdAt,
    );
  }
}

// ─── Partner Order Item ────────────────────────────────────────────────────

class PartnerOrderItem {
  final String id;
  final String itemName;
  final int quantity;
  final double unitPrice;

  const PartnerOrderItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => unitPrice * quantity;

  factory PartnerOrderItem.fromJson(Map<String, dynamic> json) {
    return PartnerOrderItem(
      id: json['id'] as String,
      itemName: json['item_name'] as String,
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
    );
  }
}

// ─── Partner Order ─────────────────────────────────────────────────────────

enum PartnerOrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  delivering,
  delivered,
  cancelled;

  String get displayName {
    switch (this) {
      case PartnerOrderStatus.pending:
        return 'Chờ xử lý';
      case PartnerOrderStatus.accepted:
        return 'Đã nhận';
      case PartnerOrderStatus.preparing:
        return 'Đang chuẩn bị';
      case PartnerOrderStatus.ready:
        return 'Sẵn sàng';
      case PartnerOrderStatus.delivering:
        return 'Đang giao';
      case PartnerOrderStatus.delivered:
        return 'Đã giao';
      case PartnerOrderStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  String get apiValue => name;

  Color get color {
    switch (this) {
      case PartnerOrderStatus.pending:
        return const Color(0xFFF39C12);
      case PartnerOrderStatus.accepted:
        return const Color(0xFF3498DB);
      case PartnerOrderStatus.preparing:
        return const Color(0xFF9B59B6);
      case PartnerOrderStatus.ready:
        return const Color(0xFF27AE60);
      case PartnerOrderStatus.delivering:
        return const Color(0xFF2980B9);
      case PartnerOrderStatus.delivered:
        return const Color(0xFF27AE60);
      case PartnerOrderStatus.cancelled:
        return const Color(0xFFE74C3C);
    }
  }

  List<PartnerOrderStatus> get validNextTransitions {
    switch (this) {
      case PartnerOrderStatus.pending:
        return [PartnerOrderStatus.accepted, PartnerOrderStatus.cancelled];
      case PartnerOrderStatus.accepted:
        return [PartnerOrderStatus.preparing, PartnerOrderStatus.cancelled];
      case PartnerOrderStatus.preparing:
        return [PartnerOrderStatus.ready, PartnerOrderStatus.cancelled];
      case PartnerOrderStatus.ready:
        return [PartnerOrderStatus.delivering];
      case PartnerOrderStatus.delivering:
        return [PartnerOrderStatus.delivered];
      default:
        return [];
    }
  }
}

PartnerOrderStatus _parsePartnerOrderStatus(String value) {
  return PartnerOrderStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PartnerOrderStatus.pending,
  );
}

class PartnerOrder {
  final String id;
  final String? storeId;
  final String? storeName;
  final String customerUserId;
  final String? customerName;
  final String? customerPhone;
  final String? venueId;
  final String? deliveryLocation;
  final PartnerOrderStatus status;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double totalPrice;
  final String? notes;
  final List<PartnerOrderItem> items;
  final DateTime? createdAt;

  const PartnerOrder({
    required this.id,
    this.storeId,
    this.storeName,
    required this.customerUserId,
    this.customerName,
    this.customerPhone,
    this.venueId,
    this.deliveryLocation,
    required this.status,
    this.paymentStatus = 'unpaid',
    required this.subtotal,
    required this.deliveryFee,
    required this.totalPrice,
    this.notes,
    this.items = const [],
    this.createdAt,
  });

  factory PartnerOrder.fromJson(Map<String, dynamic> json) {
    return PartnerOrder(
      id: json['id'] as String,
      storeId: json['store_id'] as String?,
      storeName: json['store_name'] as String?,
      customerUserId: json['customer_user_id'] as String,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      venueId: json['venue_id'] as String?,
      deliveryLocation: json['delivery_location'] as String?,
      status: _parsePartnerOrderStatus(json['status'] as String),
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['delivery_fee']),
      totalPrice: _toDouble(json['total_price']),
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PartnerOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  PartnerOrder copyWith({
    PartnerOrderStatus? status,
    String? paymentStatus,
  }) {
    return PartnerOrder(
      id: id,
      storeId: storeId,
      storeName: storeName,
      customerUserId: customerUserId,
      customerName: customerName,
      customerPhone: customerPhone,
      venueId: venueId,
      deliveryLocation: deliveryLocation,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
      notes: notes,
      items: items,
      createdAt: createdAt,
    );
  }
}

// ─── Create / Update DTOs ──────────────────────────────────────────────────

class PartnerMenuItemCreateData {
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;

  const PartnerMenuItemCreateData({
    required this.name,
    this.description = '',
    required this.price,
    this.category = 'food',
    this.imageUrl,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'image_url': imageUrl,
        'is_available': isAvailable,
      };
}

class PartnerMenuItemUpdateData {
  final String? name;
  final String? description;
  final double? price;
  final String? category;
  final String? imageUrl;
  final bool? isAvailable;

  const PartnerMenuItemUpdateData({
    this.name,
    this.description,
    this.price,
    this.category,
    this.imageUrl,
    this.isAvailable,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (price != null) map['price'] = price;
    if (category != null) map['category'] = category;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (isAvailable != null) map['is_available'] = isAvailable;
    return map;
  }
}
