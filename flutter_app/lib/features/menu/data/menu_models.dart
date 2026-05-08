import 'package:json_annotation/json_annotation.dart';

part 'menu_models.g.dart';

/// Menu item model
@JsonSerializable()
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

  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);

  Map<String, dynamic> toJson() => _$MenuItemToJson(this);
}

/// Menu category containing a list of items
@JsonSerializable()
class MenuCategory {
  final String name;
  final List<MenuItem> items;

  const MenuCategory({required this.name, required this.items});

  factory MenuCategory.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$MenuCategoryToJson(this);
}

/// Order item for creating an order
@JsonSerializable()
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

  Map<String, dynamic> toJson() => _$OrderItemCreateToJson(this);
}

/// Order item returned from the API
@JsonSerializable()
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

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}

/// Order creation request
@JsonSerializable()
class OrderCreate {
  final List<OrderItemCreate> items;
  final String? bookingId;
  final String? notes;

  const OrderCreate({required this.items, this.bookingId, this.notes});

  factory OrderCreate.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateFromJson(json);

  Map<String, dynamic> toJson() => _$OrderCreateToJson(this);
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
@JsonSerializable()
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

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
