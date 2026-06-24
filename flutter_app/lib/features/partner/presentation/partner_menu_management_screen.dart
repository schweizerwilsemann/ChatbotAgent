import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/partner/data/partner_models.dart';
import 'package:sports_venue_chatbot/features/partner/presentation/partner_menu_provider.dart';

class PartnerMenuManagementScreen extends ConsumerStatefulWidget {
  const PartnerMenuManagementScreen({super.key});

  @override
  ConsumerState<PartnerMenuManagementScreen> createState() =>
      _PartnerMenuManagementScreenState();
}

class _PartnerMenuManagementScreenState
    extends ConsumerState<PartnerMenuManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(partnerMenuProvider.notifier).loadItems();
    });
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

  Future<void> _handleCreate() async {
    final result = await _showAddEditSheet();
    if (result == null || !mounted) return;
    await ref.read(partnerMenuProvider.notifier).createItem(result);
  }

  Future<void> _handleEdit(PartnerMenuItem item) async {
    final result = await _showAddEditSheet(item: item);
    if (result == null || !mounted) return;
    await ref.read(partnerMenuProvider.notifier).updateItem(
          item.id,
          PartnerMenuItemUpdateData(
            name: result.name,
            description: result.description,
            price: result.price,
            category: result.category,
            imageUrl: result.imageUrl,
            isAvailable: result.isAvailable,
          ),
        );
  }

  Future<void> _handleDelete(PartnerMenuItem item) async {
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
      await ref.read(partnerMenuProvider.notifier).deleteItem(item.id);
    }
  }

  Future<void> _handleToggleAvailability(PartnerMenuItem item) async {
    await ref
        .read(partnerMenuProvider.notifier)
        .toggleAvailability(item.id, !item.isAvailable);
  }

  Future<PartnerMenuItemCreateData?> _showAddEditSheet({
    PartnerMenuItem? item,
  }) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final priceCtrl = TextEditingController(
      text: isEdit ? item.price.toStringAsFixed(0) : '',
    );

    const categoryOptions = ['food', 'drink', 'dessert', 'combo'];
    final categoryLabels = {
      'food': 'Đồ ăn',
      'drink': 'Đồ uống',
      'dessert': 'Tráng miệng',
      'combo': 'Combo',
    };
    String selectedCategory = item?.category ?? categoryOptions.first;
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<PartnerMenuItemCreateData>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên món *',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập tên món'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục *',
                        ),
                        items: categoryOptions
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(categoryLabels[c] ?? c),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => selectedCategory = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Giá (VNĐ) *',
                          suffixText: 'đ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập giá';
                          if (double.tryParse(v.trim()) == null) {
                            return 'Giá không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(
                            ctx,
                            PartnerMenuItemCreateData(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              price: double.parse(priceCtrl.text.trim()),
                              category: selectedCategory,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE67E22),
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
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerMenuProvider);

    ref.listen<PartnerMenuState>(partnerMenuProvider, (prev, next) {
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        _showSnackBar(next.successMessage!);
        ref.read(partnerMenuProvider.notifier).clearSuccess();
      }
      if (next.error != null && next.error != prev?.error) {
        _showSnackBar(next.error!, isError: true);
        ref.read(partnerMenuProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(partnerMenuProvider.notifier).loadItems(),
              child: state.items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_menu,
                                  size: 64,
                                  color: AppColors.textHint.withValues(
                                    alpha: 0.5,
                                  )),
                              const SizedBox(height: 12),
                              const Text(
                                'Chưa có món nào',
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.items.length,
                      itemBuilder: (ctx, i) {
                        final item = state.items[i];
                        return _PartnerMenuItemCard(
                          item: item,
                          formatPrice: _formatPrice,
                          onEdit: () => _handleEdit(item),
                          onDelete: () => _handleDelete(item),
                          onToggle: () => _handleToggleAvailability(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE67E22),
        onPressed: _handleCreate,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PartnerMenuItemCard extends StatelessWidget {
  final PartnerMenuItem item;
  final String Function(double) formatPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _PartnerMenuItemCard({
    required this.item,
    required this.formatPrice,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE67E22).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: const Color(0xFFE67E22),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Ẩn',
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE67E22).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _categoryLabel(item.category),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE67E22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatPrice(item.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE67E22),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Đã bán: ${item.salesCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'toggle':
                    onToggle();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
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

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'drink':
        return Icons.local_cafe;
      case 'dessert':
        return Icons.cake;
      case 'combo':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'drink':
        return 'Đồ uống';
      case 'dessert':
        return 'Tráng miệng';
      case 'combo':
        return 'Combo';
      default:
        return 'Đồ ăn';
    }
  }
}
