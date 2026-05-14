import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';

/// Profile / settings screen for admin and staff.
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ quản lý'),
      ),
      body: user == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: 16,
              ),
              children: [
                ResponsiveContainer(
                  maxWidth: 500,
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Info cards
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại',
                        value: user.phone,
                      ),
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email?.isNotEmpty == true
                            ? user.email!
                            : 'Chưa cập nhật',
                      ),
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Mã nhân viên',
                        value: user.id,
                      ),
                      const SizedBox(height: 20),

                      // Settings section
                      const Divider(),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.bar_chart,
                        label: 'Biểu đồ & Phân tích',
                        onTap: () => context.push('/admin/analytics'),
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        label: 'Thông báo vận hành',
                        onTap: () => context.push('/admin/notifications'),
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        label: 'Thông tin ứng dụng',
                        onTap: () => _showAboutDialog(context),
                      ),
                      const SizedBox(height: 28),

                      // Logout button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _confirmLogout(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông tin ứng dụng'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sports Venue Chatbot',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Phiên bản: 1.0.0'),
            Text('Ứng dụng quản lý sân thể thao'),
            SizedBox(height: 12),
            Text('© 2025 Sports Venue Chatbot',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        subtitle:
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
