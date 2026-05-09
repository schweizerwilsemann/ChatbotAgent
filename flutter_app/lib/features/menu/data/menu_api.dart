import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';

final menuApiProvider = Provider<MenuApi>((ref) {
  return MenuApi(ref.watch(dioClientProvider));
});

class MenuApi {
  final DioClient _dioClient;

  MenuApi(this._dioClient);

  /// Fetch the full menu grouped by categories
  Future<List<MenuCategory>> getMenu() async {
    try {
      final response = await _dioClient.get<dynamic>(
        ApiConstants.menuEndpoint,
      );
      final data = response.data;
      if (data == null) return [];

      if (data is List<dynamic>) {
        return data
            .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (data is Map<String, dynamic> && data['categories'] is Map) {
        final categories = data['categories'] as Map;
        return categories.entries.map((entry) {
          final name = _categoryLabel(entry.key.toString());
          final items = (entry.value as List<dynamic>).map((raw) {
            final item = raw as Map<String, dynamic>;
            return MenuItem(
              name: item['item_name'] as String,
              description: item['unit'] as String? ?? '',
              price: (item['price'] as num).toDouble(),
              category: name,
            );
          }).toList();
          return MenuCategory(name: name, items: items);
        }).toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'drinks':
        return 'Đồ uống';
      case 'snacks':
        return 'Đồ ăn';
      case 'billiards':
        return 'Phụ kiện';
      default:
        return key;
    }
  }

  /// Create a new order
  Future<Order> createOrder(OrderCreate order) async {
    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.orderEndpoint,
        data: order.toJson(),
      );
      return Order.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get an order by ID
  Future<Order> getOrderById(String orderId) async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>(
        '${ApiConstants.orderEndpoint}/$orderId',
      );
      return Order.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all orders for a user
  Future<List<Order>> getOrdersByUser(String userId) async {
    try {
      final response = await _dioClient.get<List<dynamic>>(
        ApiConstants.orderEndpoint,
        queryParameters: {'user_id': userId},
      );
      if (response.data == null) return [];
      return response.data!
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
