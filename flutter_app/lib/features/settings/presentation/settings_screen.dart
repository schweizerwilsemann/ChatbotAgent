import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/settings/presentation/app_settings_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    ref.listen<AppSettingsState>(appSettingsProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppSnackBar.showError(context, next.error!);
        ref.read(appSettingsProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: AppSpacing.md,
              ),
              children: [
                ResponsiveContainer(
                  maxWidth: 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle(
                        icon: Icons.security,
                        title: 'Bảo mật',
                        subtitle:
                            'Áp dụng cho Stripe, VNPay và thanh toán online.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        child: SwitchListTile(
                          value: settings.requireAuthForOnlinePayment,
                          onChanged: settings.deviceAuthSupported
                              ? (value) => ref
                                  .read(appSettingsProvider.notifier)
                                  .setRequireAuthForOnlinePayment(value)
                              : null,
                          secondary: const Icon(
                            Icons.fingerprint,
                            color: AppColors.primary,
                          ),
                          title: const Text('Xác thực trước thanh toán online'),
                          subtitle: Text(settings.authCapabilityLabel),
                        ),
                      ),
                      if (!settings.deviceAuthSupported)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: Text(
                            'Bật khóa màn hình hoặc sinh trắc học trong cài đặt điện thoại để dùng tính năng này.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionTitle(
                        icon: Icons.language,
                        title: 'Ngôn ngữ',
                        subtitle:
                            'Chọn ngôn ngữ giao diện đang được hỗ trợ.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        child: Column(
                          children: [
                            for (final language in AppLanguage.supportedLanguages)
                              _LanguageTile(
                                language: language,
                                selected: language == settings.language,
                                onTap: () => ref
                                    .read(appSettingsProvider.notifier)
                                    .setLanguage(language),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Ghi chú: English chưa được bật vì app chưa có bộ chuỗi i18n đầy đủ. Khi thêm bản dịch, màn này có thể mở lại lựa chọn English.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionTitle(
                        icon: Icons.info_outline,
                        title: 'Ứng dụng',
                        subtitle: 'Sports Venue Chatbot 1.0.0',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        language == AppLanguage.system ? Icons.phone_android : Icons.translate,
        color: AppColors.primary,
      ),
      title: Text(language.label),
      subtitle: Text(language.description),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.textHint,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
