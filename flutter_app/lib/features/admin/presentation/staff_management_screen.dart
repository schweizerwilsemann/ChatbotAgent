import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/admin/data/staff_management_api.dart';
import 'package:sports_venue_chatbot/features/admin/data/staff_management_models.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_api.dart';
import 'package:sports_venue_chatbot/features/venue/data/venue_models.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_confirm_dialog.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final staffListProvider =
    AsyncNotifierProvider<_StaffListNotifier, List<StaffUser>>(
  _StaffListNotifier.new,
);

class _StaffListNotifier extends AsyncNotifier<List<StaffUser>> {
  @override
  Future<List<StaffUser>> build() => _fetch();

  Future<List<StaffUser>> _fetch() async {
    final api = ref.read(staffManagementApiProvider);
    return api.getStaffList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final staffAssignmentsProvider =
    AsyncNotifierProvider<_AssignmentNotifier, List<StaffAssignment>>(
  _AssignmentNotifier.new,
);

class _AssignmentNotifier extends AsyncNotifier<List<StaffAssignment>> {
  @override
  Future<List<StaffAssignment>> build() => _fetch();

  Future<List<StaffAssignment>> _fetch() async {
    final api = ref.read(staffManagementApiProvider);
    return api.getAllAssignments();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final resourceListProvider =
    AsyncNotifierProvider<_ResourceListNotifier, List<VenueResource>>(
  _ResourceListNotifier.new,
);

class _ResourceListNotifier extends AsyncNotifier<List<VenueResource>> {
  @override
  Future<List<VenueResource>> build() async {
    final api = ref.read(venueApiProvider);
    return api.getResources();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final api = ref.read(venueApiProvider);
    state = await AsyncValue.guard(() => api.getResources());
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Nhân viên', icon: Icon(Icons.people_outline)),
              Tab(text: 'Phân công', icon: Icon(Icons.assignment_outlined)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _StaffListTab(),
              _AssignmentsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Staff List Tab ──────────────────────────────────────────────────────────

class _StaffListTab extends ConsumerWidget {
  const _StaffListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'Lỗi tải danh sách nhân viên',
          onRetry: () => ref.read(staffListProvider.notifier).refresh(),
        ),
        data: (staff) {
          if (staff.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: AppColors.textHint),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Chưa có nhân viên nào',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nhấn nút + để thêm nhân viên mới',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(staffListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: staff.length,
              itemBuilder: (context, index) => _StaffCard(staff: staff[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        onPressed: () => _showCreateStaffDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  final StaffUser staff;

  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    staff.phone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (staff.email != null && staff.email!.isNotEmpty)
                    Text(
                      staff.email!,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditStaffDialog(context, ref, staff);
                    break;
                  case 'delete':
                    _confirmDeleteStaff(context, ref, staff);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Sửa'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title:
                        Text('Xoá', style: TextStyle(color: AppColors.error)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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

// ─── Assignments Tab ─────────────────────────────────────────────────────────

class _AssignmentsTab extends ConsumerWidget {
  const _AssignmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(staffAssignmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'Lỗi tải danh sách phân công',
          onRetry: () => ref.read(staffAssignmentsProvider.notifier).refresh(),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 64, color: AppColors.textHint),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Chưa có phân công nào',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nhấn nút + để phân công nhân viên',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(staffAssignmentsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: assignments.length,
              itemBuilder: (context, index) =>
                  _AssignmentCard(assignment: assignments[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        onPressed: () => _showCreateAssignmentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AssignmentCard extends ConsumerWidget {
  final StaffAssignment assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeColor = switch (assignment.scope) {
      'venue' => AppColors.success,
      'area' => AppColors.info,
      'resource' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scopeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                assignment.scope == 'resource'
                    ? Icons.sports_tennis
                    : assignment.scope == 'area'
                        ? Icons.location_on_outlined
                        : Icons.store_outlined,
                color: scopeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        assignment.staffName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scopeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.scopeDisplayName,
                          style: TextStyle(
                            color: scopeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${assignment.venueName} · ${assignment.targetDisplayName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () =>
                  _confirmDeleteAssignment(context, ref, assignment),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

Future<void> _showCreateStaffDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showDialog<StaffCreateRequest>(
    context: context,
    builder: (_) => const _StaffFormDialog(),
  );
  if (result == null || !context.mounted) return;

  try {
    await ref.read(staffManagementApiProvider).createStaff(result);
    ref.invalidate(staffListProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Tạo nhân viên thành công');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'Lỗi tạo nhân viên: $e');
    }
  }
}

Future<void> _showEditStaffDialog(
  BuildContext context,
  WidgetRef ref,
  StaffUser staff,
) async {
  final result = await showDialog<StaffUpdateRequest>(
    context: context,
    builder: (_) => _StaffFormDialog(staff: staff),
  );
  if (result == null || !context.mounted) return;

  try {
    await ref.read(staffManagementApiProvider).updateStaff(staff.id, result);
    ref.invalidate(staffListProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Cập nhật thành công');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'Lỗi cập nhật: $e');
    }
  }
}

Future<void> _confirmDeleteStaff(
  BuildContext context,
  WidgetRef ref,
  StaffUser staff,
) async {
  final confirmed = await AppConfirmDialog.show(
    context: context,
    title: 'Xoá nhân viên',
    content:
        'Bạn có chắc muốn xoá nhân viên "${staff.name}"? Tài khoản sẽ được chuyển về khách hàng.',
    confirmLabel: 'Xoá',
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(staffManagementApiProvider).deleteStaff(staff.id);
    ref.invalidate(staffListProvider);
    ref.invalidate(staffAssignmentsProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Đã xoá nhân viên');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'Lỗi xoá: $e');
    }
  }
}

Future<void> _showCreateAssignmentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showDialog<StaffAssignmentCreateRequest>(
    context: context,
    builder: (_) => const _AssignmentFormDialog(),
  );
  if (result == null || !context.mounted) return;

  try {
    await ref.read(staffManagementApiProvider).createAssignment(result);
    ref.invalidate(staffAssignmentsProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Tạo phân công thành công');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'Lỗi tạo phân công: $e');
    }
  }
}

Future<void> _confirmDeleteAssignment(
  BuildContext context,
  WidgetRef ref,
  StaffAssignment assignment,
) async {
  final confirmed = await AppConfirmDialog.show(
    context: context,
    title: 'Xoá phân công',
    content:
        'Bạn có chắc muốn xoá phân công "${assignment.staffName} → ${assignment.targetDisplayName}"?',
    confirmLabel: 'Xoá',
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(staffManagementApiProvider).deleteAssignment(assignment.id);
    ref.invalidate(staffAssignmentsProvider);
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Đã xoá phân công');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'Lỗi xoá: $e');
    }
  }
}

// ─── Staff Form Dialog ───────────────────────────────────────────────────────

class _StaffFormDialog extends StatefulWidget {
  final StaffUser? staff;

  const _StaffFormDialog({this.staff});

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  bool _obscurePassword = true;

  bool get _isEdit => widget.staff != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.staff?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.staff?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.staff?.email ?? '');
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_isEdit) {
      Navigator.of(context).pop(StaffUpdateRequest(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      ));
    } else {
      Navigator.of(context).pop(StaffCreateRequest(
        phone: _phoneCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !_isEdit,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nhập số điện thoại';
                    }
                    if (v.trim().length < 7) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                      if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: Text(_isEdit ? 'Cập nhật' : 'Tạo'),
        ),
      ],
    );
  }
}

// ─── Assignment Form Dialog ──────────────────────────────────────────────────

class _AssignmentFormDialog extends ConsumerStatefulWidget {
  const _AssignmentFormDialog();

  @override
  ConsumerState<_AssignmentFormDialog> createState() =>
      _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends ConsumerState<_AssignmentFormDialog> {
  String? _selectedStaffId;
  String? _selectedResourceId;
  String _scope = 'venue';

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final resourcesAsync = ref.watch(resourceListProvider);

    final staffList = staffAsync.valueOrNull ?? [];
    final resourceList = resourcesAsync.valueOrNull ?? [];

    return AlertDialog(
      title: const Text('Phân công nhân viên'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Staff dropdown
              DropdownButtonFormField<String>(
                value: _selectedStaffId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Nhân viên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: staffList
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.phone})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStaffId = v),
                validator: (v) => v == null ? 'Chọn nhân viên' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Scope selector
              const Text(
                'Phạm vi phân công',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'venue',
                    label: Text('Toàn sân'),
                    icon: Icon(Icons.store, size: 16),
                  ),
                  ButtonSegment(
                    value: 'resource',
                    label: Text('Sân cụ thể'),
                    icon: Icon(Icons.sports_tennis, size: 16),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (v) => setState(() {
                  _scope = v.first;
                  if (_scope == 'venue') _selectedResourceId = null;
                }),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Resource dropdown (only when scope=resource)
              if (_scope == 'resource') ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _selectedResourceId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sân / Bàn *',
                    prefixIcon: Icon(Icons.sports_tennis),
                  ),
                  items: resourceList
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              r.displayLabel,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedResourceId = v),
                  validator: (v) =>
                      _scope == 'resource' && v == null ? 'Chọn sân/bàn' : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: _submitAssignment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: const Text('Tạo phân công'),
        ),
      ],
    );
  }

  void _submitAssignment() {
    if (_selectedStaffId == null) {
      AppSnackBar.showWarning(context, 'Vui lòng chọn nhân viên');
      return;
    }
    if (_scope == 'resource' && _selectedResourceId == null) {
      AppSnackBar.showWarning(context, 'Vui lòng chọn sân/bàn');
      return;
    }

    Navigator.of(context).pop(StaffAssignmentCreateRequest(
      staffId: _selectedStaffId!,
      venueId: '',
      resourceId: _selectedResourceId,
      scope: _scope,
    ));
  }
}
