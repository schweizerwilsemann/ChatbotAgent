import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart'
    show AppSnackBar, SnackBarType;

// ─── Provider ────────────────────────────────────────────────────────────────

final resourceManagementProvider =
    StateNotifierProvider<ResourceManagementNotifier, ResourceManagementState>(
        (ref) {
  return ResourceManagementNotifier(ref.watch(dioClientProvider));
});

class ResourceManagementState {
  final List<VenueResource> resources;
  final bool isLoading;
  final String? error;

  const ResourceManagementState({
    this.resources = const [],
    this.isLoading = false,
    this.error,
  });

  ResourceManagementState copyWith({
    List<VenueResource>? resources,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ResourceManagementState(
      resources: resources ?? this.resources,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ResourceManagementNotifier
    extends StateNotifier<ResourceManagementState> {
  final DioClient _dio;

  ResourceManagementNotifier(this._dio)
      : super(const ResourceManagementState());

  Future<void> loadResources({String? status}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      final response = await _dio.get<dynamic>(
        ApiConstants.venueResourcesEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final rawList = response.data;
      if (rawList is! List) {
        state =
            state.copyWith(isLoading: false, error: 'Dữ liệu không hợp lệ.');
        return;
      }
      final resources = rawList
          .map((json) => VenueResource.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(resources: resources, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách sân. $e',
      );
    }
  }

  Future<bool> updateStatus(String resourceId, String status) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.adminResourcesEndpoint}/$resourceId',
        data: {'status': status},
      );
      await loadResources();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateResource(
    String resourceId, {
    String? name,
    String? status,
    double? hourlyRate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (status != null) data['status'] = status;
      if (hourlyRate != null) data['hourly_rate'] = hourlyRate;
      await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.adminResourcesEndpoint}/$resourceId',
        data: data,
      );
      await loadResources();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ResourceManagementScreen extends ConsumerStatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  ConsumerState<ResourceManagementScreen> createState() =>
      _ResourceManagementScreenState();
}

class _ResourceManagementScreenState
    extends ConsumerState<ResourceManagementScreen> {
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resourceManagementProvider.notifier).loadResources();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resourceManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sân'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(resourceManagementProvider.notifier)
                .loadResources(
                    status: _statusFilter == 'all' ? null : _statusFilter),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _statusFilter == 'all',
                  onTap: () => _setFilter('all'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Hoạt động',
                  selected: _statusFilter == 'active',
                  color: AppColors.success,
                  onTap: () => _setFilter('active'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Bảo trì',
                  selected: _statusFilter == 'maintenance',
                  color: AppColors.warning,
                  onTap: () => _setFilter('maintenance'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Tắt',
                  selected: _statusFilter == 'inactive',
                  color: AppColors.textHint,
                  onTap: () => _setFilter('inactive'),
                ),
              ],
            ),
          ),
          // Resource list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.error),
                            const SizedBox(height: AppSpacing.md),
                            Text(state.error!, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.md),
                            ElevatedButton(
                              onPressed: () => ref
                                  .read(resourceManagementProvider.notifier)
                                  .loadResources(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : state.resources.isEmpty
                        ? Center(
                            child: Text(
                              'Không có sân nào',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(resourceManagementProvider.notifier)
                                .loadResources(
                                    status: _statusFilter == 'all'
                                        ? null
                                        : _statusFilter),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: state.resources.length,
                              itemBuilder: (context, index) => _ResourceCard(
                                  resource: state.resources[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _setFilter(String status) {
    setState(() => _statusFilter = status);
    ref
        .read(resourceManagementProvider.notifier)
        .loadResources(status: status == 'all' ? null : status);
  }
}

// ─── Filter Chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? chipColor.withOpacity(0.15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? chipColor : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Resource Card ───────────────────────────────────────────────────────────

class _ResourceCard extends ConsumerWidget {
  final VenueResource resource;

  const _ResourceCard({required this.resource});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusInfo = _statusInfo(resource.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForResourceType(resource.resourceType),
                  color: statusInfo.$2,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (resource.areaName != null)
                        Text(
                          resource.areaName!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusInfo.$1,
                    style: TextStyle(
                      color: statusInfo.$2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Info row
            Row(
              children: [
                _InfoChip(icon: Icons.tag, label: resource.code),
                const SizedBox(width: AppSpacing.sm),
                if (resource.hourlyRate != null)
                  _InfoChip(
                    icon: Icons.attach_money,
                    label: '${_formatPrice(resource.hourlyRate!)}đ/h',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (resource.status != 'active')
                  TextButton.icon(
                    onPressed: () =>
                        _changeStatus(context, ref, resource.id, 'active'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Kích hoạt'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.success),
                  ),
                if (resource.status != 'maintenance')
                  TextButton.icon(
                    onPressed: () =>
                        _changeStatus(context, ref, resource.id, 'maintenance'),
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: const Text('Bảo trì'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning),
                  ),
                if (resource.status != 'inactive')
                  TextButton.icon(
                    onPressed: () =>
                        _changeStatus(context, ref, resource.id, 'inactive'),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Tắt'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeStatus(
    BuildContext context,
    WidgetRef ref,
    String resourceId,
    String newStatus,
  ) async {
    final statusNames = {
      'active': 'hoạt động',
      'maintenance': 'bảo trì',
      'inactive': 'tắt',
    };
    final success = await ref
        .read(resourceManagementProvider.notifier)
        .updateStatus(resourceId, newStatus);
    if (success && context.mounted) {
      AppSnackBar.show(
        context,
        'Đã chuyển trạng thái ${statusNames[newStatus] ?? newStatus}',
        type: SnackBarType.success,
      );
    }
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return price.round().toString();
    }
    return price.toStringAsFixed(0);
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'active':
        return ('Hoạt động', AppColors.success);
      case 'maintenance':
        return ('Bảo trì', AppColors.warning);
      case 'inactive':
        return ('Tắt', AppColors.textHint);
      default:
        return (status, AppColors.textSecondary);
    }
  }

  IconData _iconForResourceType(String type) {
    switch (type) {
      case 'billiards_table':
        return Icons.sports_bar;
      case 'pickleball_court':
        return Icons.sports_tennis;
      case 'badminton_court':
        return Icons.sports_tennis;
      case 'dining_table':
        return Icons.table_restaurant;
      default:
        return Icons.grid_view;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
