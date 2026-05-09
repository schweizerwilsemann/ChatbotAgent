import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';

/// A section title with consistent styling (w700, textPrimary).
///
/// ```dart
/// const AppSectionTitle('Loại sân'),
/// const SizedBox(height: 8),
/// _buildCourtTypeSelector(),
/// ```
class AppSectionTitle extends StatelessWidget {
  final String text;

  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );
  }
}
