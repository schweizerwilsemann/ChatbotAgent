import 'package:json_annotation/json_annotation.dart';

part 'menu_models.g.dart';

/// Menu item model
@JsonSerializable(fieldRename: FieldRename.snake)
class MenuItem {
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;

  const MenuItem({
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
  });

  /// Custom fromJson that handles the backend serializing Decimal as a String.
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final double price;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      price = double.parse(rawPrice);
    } else {
      throw FormatException('Unexpected price type: ${rawPrice.runtimeType}');
    }

    return MenuItem(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: price,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => _$MenuItemToJson(this);
}

/// Menu category containing a list of items
@JsonSerializable(fieldRename: FieldRename.snake)
class MenuCategory {
  final String name;
  final List<MenuItem> items;

  const MenuCategory({required this.name, required this.items});

  factory MenuCategory.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$MenuCategoryToJson(this);
}

/// Order item for creating an order
@JsonSerializable(fieldRename: FieldRename.snake)
class OrderItemCreate {
  final String itemName;
  final int quantity;
  final double unitPrice;

  const OrderItemCreate({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItemCreate.fromJson(Map<String, dynamic> json) =>
      _$OrderItemCreateFromJson(json);

  /// Only send item_name and quantity — the backend calculates unit_price
  /// from the menu automatically.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'item_name': itemName,
      'quantity': quantity,
    };
  }
}

/// Safely convert a JSON value (num or String) to double.
/// Handles the backend Pydantic Decimal → String serialization.
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.parse(v);
  throw FormatException('Expected num or String, got ${v.runtimeType}');
}

/// Order item returned from the API
@JsonSerializable(fieldRename: FieldRename.snake)
class OrderItem {
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: _toDouble(json['unit_price']),
      totalPrice: _toDouble(json['total_price']),
    );
  }

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}

/// Order creation request
@JsonSerializable(fieldRename: FieldRename.snake)
class OrderCreate {
  final String userId;
  final int tableNumber;
  final List<OrderItemCreate> items;
  final String? bookingId;
  final String? notes;

  const OrderCreate({
    required this.userId,
    this.tableNumber = 0,
    required this.items,
    this.bookingId,
    this.notes,
  });

  factory OrderCreate.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateFromJson(json);

  /// Custom toJson that properly serializes [items] to JSON maps and
  /// sends empty string instead of null for notes.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'table_number': tableNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes ?? '',
    };
  }
}

/// Order status enum
enum OrderStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('preparing')
  preparing,
  @JsonValue('ready')
  ready,
  @JsonValue('delivered')
  delivered,
  @JsonValue('cancelled')
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Chờ xử lý';
      case OrderStatus.preparing:
        return 'Đang chuẩn bị';
      case OrderStatus.ready:
        return 'Sẵn sàng';
      case OrderStatus.delivered:
        return 'Đã giao';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

/// Order returned from the API
@JsonSerializable(fieldRename: FieldRename.snake)
class Order {
  final String id;
  final List<OrderItem> items;
  final double totalPrice;
  final OrderStatus status;
  final String? notes;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPrice: _toDouble(json['total_price']),
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
