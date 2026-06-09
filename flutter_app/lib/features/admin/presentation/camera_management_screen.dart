import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/camera/data/camera_api.dart';
import 'package:sports_venue_chatbot/features/camera/data/camera_models.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/venue_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart'
    show AppSnackBar, SnackBarType;

// ─── Provider ────────────────────────────────────────────────────────────────

final cameraListProvider =
    AsyncNotifierProvider<CameraListNotifier, List<CameraInfo>>(
  CameraListNotifier.new,
);

class CameraListNotifier extends AsyncNotifier<List<CameraInfo>> {
  @override
  Future<List<CameraInfo>> build() async {
    return ref.watch(cameraApiProvider).listAdminCameras();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cameraApiProvider).listAdminCameras(),
    );
  }

  Future<bool> createCamera(CameraCreateRequest data) async {
    try {
      await ref.read(cameraApiProvider).createCamera(data);
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCamera(String id, CameraUpdateRequest data) async {
    try {
      await ref.read(cameraApiProvider).updateCamera(id, data);
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCamera(String id) async {
    try {
      await ref.read(cameraApiProvider).deleteCamera(id);
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CameraManagementScreen extends ConsumerStatefulWidget {
  const CameraManagementScreen({super.key});

  @override
  ConsumerState<CameraManagementScreen> createState() =>
      _CameraManagementScreenState();
}

class _CameraManagementScreenState
    extends ConsumerState<CameraManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraListProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(cameraListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Camera'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(cameraListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: camerasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Lỗi: $error', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () =>
                    ref.read(cameraListProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (cameras) {
          if (cameras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Chưa có camera nào',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nhấn + để thêm camera mới',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(cameraListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: cameras.length,
              itemBuilder: (context, index) =>
                  _CameraCard(camera: cameras[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCameraDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textOnPrimary),
      ),
    );
  }

  void _showAddCameraDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CameraFormSheet(),
    );
  }
}

// ─── Camera Card ─────────────────────────────────────────────────────────────

class _CameraCard extends ConsumerWidget {
  final CameraInfo camera;

  const _CameraCard({required this.camera});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Icons.videocam,
                  color:
                      camera.isActive ? AppColors.success : AppColors.textHint,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (camera.resourceLabel != null)
                        Text(
                          camera.resourceLabel!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: camera.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    camera.isActive ? 'Hoạt động' : 'Tắt',
                    style: TextStyle(
                      color: camera.isActive
                          ? AppColors.success
                          : AppColors.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _InfoChip(icon: Icons.language, label: camera.ipAddress),
                const SizedBox(width: AppSpacing.sm),
                _InfoChip(
                    icon: Icons.branding_watermark,
                    label: camera.brandDisplayName),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xoá'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CameraFormSheet(editCamera: camera),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá camera'),
        content: Text('Bạn có chắc muốn xoá "${camera.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success =
          await ref.read(cameraListProvider.notifier).deleteCamera(camera.id);
      if (success && context.mounted) {
        AppSnackBar.show(context, 'Đã xoá camera', type: SnackBarType.success);
      }
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

// ─── Camera Form Sheet ───────────────────────────────────────────────────────

class _CameraFormSheet extends ConsumerStatefulWidget {
  final CameraInfo? editCamera;

  const _CameraFormSheet({this.editCamera});

  @override
  ConsumerState<_CameraFormSheet> createState() => _CameraFormSheetState();
}

class _CameraFormSheetState extends ConsumerState<_CameraFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _rtspOverrideCtrl;
  String _brand = 'custom';
  String? _selectedResourceId;
  bool _isSaving = false;

  bool get _isEditing => widget.editCamera != null;

  @override
  void initState() {
    super.initState();
    final cam = widget.editCamera;
    _nameCtrl = TextEditingController(text: cam?.name ?? '');
    _ipCtrl = TextEditingController(text: cam?.ipAddress ?? '');
    _portCtrl = TextEditingController(text: cam?.port.toString() ?? '554');
    _usernameCtrl = TextEditingController(text: cam?.username ?? 'admin');
    _passwordCtrl = TextEditingController();
    _rtspOverrideCtrl = TextEditingController();
    if (cam != null) {
      _brand = cam.cameraBrand;
      _selectedResourceId = cam.resourceId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _rtspOverrideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Sửa Camera' : 'Thêm Camera',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên camera',
                  hintText: 'VD: Camera Sân 1',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên camera' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _ResourceDropdown(
                selectedResourceId: _selectedResourceId,
                onChanged: (id) => setState(() => _selectedResourceId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ IP',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập địa chỉ IP' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '554',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _brand,
                      decoration: const InputDecoration(
                        labelText: 'Hãng camera',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'custom', child: Text('Tùy chỉnh')),
                        DropdownMenuItem(
                            value: 'hik', child: Text('Hikvision')),
                        DropdownMenuItem(value: 'dahua', child: Text('Dahua')),
                        DropdownMenuItem(
                            value: 'seetong', child: Text('Seetong')),
                        DropdownMenuItem(value: 'fpt', child: Text('FPT')),
                      ],
                      onChanged: (v) => setState(() => _brand = v ?? 'custom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'admin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText:
                            _isEditing ? 'Mật khẩu mới (nếu đổi)' : 'Mật khẩu',
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _rtspOverrideCtrl,
                decoration: const InputDecoration(
                  labelText: 'RTSP URL tùy chỉnh (nếu có)',
                  hintText: 'rtsp://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Text(_isEditing ? 'Cập nhật' : 'Thêm camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final notifier = ref.read(cameraListProvider.notifier);
    bool success;

    if (_isEditing) {
      success = await notifier.updateCamera(
        widget.editCamera!.id,
        CameraUpdateRequest(
          resourceId: _selectedResourceId,
          name: _nameCtrl.text.trim(),
          ipAddress: _ipCtrl.text.trim(),
          port: int.tryParse(_portCtrl.text) ?? 554,
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
          cameraBrand: _brand,
          rtspUrlOverride: _rtspOverrideCtrl.text.isNotEmpty
              ? _rtspOverrideCtrl.text.trim()
              : null,
        ),
      );
    } else {
      success = await notifier.createCamera(CameraCreateRequest(
        resourceId: _selectedResourceId,
        name: _nameCtrl.text.trim(),
        ipAddress: _ipCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text) ?? 554,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        cameraBrand: _brand,
        rtspUrlOverride: _rtspOverrideCtrl.text.isNotEmpty
            ? _rtspOverrideCtrl.text.trim()
            : null,
      ));
    }

    setState(() => _isSaving = false);
    if (success && mounted) {
      Navigator.of(context).pop();
      AppSnackBar.show(
        context,
        _isEditing ? 'Đã cập nhật camera' : 'Đã thêm camera',
        type: SnackBarType.success,
      );
    } else if (mounted) {
      AppSnackBar.show(
        context,
        'Có lỗi xảy ra. Vui lòng thử lại.',
        type: SnackBarType.error,
      );
    }
  }
}

// ─── Resource Dropdown ──────────────────────────────────────────────────────

class _ResourceDropdown extends ConsumerWidget {
  final String? selectedResourceId;
  final ValueChanged<String?> onChanged;

  const _ResourceDropdown({
    required this.selectedResourceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(venueResourcesProvider);

    return resourcesAsync.when(
      loading: () => DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        decoration: const InputDecoration(
          labelText: 'Gán cho sân/bàn',
          border: OutlineInputBorder(),
          hintText: 'Đang tải...',
        ),
      ),
      error: (e, _) => DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        decoration: const InputDecoration(
          labelText: 'Gán cho sân/bàn',
          border: OutlineInputBorder(),
          hintText: 'Lỗi tải danh sách',
        ),
      ),
      data: (resources) {
        final activeResources =
            resources.where((r) => r.status == 'active').toList();
        return DropdownButtonFormField<String>(
          value: selectedResourceId,
          decoration: const InputDecoration(
            labelText: 'Gán cho sân/bàn',
            hintText: 'Chọn sân hoặc bàn (tuỳ chọn)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('-- Không gán --'),
            ),
            ...activeResources.map(
              (r) => DropdownMenuItem<String>(
                value: r.id,
                child: Text(r.label),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
