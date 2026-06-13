import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/core/utils/responsive.dart';
import 'package:sports_venue_chatbot/features/auth/domain/vietnam_phone_number.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/widgets/auth_video_background.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';
import 'package:sports_venue_chatbot/shared/widgets/loading_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registerState = ref.watch(registerProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: AuthVideoBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: hPadding,
                vertical: AppSpacing.lg,
              ),
              child: ResponsiveContainer(
                maxWidth: 420,
                child: AuthGlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Đăng ký khách hàng',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Dùng số Viettel, VinaPhone hoặc MobiFone. ',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: AppColors.primary),
                          enabled: !registerState.isLoading,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập họ và tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(color: AppColors.primary),
                          enabled: !registerState.isLoading,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            hintText: '0901234567 hoặc +84901234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: VietnamPhoneNumber.validateForRegistration,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: AppColors.primary),
                          enabled: !registerState.isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (value.length < 8) {
                              return 'Mật khẩu tối thiểu 8 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: const TextStyle(color: AppColors.primary),
                          enabled: !registerState.isLoading,
                          obscureText: _obscureConfirmation,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!registerState.isLoading) {
                              _handleRegister();
                            }
                          },
                        ),
                        if (registerState.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Text(
                              registerState.error!,
                              style: const TextStyle(
                                color: AppColors.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        LoadingButton(
                          label: 'Tạo tài khoản',
                          onPressed: _handleRegister,
                          isLoading: registerState.isLoading,
                          width: double.infinity,
                          height: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: registerState.isLoading
                              ? null
                              : () => context.go('/login'),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Đã có tài khoản? ',
                              children: [
                                TextSpan(
                                  text: 'Đăng nhập',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (ref.read(registerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    ref.read(registerProvider.notifier).clearError();
    final success = await ref.read(registerProvider.notifier).register(
          phone: _phoneController.text,
          name: _nameController.text,
          password: _passwordController.text,
        );

    if (!success && mounted) {
      AppSnackBar.showError(
        context,
        ref.read(registerProvider).error ?? 'Đăng ký thất bại',
      );
    }
  }
}
