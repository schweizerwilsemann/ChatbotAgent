// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MenuItem _$MenuItemFromJson(Map<String, dynamic> json) => MenuItem(
  name: json['name'] as String,
  description: json['description'] as String,
  price: (json['price'] as num).toDouble(),
  imageUrl: json['image_url'] as String?,
  category: json['category'] as String,
);

Map<String, dynamic> _$MenuItemToJson(MenuItem instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'price': instance.price,
  'image_url': instance.imageUrl,
  'category': instance.category,
};

MenuCategory _$MenuCategoryFromJson(Map<String, dynamic> json) => MenuCategory(
  name: json['name'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MenuCategoryToJson(MenuCategory instance) =>
    <String, dynamic>{
      'name': instance.name,
      'items': instance.items,
    };

OrderItemCreate _$OrderItemCreateFromJson(Map<String, dynamic> json) =>
    OrderItemCreate(
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
    );

Map<String, dynamic> _$OrderItemCreateToJson(OrderItemCreate instance) =>
    <String, dynamic>{
      'item_name': instance.itemName,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
    };

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  itemName: json['item_name'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unit_price'] as num).toDouble(),
  totalPrice: (json['total_price'] as num).toDouble(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'item_name': instance.itemName,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'total_price': instance.totalPrice,
};

OrderCreate _$OrderCreateFromJson(Map<String, dynamic> json) => OrderCreate(
  userId: json['user_id'] as String,
  tableNumber: (json['table_number'] as num?)?.toInt() ?? 0,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItemCreate.fromJson(e as Map<String, dynamic>))
      .toList(),
  bookingId: json['booking_id'] as String?,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$OrderCreateToJson(OrderCreate instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'table_number': instance.tableNumber,
      'items': instance.items,
      'booking_id': instance.bookingId,
      'notes': instance.notes,
    };

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: json['id'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalPrice: (json['total_price'] as num).toDouble(),
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  notes: json['notes'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'items': instance.items,
  'total_price': instance.totalPrice,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'notes': instance.notes,
  'created_at': instance.createdAt.toIso8601String(),
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.preparing: 'preparing',
  OrderStatus.ready: 'ready',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};
