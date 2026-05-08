import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/features/menu/data/menu_models.dart';
import 'package:sports_venue_chatbot/features/menu/presentation/menu_provider.dart';

/// Vietnamese currency formatter
final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

/// Well-known category tab labels
const _categoryTabs = <String, String>{
  'Đồ uống': '🥤',
  'Đồ ăn': '🍔',
  'Phụ kiện': '🎒',
};

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thực đơn'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _categoryTabs.entries
              .map((e) => Tab(text: '${e.value} ${e.key}'))
              .toList(),
        ),
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Không thể tải thực đơn',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(menuProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (categories) {
          // Build ordered list: match tab labels to API categories by name,
          // fallback to empty list when a tab has no matching category.
          final categoryList = _categoryTabs.keys.map((tabName) {
            final match = categories.where((c) => c.name == tabName).toList();
            if (match.isNotEmpty) return match.first;
            // If API uses different names, try case-insensitive match
            final ciMatch = categories
                .where((c) => c.name.toLowerCase() == tabName.toLowerCase())
                .toList();
            if (ciMatch.isNotEmpty) return ciMatch.first;
            // Return an empty placeholder
            return MenuCategory(name: tabName, items: const []);
          }).toList();

          return Column(
            children: [
              // Menu grid
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: categoryList
                      .map((cat) => _MenuCategoryGrid(category: cat))
                      .toList(),
                ),
              ),

              // Cart summary bar
              if (!cart.isEmpty) _CartSummaryBar(cart: cart),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category grid
// ---------------------------------------------------------------------------

class _MenuCategoryGrid extends ConsumerWidget {
  final MenuCategory category;

  const _MenuCategoryGrid({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (category.items.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có sản phẩm nào',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: category.items.length,
      itemBuilder: (context, index) {
        return _MenuItemCard(item: category.items[index]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single menu item card
// ---------------------------------------------------------------------------

class _MenuItemCard extends ConsumerWidget {
  final MenuItem item;

  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final quantity = cart.items
        .where((ci) => ci.name == item.name)
        .fold<int>(0, (_, ci) => ci.quantity);

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image placeholder
          Expanded(
            flex: 3,
            child: Container(
              color: colorScheme.surfaceContainerHighest,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          // Info section
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Description
                  Expanded(
                    child: Text(
                      item.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Price + add to cart
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _vndFormat.format(item.price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _QuantityControl(
                        quantity: quantity,
                        onAdd: () =>
                            ref.read(cartProvider.notifier).addItem(item),
                        onRemove: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(Icons.fastfood, size: 40, color: Colors.grey),
    );
  }
}

// ---------------------------------------------------------------------------
// +/- quantity control
// ---------------------------------------------------------------------------

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return IconButton(
        icon: const Icon(Icons.add_circle, size: 28),
        color: Theme.of(context).colorScheme.primary,
        onPressed: onAdd,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.remove_circle_outline,
              size: 24,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.add_circle,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom cart summary bar
// ---------------------------------------------------------------------------

class _CartSummaryBar extends ConsumerWidget {
  final CartState cart;

  const _CartSummaryBar({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final orderState = ref.watch(createOrderProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cart icon with badge
            Badge(
              label: Text('${cart.totalItems}'),
              child: Icon(
                Icons.shopping_cart_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Total price
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.totalItems} sản phẩm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _vndFormat.format(cart.totalPrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Place order button
            FilledButton.icon(
              onPressed: orderState.isLoading
                  ? null
                  : () => _showOrderConfirmation(context, ref),
              icon: orderState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: const Text('Đặt hàng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderConfirmation(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _OrderConfirmationSheet(cart: cart),
    );
  }
}

// ---------------------------------------------------------------------------
// Order confirmation bottom sheet
// ---------------------------------------------------------------------------

class _OrderConfirmationSheet extends ConsumerStatefulWidget {
  final CartState cart;

  const _OrderConfirmationSheet({required this.cart});

  @override
  ConsumerState<_OrderConfirmationSheet> createState() =>
      _OrderConfirmationSheetState();
}

class _OrderConfirmationSheetState
    extends ConsumerState<_OrderConfirmationSheet> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(createOrderProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Xác nhận đơn hàng',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // Items list
          ...widget.cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} x${item.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _vndFormat.format(item.totalPrice),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),

          // Total
          Row(
            children: [
              Text(
                'Tổng cộng',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _vndFormat.format(widget.cart.totalPrice),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes field
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tuỳ chọn)',
              hintText: 'Ví dụ: không đá, ít đường...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Error message
          if (orderState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                orderState.error!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),

          // Submit button
          FilledButton(
            onPressed: orderState.isLoading ? null : _submitOrder,
            child: orderState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Xác nhận đặt hàng'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    final orderCreate = OrderCreate(
      items: widget.cart.toOrderItems(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final success = await ref
        .read(createOrderProvider.notifier)
        .createOrder(orderCreate);

    if (success && mounted) {
      ref.read(cartProvider.notifier).clear();
      Navigator.of(context).pop(); // dismiss bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt hàng thành công! 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset order state after showing success
      ref.read(createOrderProvider.notifier).reset();
    }
  }
}
