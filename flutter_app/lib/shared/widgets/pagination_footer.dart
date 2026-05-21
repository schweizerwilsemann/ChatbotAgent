import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';

class PaginationFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final String endLabel;

  const PaginationFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.endLabel = 'Đã tải hết dữ liệu',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            endLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ),
      );
    }

    return const SizedBox(height: AppSpacing.md);
  }
}
