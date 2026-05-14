// ─── Helper ─────────────────────────────────────────────────────────────────

/// Safely convert a JSON value (num or String) to double.
/// Handles the backend Pydantic Decimal → String serialization.
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.parse(v);
  throw FormatException('Expected num or String, got ${v.runtimeType}');
}

/// Safely convert a JSON value (num or String) to int.
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw FormatException('Expected num or String, got ${v.runtimeType}');
}

/// Safely parse an ISO-8601 string to DateTime, returns null if null/empty.
DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.parse(v as String);
}

// ─── Enums ──────────────────────────────────────────────────────────────────

enum AdminBookingStatus {
  pending,
  confirmed,
  cancelled,
  completed,
}

AdminBookingStatus _parseBookingStatus(String value) {
  switch (value) {
    case 'pending':
      return AdminBookingStatus.pending;
    case 'confirmed':
      return AdminBookingStatus.confirmed;
    case 'cancelled':
      return AdminBookingStatus.cancelled;
    case 'completed':
      return AdminBookingStatus.completed;
    default:
      return AdminBookingStatus.pending;
  }
}

String _bookingStatusToString(AdminBookingStatus status) {
  switch (status) {
    case AdminBookingStatus.pending:
      return 'pending';
    case AdminBookingStatus.confirmed:
      return 'confirmed';
    case AdminBookingStatus.cancelled:
      return 'cancelled';
    case AdminBookingStatus.completed:
      return 'completed';
  }
}

extension AdminBookingStatusExtension on AdminBookingStatus {
  String get displayName {
    switch (this) {
      case AdminBookingStatus.pending:
        return 'Chờ xác nhận';
      case AdminBookingStatus.confirmed:
        return 'Đã xác nhận';
      case AdminBookingStatus.cancelled:
        return 'Đã huỷ';
      case AdminBookingStatus.completed:
        return 'Hoàn thành';
    }
  }

  String get apiValue => _bookingStatusToString(this);
}

enum AdminOrderStatus {
  pending,
  preparing,
  ready,
  delivered,
  cancelled,
}

AdminOrderStatus _parseOrderStatus(String value) {
  switch (value) {
    case 'pending':
      return AdminOrderStatus.pending;
    case 'preparing':
      return AdminOrderStatus.preparing;
    case 'ready':
      return AdminOrderStatus.ready;
    case 'delivered':
      return AdminOrderStatus.delivered;
    case 'cancelled':
      return AdminOrderStatus.cancelled;
    default:
      return AdminOrderStatus.pending;
  }
}

String _orderStatusToString(AdminOrderStatus status) {
  switch (status) {
    case AdminOrderStatus.pending:
      return 'pending';
    case AdminOrderStatus.preparing:
      return 'preparing';
    case AdminOrderStatus.ready:
      return 'ready';
    case AdminOrderStatus.delivered:
      return 'delivered';
    case AdminOrderStatus.cancelled:
      return 'cancelled';
  }
}

extension AdminOrderStatusExtension on AdminOrderStatus {
  String get displayName {
    switch (this) {
      case AdminOrderStatus.pending:
        return 'Chờ xử lý';
      case AdminOrderStatus.preparing:
        return 'Đang chuẩn bị';
      case AdminOrderStatus.ready:
        return 'Sẵn sàng';
      case AdminOrderStatus.delivered:
        return 'Đã giao';
      case AdminOrderStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  String get apiValue => _orderStatusToString(this);
}

// ─── Dashboard Stats ────────────────────────────────────────────────────────

class DashboardStats {
  final double totalRevenue;
  final int bookingsToday;
  final int ordersToday;
  final int activeCourts;
  final int totalCourts;

  const DashboardStats({
    required this.totalRevenue,
    required this.bookingsToday,
    required this.ordersToday,
    required this.activeCourts,
    required this.totalCourts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: _toDouble(json['total_revenue']),
      bookingsToday: _toInt(json['bookings_today']),
      ordersToday: _toInt(json['orders_today']),
      activeCourts: _toInt(json['active_courts']),
      totalCourts: _toInt(json['total_courts']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'bookings_today': bookingsToday,
      'orders_today': ordersToday,
      'active_courts': activeCourts,
      'total_courts': totalCourts,
    };
  }
}

// ─── Admin Booking ──────────────────────────────────────────────────────────

class AdminBooking {
  final String id;
  final String userId;
  final String userName;
  final String courtType;
  final int courtNumber;
  final DateTime date;
  final String startTime;
  final String endTime;
  final AdminBookingStatus status;
  final double? totalPrice;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AdminBooking({
    required this.id,
    required this.userId,
    required this.userName,
    required this.courtType,
    required this.courtNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.totalPrice,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminBooking.fromJson(Map<String, dynamic> json) {
    return AdminBooking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? '',
      courtType: json['court_type'] as String,
      courtNumber: _toInt(json['court_number']),
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: _parseBookingStatus(json['status'] as String),
      totalPrice:
          json['total_price'] != null ? _toDouble(json['total_price']) : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'court_type': courtType,
      'court_number': courtNumber,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'start_time': startTime,
      'end_time': endTime,
      'status': _bookingStatusToString(status),
      'total_price': totalPrice,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AdminBooking copyWith({
    String? id,
    String? userId,
    String? userName,
    String? courtType,
    int? courtNumber,
    DateTime? date,
    String? startTime,
    String? endTime,
    AdminBookingStatus? status,
    double? totalPrice,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminBooking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      courtType: courtType ?? this.courtType,
      courtNumber: courtNumber ?? this.courtNumber,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Admin Order Item ───────────────────────────────────────────────────────

class AdminOrderItem {
  final String id;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const AdminOrderItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      id: json['id'] as String,
      itemName: json['item_name'] as String,
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      totalPrice: _toDouble(json['total_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

// ─── Admin Order ────────────────────────────────────────────────────────────

class AdminOrder {
  final String id;
  final String userId;
  final int tableNumber;
  final AdminOrderStatus status;
  final double totalPrice;
  final String? notes;
  final List<AdminOrderItem> items;
  final DateTime createdAt;

  const AdminOrder({
    required this.id,
    required this.userId,
    required this.tableNumber,
    required this.status,
    required this.totalPrice,
    this.notes,
    required this.items,
    required this.createdAt,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    return AdminOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tableNumber: _toInt(json['table_number']),
      status: _parseOrderStatus(json['status'] as String),
      totalPrice: _toDouble(json['total_price']),
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AdminOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'table_number': tableNumber,
      'status': _orderStatusToString(status),
      'total_price': totalPrice,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AdminOrder copyWith({
    String? id,
    String? userId,
    int? tableNumber,
    AdminOrderStatus? status,
    double? totalPrice,
    String? notes,
    List<AdminOrderItem>? items,
    DateTime? createdAt,
  }) {
    return AdminOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─── Admin Menu Item ────────────────────────────────────────────────────────

class AdminMenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final String categoryKey;
  final String unit;
  final String? tags;
  final int salesCount;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AdminMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    required this.categoryKey,
    required this.unit,
    this.tags,
    required this.salesCount,
    required this.isAvailable,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminMenuItem.fromJson(Map<String, dynamic> json) {
    return AdminMenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: _toDouble(json['price']),
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String,
      categoryKey: json['category_key'] as String,
      unit: json['unit'] as String? ?? '',
      tags: json['tags'] as String?,
      salesCount: _toInt(json['sales_count']),
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'category_key': categoryKey,
      'unit': unit,
      'tags': tags,
      'sales_count': salesCount,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AdminMenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    String? categoryKey,
    String? unit,
    String? tags,
    int? salesCount,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      categoryKey: categoryKey ?? this.categoryKey,
      unit: unit ?? this.unit,
      tags: tags ?? this.tags,
      salesCount: salesCount ?? this.salesCount,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── Menu Item Create ───────────────────────────────────────────────────────

class MenuItemCreate {
  final String name;
  final String categoryKey;
  final String categoryName;
  final String? description;
  final String? unit;
  final double price;
  final String? imageUrl;
  final String? tags;

  const MenuItemCreate({
    required this.name,
    required this.categoryKey,
    required this.categoryName,
    this.description,
    this.unit,
    required this.price,
    this.imageUrl,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category_key': categoryKey,
      'category_name': categoryName,
      'description': description,
      'unit': unit,
      'price': price,
      'image_url': imageUrl,
      'tags': tags,
    };
  }
}

// ─── Menu Item Update ───────────────────────────────────────────────────────

class MenuItemUpdate {
  final String? name;
  final String? categoryKey;
  final String? categoryName;
  final String? description;
  final String? unit;
  final double? price;
  final String? imageUrl;
  final String? tags;

  const MenuItemUpdate({
    this.name,
    this.categoryKey,
    this.categoryName,
    this.description,
    this.unit,
    this.price,
    this.imageUrl,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (categoryKey != null) map['category_key'] = categoryKey;
    if (categoryName != null) map['category_name'] = categoryName;
    if (description != null) map['description'] = description;
    if (unit != null) map['unit'] = unit;
    if (price != null) map['price'] = price;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (tags != null) map['tags'] = tags;
    return map;
  }
}

// ─── Analytics Sub-models ───────────────────────────────────────────────────

class DayRevenue {
  final String date;
  final double revenue;

  const DayRevenue({required this.date, required this.revenue});

  factory DayRevenue.fromJson(Map<String, dynamic> json) {
    return DayRevenue(
      date: json['date'] as String,
      revenue: _toDouble(json['revenue']),
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'revenue': revenue};
}

class CourtBookingCount {
  final String courtType;
  final int courtNumber;
  final int count;

  const CourtBookingCount({
    required this.courtType,
    required this.courtNumber,
    required this.count,
  });

  factory CourtBookingCount.fromJson(Map<String, dynamic> json) {
    return CourtBookingCount(
      courtType: json['court_type'] as String,
      courtNumber: _toInt(json['court_number']),
      count: _toInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() => {
        'court_type': courtType,
        'court_number': courtNumber,
        'count': count,
      };
}

class HourOrderCount {
  final int hour;
  final int count;

  const HourOrderCount({required this.hour, required this.count});

  factory HourOrderCount.fromJson(Map<String, dynamic> json) {
    return HourOrderCount(
      hour: _toInt(json['hour']),
      count: _toInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'count': count};
}

class DayOrderCount {
  final String date;
  final int count;

  const DayOrderCount({required this.date, required this.count});

  factory DayOrderCount.fromJson(Map<String, dynamic> json) {
    return DayOrderCount(
      date: json['date'] as String,
      count: _toInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'count': count};
}

// ─── Analytics Data ─────────────────────────────────────────────────────────

class AnalyticsData {
  final List<DayRevenue> revenueByDay;
  final List<CourtBookingCount> bookingsByCourt;
  final List<HourOrderCount> ordersByHour;
  final List<DayOrderCount> orderCountByDay;

  const AnalyticsData({
    required this.revenueByDay,
    required this.bookingsByCourt,
    required this.ordersByHour,
    required this.orderCountByDay,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      revenueByDay: (json['revenue_by_day'] as List<dynamic>?)
              ?.map((e) => DayRevenue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bookingsByCourt: (json['bookings_by_court'] as List<dynamic>?)
              ?.map(
                  (e) => CourtBookingCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      ordersByHour: (json['orders_by_hour'] as List<dynamic>?)
              ?.map((e) => HourOrderCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      orderCountByDay: (json['order_count_by_day'] as List<dynamic>?)
              ?.map((e) => DayOrderCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'revenue_by_day': revenueByDay.map((e) => e.toJson()).toList(),
      'bookings_by_court': bookingsByCourt.map((e) => e.toJson()).toList(),
      'orders_by_hour': ordersByHour.map((e) => e.toJson()).toList(),
      'order_count_by_day': orderCountByDay.map((e) => e.toJson()).toList(),
    };
  }
}
