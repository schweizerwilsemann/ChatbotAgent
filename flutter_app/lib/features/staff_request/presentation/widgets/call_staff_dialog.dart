import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/staff_request/data/staff_request_models.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/venue_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_dialog.dart';

class CallStaffResult {
  final String? venueId;
  final String? resourceId;
  final String? resourceLabel;
  final StaffRequestType requestType;
  final String? description;
  final int? tableNumber;

  const CallStaffResult({
    this.venueId,
    this.resourceId,
    this.resourceLabel,
    required this.requestType,
    this.description,
    this.tableNumber,
  });
}

class _CallStaffDialogContent extends ConsumerStatefulWidget {
  const _CallStaffDialogContent();

  @override
  ConsumerState<_CallStaffDialogContent> createState() =>
      _CallStaffDialogContentState();
}

class _CallStaffDialogContentState
    extends ConsumerState<_CallStaffDialogContent> {
  StaffRequestType? _selectedType;
  VenueResource? _selectedResource;
  late final TextEditingController _tableController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _tableController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _tableController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resourcesAsync = ref.watch(venueResourcesProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gọi nhân viên phục vụ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chọn loại yêu cầu để nhân viên hỗ trợ bạn nhanh hơn.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Request type chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: StaffRequestType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text('${type.emoji} ${type.displayName}'),
                      selected: isSelected,
                      selectedColor: AppColors.primarySurface,
                      onSelected: (_) {
                        setState(() => _selectedType = type);
                      },
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                resourcesAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (resources) => DropdownButtonFormField<VenueResource>(
                    initialValue: resources.contains(_selectedResource)
                        ? _selectedResource
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bàn / sân',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    hint: const Text('Chọn vị trí phục vụ'),
                    items: resources
                        .map(
                          (resource) => DropdownMenuItem(
                            value: resource,
                            child: Text(
                              resource.displayLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (resource) {
                      setState(() {
                        _selectedResource = resource;
                        if (resource != null) {
                          _tableController.text = resource.number.toString();
                        }
                      });
                    },
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _tableController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số bàn / sân (tùy chọn)',
                    hintText: 'VD: 3',
                    prefixIcon: Icon(Icons.table_restaurant, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả thêm (tùy chọn)',
                    hintText: 'VD: Mang thêm 2 lon nước ngọt',
                    prefixIcon: Icon(Icons.edit_note, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedType == null
                          ? null
                          : () {
                              final tableNum = _tableController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : int.tryParse(_tableController.text.trim());
                              Navigator.of(context, rootNavigator: true)
                                  .pop(CallStaffResult(
                                venueId: _selectedResource?.venueId,
                                resourceId: _selectedResource?.id,
                                resourceLabel: _selectedResource?.displayLabel,
                                requestType: _selectedType!,
                                description: _descController.text.trim().isEmpty
                                    ? null
                                    : _descController.text.trim(),
                                tableNumber: tableNum,
                              ));
                            },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Gửi yêu cầu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CallStaffDialog {
  CallStaffDialog._();

  static Future<CallStaffResult?> show(BuildContext context) async {
    return showDialog<CallStaffResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _CallStaffDialogContent(),
    );
  }

  static Future<bool> showCancelConfirm(BuildContext context) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: 'Hủy yêu cầu?',
      content: 'Bạn có chắc muốn hủy yêu cầu gọi nhân viên?',
      icon: Icons.cancel_outlined,
      iconColor: AppColors.warning,
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Không'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hủy yêu cầu'),
        ),
      ],
    );
    return confirmed == true;
  }
}
