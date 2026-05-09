import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () =>
                ref.read(authStateProvider.notifier).refreshProfile(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Không thể tải thông tin cá nhân',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
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
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final User user;

  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 16),
        Text(
          user.name,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          user.role,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _ProfileTile(
          icon: Icons.phone_outlined,
          label: 'Số điện thoại',
          value: user.phone,
        ),
        _ProfileTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email?.isNotEmpty == true ? user.email! : 'Chưa cập nhật',
        ),
        _ProfileTile(
          icon: Icons.badge_outlined,
          label: 'Mã người dùng',
          value: user.id,
        ),
      ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
