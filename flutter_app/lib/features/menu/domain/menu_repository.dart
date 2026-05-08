import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_api.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(menuApiProvider));
});

/// Abstract menu repository interface
abstract class IMenuRepository {
  Future<List<MenuCategory>> getMenu();
  Future<Order> createOrder(OrderCreate order);
  Future<Order> getOrderById(String orderId);
  Future<List<Order>> getOrdersByUser(String userId);
}

/// Concrete implementation of the menu repository
class MenuRepository implements IMenuRepository {
  final MenuApi _menuApi;

  MenuRepository(this._menuApi);

  @override
  Future<List<MenuCategory>> getMenu() async {
    try {
      return await _menuApi.getMenu();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải thực đơn. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Order> createOrder(OrderCreate order) async {
    try {
      // Validate order data
      if (order.items.isEmpty) {
        throw ValidationException(
          message: 'Đơn hàng phải có ít nhất một sản phẩm',
        );
      }
      for (final item in order.items) {
        if (item.quantity <= 0) {
          throw ValidationException(message: 'Số lượng phải lớn hơn 0');
        }
      }
      return await _menuApi.createOrder(order);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tạo đơn hàng. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Order> getOrderById(String orderId) async {
    try {
      return await _menuApi.getOrderById(orderId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải thông tin đơn hàng.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<List<Order>> getOrdersByUser(String userId) async {
    try {
      return await _menuApi.getOrdersByUser(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải danh sách đơn hàng.',
        statusCode: 500,
      );
    }
  }
}
