import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_dialog.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';
import 'package:sports_venue_chatbot/shared/widgets/floating_card.dart';
import 'package:sports_venue_chatbot/shared/widgets/glass_app_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Cá nhân'),
        actions: [
          GlassIconButton(
            tooltip: 'Làm mới',
            onPressed: () =>
                ref.read(authStateProvider.notifier).refreshProfile(),
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Không thể tải thông tin cá nhân',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Bạn chưa đăng nhập'));
          }
          return _ProfileBody(
            user: user,
            onChangePassword: () => _showChangePasswordDialog(context, ref),
            onScanQr: () => context.push('/scan-qr'),
            onOpenSettings: () => context.push('/settings'),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttonWidth =
                  constraints.maxWidth > 500 ? 500.0 : constraints.maxWidth;

              return Align(
                heightFactor: 1,
                alignment: Alignment.center,
                child: SizedBox(
                  width: buttonWidth,
                  child: FilledButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.showWarning<bool>(
      context,
      title: 'Đăng xuất',
      content: 'Bạn có chắc muốn đăng xuất khỏi tài khoản?',
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: const Text('Đăng xuất'),
        ),
      ],
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    ref.read(changePasswordProvider.notifier).clearError();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      AppSnackBar.showSuccess(context, 'Đã đổi mật khẩu.');
    }
  }
}

class _ProfileBody extends StatelessWidget {
  final User user;
  final VoidCallback onChangePassword;
  final VoidCallback onScanQr;
  final VoidCallback onOpenSettings;

  const _ProfileBody({
    required this.user,
    required this.onChangePassword,
    required this.onScanQr,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxContentWidth = 500.0;
        final hPad = constraints.maxWidth > maxContentWidth
            ? (constraints.maxWidth - maxContentWidth) / 2
            : Responsive.horizontalPadding(context);

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: hPad,
            vertical: AppSpacing.md,
          ),
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              user.name,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm / 2),
            Text(
              user.role,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProfileTile(
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: user.phone,
            ),
            _ProfileTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email?.isNotEmpty == true
                  ? user.email!
                  : 'Chưa cập nhật',
            ),
            _ProfileTile(
              icon: Icons.badge_outlined,
              label: 'Mã người dùng',
              value: user.id,
            ),
            _ProfileTile(
              icon: Icons.qr_code_scanner,
              label: 'Quét QR nhận sân',
              value: 'Mở camera để xác nhận nhận sân với nhân viên',
              onTap: onScanQr,
            ),
            _ProfileTile(
              icon: Icons.settings_outlined,
              label: 'Cài đặt',
              value: 'Bảo mật thanh toán online và gói ngôn ngữ',
              onTap: onOpenSettings,
            ),
            _ProfileTile(
              icon: Icons.lock_outline,
              label: 'Mật khẩu',
              value: 'Đổi mật khẩu đăng nhập',
              onTap: onChangePassword,
            ),
          ],
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: AppColors.textHint),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    setState(() => _localError = null);
    if (next.length < 8) {
      setState(() => _localError = 'Mật khẩu mới tối thiểu 8 ký tự.');
      return;
    }
    if (next != confirm) {
      setState(() => _localError = 'Xác nhận mật khẩu mới chưa khớp.');
      return;
    }

    final success =
        await ref.read(changePasswordProvider.notifier).changePassword(
              currentPassword: current,
              newPassword: next,
            );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordProvider);
    final error = _localError ?? state.error;

    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu hiện tại',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nhập lại mật khẩu mới',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cập nhật'),
        ),
      ],
    );
  }
}
