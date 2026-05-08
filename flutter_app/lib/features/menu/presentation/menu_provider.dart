import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';
import 'package:sports_venue_chatbot/features/menu/domain/menu_repository.dart';

// ---------------------------------------------------------------------------
// Menu data provider
// ---------------------------------------------------------------------------

/// Async provider that fetches the full menu from the API
final menuProvider = FutureProvider<List<MenuCategory>>((ref) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenu();
});

// ---------------------------------------------------------------------------
// Cart state management
// ---------------------------------------------------------------------------

/// Represents a single item in the cart
class CartItem {
  final String name;
  final double unitPrice;
  final int quantity;

  const CartItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      name: name,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Cart state class
class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool get isEmpty => items.isEmpty;

  /// Convert cart items to order item creation objects
  List<OrderItemCreate> toOrderItems() {
    return items
        .map(
          (item) => OrderItemCreate(
            itemName: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          ),
        )
        .toList();
  }
}

/// Cart StateNotifier with add / remove / clear operations
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Add one unit of the given menu item to the cart.
  /// If the item already exists, increment its quantity.
  void addItem(MenuItem item) {
    final index = state.items.indexWhere((ci) => ci.name == item.name);
    if (index >= 0) {
      final updated = state.items[index].copyWith(
        quantity: state.items[index].quantity + 1,
      );
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = updated;
      state = CartState(items: newItems);
    } else {
      state = CartState(
        items: [
          ...state.items,
          CartItem(name: item.name, unitPrice: item.price, quantity: 1),
        ],
      );
    }
  }

  /// Remove one unit of the item. If quantity reaches 0, remove entirely.
  void removeItem(String itemName) {
    final index = state.items.indexWhere((ci) => ci.name == itemName);
    if (index < 0) return;

    if (state.items[index].quantity <= 1) {
      state = CartState(
        items: state.items.where((ci) => ci.name != itemName).toList(),
      );
    } else {
      final updated = state.items[index].copyWith(
        quantity: state.items[index].quantity - 1,
      );
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = updated;
      state = CartState(items: newItems);
    }
  }

  /// Get the quantity of a specific item in the cart (0 if not present)
  int getQuantity(String itemName) {
    final item = state.items.where((ci) => ci.name == itemName).toList();
    return item.isEmpty ? 0 : item.first.quantity;
  }

  /// Clear all items from the cart
  void clear() {
    state = const CartState();
  }
}

/// Provider for the CartNotifier
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// ---------------------------------------------------------------------------
// Order creation state & provider
// ---------------------------------------------------------------------------

/// State class for order creation
class OrderCreateState {
  final bool isLoading;
  final String? error;
  final Order? order;

  const OrderCreateState({this.isLoading = false, this.error, this.order});

  OrderCreateState copyWith({
    bool? isLoading,
    String? error,
    Order? order,
    bool clearError = false,
    bool clearOrder = false,
  }) {
    return OrderCreateState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      order: clearOrder ? null : (order ?? this.order),
    );
  }
}

/// Notifier for creating orders
class OrderCreateNotifier extends StateNotifier<OrderCreateState> {
  final MenuRepository _repository;

  OrderCreateNotifier(this._repository) : super(const OrderCreateState());

  /// Submit a new order
  Future<bool> createOrder(OrderCreate order) async {
    state = state.copyWith(isLoading: true, clearError: true, clearOrder: true);
    try {
      final newOrder = await _repository.createOrder(order);
      state = state.copyWith(isLoading: false, order: newOrder);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tạo đơn hàng. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Reset state after the user has seen the result
  void reset() {
    state = const OrderCreateState();
  }
}

/// Provider for the OrderCreateNotifier
final createOrderProvider =
    StateNotifierProvider<OrderCreateNotifier, OrderCreateState>((ref) {
      return OrderCreateNotifier(ref.watch(menuRepositoryProvider));
    });
