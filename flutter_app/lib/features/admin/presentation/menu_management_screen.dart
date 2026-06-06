import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/admin/data/admin_models.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/menu_management_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/pagination_footer.dart';

// ─── Category helpers ───────────────────────────────────────────────────────

const _defaultTabLabels = ['Tất cả', 'Đồ uống', 'Đồ ăn', 'Tráng miệng', 'Khác'];

const _defaultCategoryKeyMap = <String, String>{
  'Đồ uống': 'drinks',
  'Đồ ăn': 'food',
  'Tráng miệng': 'desserts',
  'Khác': 'other',
};

/// Build a categoryName → categoryKey map from the loaded items.
Map<String, String> _buildCategoryKeyMap(List<AdminMenuItem> items) {
  final map = <String, String>{};
  for (final item in items) {
    if (!map.containsKey(item.category)) {
      map[item.category] = item.categoryKey;
    }
  }
  return map;
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _defaultTabLabels.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuManagementProvider.notifier).loadItems();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String? get _selectedCategoryKey {
    final selectedTab = _defaultTabLabels[_tabController.index];
    if (selectedTab == 'Tất cả') return null;
    return _defaultCategoryKeyMap[selectedTab];
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final categoryKey = _selectedCategoryKey;
    ref.read(menuManagementProvider.notifier).loadItems(
          categoryKey: categoryKey,
          clearCategoryKey: categoryKey == null,
          query: _searchQuery,
        );
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final categoryKey = _selectedCategoryKey;
      ref.read(menuManagementProvider.notifier).loadItems(
            categoryKey: categoryKey,
            clearCategoryKey: categoryKey == null,
            query: _searchQuery,
          );
    });
  }

  bool _handlePagination(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 360) {
      ref.read(menuManagementProvider.notifier).loadMoreItems();
    }
    return false;
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(price.round())}đ';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── CRUD actions ───────────────────────────────────────────────────

  Future<void> _handleCreate() async {
    final result = await _showAddEditSheet();
    if (result == null || !mounted) return;
    await ref.read(menuManagementProvider.notifier).createItem(result);
    // Snackbars are driven by listener below
  }

  Future<void> _handleEdit(AdminMenuItem item) async {
    final result = await _showAddEditSheet(item: item);
    if (result == null || !mounted) return;
    await ref.read(menuManagementProvider.notifier).updateItem(
          item.id,
          MenuItemUpdate(
            name: result.name,
            categoryKey: result.categoryKey,
            categoryName: result.categoryName,
            description: result.description,
            unit: result.unit,
            price: result.price,
            imageUrl: result.imageUrl,
            tags: result.tags,
          ),
        );
  }

  Future<void> _handleDelete(AdminMenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá món'),
        content: Text('Bạn có chắc muốn xoá "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(menuManagementProvider.notifier).deleteItem(item.id);
    }
  }

  Future<void> _handleToggleAvailability(AdminMenuItem item) async {
    await ref
        .read(menuManagementProvider.notifier)
        .toggleAvailability(item.id, !item.isAvailable);
  }

  // ── Add / Edit bottom sheet ────────────────────────────────────────

  Future<MenuItemCreate?> _showAddEditSheet({AdminMenuItem? item}) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final priceCtrl = TextEditingController(
        text: isEdit ? item.price.toStringAsFixed(0) : '');

    // Build category options dynamically from loaded items
    final state = ref.read(menuManagementProvider);
    final categoryKeyMap = _buildCategoryKeyMap(state.items);
    if (categoryKeyMap.isEmpty) {
      categoryKeyMap.addAll(_defaultCategoryKeyMap);
    }
    final categoryOptions = categoryKeyMap.keys.toList()..sort();

    // Ensure the item's current category is in the list when editing
    if (isEdit && !categoryOptions.contains(item.category)) {
      categoryOptions.add(item.category);
      categoryKeyMap[item.category] = item.categoryKey;
    }

    String selectedCategory = isEdit ? item.category : categoryOptions.first;
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<MenuItemCreate>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + bottomInset,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    isEdit ? 'Sửa món' : 'Thêm món mới',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên món *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên món' : null,
                  ),
                  const SizedBox(height: 14),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục *',
                    ),
                    items: categoryOptions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        selectedCategory = v;
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Price
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration: const InputDecoration(
                      labelText: 'Giá (VNĐ) *',
                      suffixText: 'đ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nhập giá';
                      }
                      if (double.tryParse(v.trim()) == null) {
                        return 'Giá không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final categoryKey =
                          categoryKeyMap[selectedCategory] ?? 'other';
                      Navigator.pop(
                        ctx,
                        MenuItemCreate(
                          name: nameCtrl.text.trim(),
                          categoryKey: categoryKey,
                          categoryName: selectedCategory,
                          description: descCtrl.text.trim(),
                          price: double.parse(priceCtrl.text.trim()),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEdit ? 'Cập nhật' : 'Thêm mới'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Note: intentionally NOT disposing controllers here.
    // The bottom sheet widget tree may still be alive (exit animation)
    // and disposing early causes "used after being disposed" errors.
    // Controllers are GC'd once all references are gone.
    return result;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuManagementProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final canManageMenu = user?.role.toUpperCase() == 'ADMIN';

    // Listen for success / error messages
    ref.listen<MenuManagementState>(menuManagementProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        _showSnackBar(next.successMessage!);
        ref.read(menuManagementProvider.notifier).clearSuccess();
      }
      if (next.error != null && next.error != prev?.error) {
        _showSnackBar(next.error!, isError: true);
        ref.read(menuManagementProvider.notifier).clearError();
      }
    });

    final items = state.items;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Quản lý thực đơn'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          if (canManageMenu)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Thêm món',
              onPressed: _handleCreate,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _defaultTabLabels.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 900,
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(),

            // Content
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () {
                        final categoryKey = _selectedCategoryKey;
                        return ref
                            .read(menuManagementProvider.notifier)
                            .loadItems(
                              categoryKey: categoryKey,
                              clearCategoryKey: categoryKey == null,
                              query: _searchQuery,
                            );
                      },
                      child: items.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.3,
                                ),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.restaurant_menu,
                                          size: 64,
                                          color: AppColors.textHint
                                              .withValues(alpha: 0.5)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Không có món nào',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: _handlePagination,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: items.length + 1,
                                itemBuilder: (ctx, i) {
                                  if (i == items.length) {
                                    return PaginationFooter(
                                      isLoading: state.isLoadingMore,
                                      hasMore: state.hasMore,
                                    );
                                  }
                                  return _MenuItemManagementCard(
                                    item: items[i],
                                    formatPrice: _formatPrice,
                                    canManageMenu: canManageMenu,
                                    onEdit: () => _handleEdit(items[i]),
                                    onDelete: () => _handleDelete(items[i]),
                                    onToggleAvailability: () =>
                                        _handleToggleAvailability(items[i]),
                                  );
                                },
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm món...',
          hintStyle: const TextStyle(color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _handleSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _handleSearchChanged,
      ),
    );
  }
}

// ─── Menu item card ─────────────────────────────────────────────────────────

class _MenuItemManagementCard extends StatelessWidget {
  final AdminMenuItem item;
  final String Function(double) formatPrice;
  final bool canManageMenu;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _MenuItemManagementCard({
    required this.item,
    required this.formatPrice,
    required this.canManageMenu,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Placeholder icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.isAvailable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Hết hàng',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Category + price
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.toolBadgeMenu,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatPrice(item.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Popup menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'toggle':
                    onToggleAvailability();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                if (canManageMenu)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: AppColors.info),
                        SizedBox(width: 10),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        item.isAvailable
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Text(item.isAvailable ? 'Ẩn' : 'Hiện'),
                    ],
                  ),
                ),
                if (canManageMenu)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('Xoá', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
