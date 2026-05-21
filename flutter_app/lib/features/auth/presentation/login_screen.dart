import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';
import 'package:sports_venue_chatbot/shared/widgets/floating_card.dart';
import 'package:sports_venue_chatbot/shared/widgets/loading_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Note: navigation after login is handled entirely by GoRouter redirect logic.
    // No ref.listen needed here — it would cause double-navigation and redirect loops.

    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: ResponsiveContainer(
              maxWidth: 420,
              child: FloatingCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sports_tennis,
                        size: 72,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Sports Venue Chatbot',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Đăng nhập để tiếp tục',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !loginState.isLoading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          hintText: 'Nhập số điện thoại',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập số điện thoại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !loginState.isLoading,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu',
                          hintText: 'Nhập mật khẩu',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!loginState.isLoading) {
                            _handleLogin();
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (loginState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            loginState.error!,
                            style: TextStyle(color: colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      LoadingButton(
                        label: 'Đăng nhập',
                        onPressed: _handleLogin,
                        isLoading: loginState.isLoading,
                        width: double.infinity,
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (ref.read(loginProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    ref.read(loginProvider.notifier).clearError();

    final success = await ref
        .read(loginProvider.notifier)
        .login(_phoneController.text, _passwordController.text);

    if (!success && mounted) {
      // Error is already reflected in loginState; optionally show a snackbar
      AppSnackBar.showError(
          context, ref.read(loginProvider).error ?? 'Đăng nhập thất bại');
    }
  }
}
