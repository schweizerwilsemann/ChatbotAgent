import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_dialog.dart';
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
          return _ProfileBody(user: user);
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
            foregroundColor: Colors.white,
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
}

class _ProfileBody extends StatelessWidget {
  final User user;

  const _ProfileBody({required this.user});

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

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
