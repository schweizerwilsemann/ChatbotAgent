import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final resourcePricingProvider =
    StateNotifierProvider<ResourcePricingNotifier, ResourcePricingState>((ref) {
  return ResourcePricingNotifier(ref.watch(dioClientProvider));
});

class ResourcePricingState {
  final List<VenueResource> resources;
  final bool isLoading;
  final String? error;

  const ResourcePricingState({
    this.resources = const [],
    this.isLoading = false,
    this.error,
  });

  ResourcePricingState copyWith({
    List<VenueResource>? resources,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ResourcePricingState(
      resources: resources ?? this.resources,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ResourcePricingNotifier extends StateNotifier<ResourcePricingState> {
  final DioClient _dio;

  ResourcePricingNotifier(this._dio) : super(const ResourcePricingState());

  Future<void> loadResources() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.venueResourcesEndpoint,
        queryParameters: {'status': 'active'},
      );
      final rawList = response.data;
      if (rawList is! List) {
        state = state.copyWith(
          isLoading: false,
          error: 'Dữ liệu không hợp lệ.',
        );
        return;
      }
      final resources = rawList
          .map((json) => VenueResource.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(resources: resources, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải danh sách sân/bàn. $e',
      );
    }
  }

  Future<bool> updateHourlyRate(String resourceId, double? hourlyRate) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.adminResourcesEndpoint}/$resourceId',
        data: {'hourly_rate': hourlyRate},
      );
      await loadResources();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ResourcePricingScreen extends ConsumerStatefulWidget {
  const ResourcePricingScreen({super.key});

  @override
  ConsumerState<ResourcePricingScreen> createState() =>
      _ResourcePricingScreenState();
}

class _ResourcePricingScreenState extends ConsumerState<ResourcePricingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resourcePricingProvider.notifier).loadResources();
    });
  }

  String _sportTypeLabel(String? type) {
    switch (type) {
      case 'billiards':
        return 'Bida';
      case 'pickleball':
        return 'Pickleball';
      case 'badminton':
        return 'Cầu lông';
      default:
        return type ?? 'Khác';
    }
  }

  String _resourceTypeLabel(String type) {
    switch (type) {
      case 'billiards_table':
        return 'Bàn bida';
      case 'pickleball_court':
        return 'Sân pickleball';
      case 'badminton_court':
        return 'Sân cầu lông';
      case 'dining_table':
        return 'Bàn ăn';
      default:
        return type;
    }
  }

  Color _sportColor(String? type) {
    switch (type) {
      case 'billiards':
        return AppColors.billiardsColor;
      case 'pickleball':
        return AppColors.pickleballColor;
      case 'badminton':
        return AppColors.badmintonColor;
      default:
        return AppColors.primary;
    }
  }

  void _editPrice(VenueResource resource) {
    final controller = TextEditingController(
      text: resource.hourlyRate?.round().toString() ?? '',
    );

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cập nhật giá - ${resource.displayLabel}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_resourceTypeLabel(resource.resourceType)} · ${_sportTypeLabel(resource.sportType)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Giá mỗi giờ (VNĐ)',
                suffixText: 'đ/giờ',
                hintText: 'VD: 80000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          if (resource.hourlyRate != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text(
                'Xoá giá',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == null) {
        // Clear price
        final ok = await ref
            .read(resourcePricingProvider.notifier)
            .updateHourlyRate(resource.id, null);
        if (ok && mounted) {
          AppSnackBar.showSuccess(context, 'Đã xoá giá sân.');
        }
      } else if (confirmed == true) {
        final rate = double.tryParse(controller.text.trim());
        if (rate == null || rate <= 0) return;
        final ok = await ref
            .read(resourcePricingProvider.notifier)
            .updateHourlyRate(resource.id, rate);
        if (ok && mounted) {
          AppSnackBar.showSuccess(context, 'Đã cập nhật giá sân.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resourcePricingProvider);
    final money =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình giá sân'),
        centerTitle: true,
      ),
      body: ResponsiveContainer(
        maxWidth: 700,
        child: state.isLoading && state.resources.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.resources.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(state.error!,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref
                              .read(resourcePricingProvider.notifier)
                              .loadResources(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(resourcePricingProvider.notifier)
                        .loadResources(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.resources.length,
                      itemBuilder: (context, index) {
                        final resource = state.resources[index];
                        final color = _sportColor(resource.sportType);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Text(
                                '${resource.number}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(
                              resource.displayLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_resourceTypeLabel(resource.resourceType)} · ${_sportTypeLabel(resource.sportType)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  resource.hourlyRate != null
                                      ? '${money.format(resource.hourlyRate!.round())}/giờ'
                                      : 'Chưa có giá',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: resource.hourlyRate != null
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _editPrice(resource),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
