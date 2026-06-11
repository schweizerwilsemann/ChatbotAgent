import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/constants/app_spacing.dart';
import 'package:sports_venue_chatbot/features/explore/data/mini_app_dummy_data.dart';
import 'package:sports_venue_chatbot/features/explore/data/mini_app_models.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart'
    show AppSnackBar;

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  MiniAppCategory? _selectedCategory;

  List<MiniApp> get _filteredApps {
    if (_selectedCategory == null) return dummyMiniApps;
    return dummyMiniApps
        .where((app) => app.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header banner ──────────────────────────────
          SliverToBoxAdapter(child: _buildBanner(context)),
          // ── Category filter chips ──────────────────────
          SliverToBoxAdapter(child: _buildCategoryChips()),
          // ── Featured mini apps ─────────────────────────
          SliverToBoxAdapter(child: _buildFeaturedSection(context)),
          // ── All mini apps grid ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                _selectedCategory == null
                    ? 'Tất cả ứng dụng'
                    : miniAppCategories
                        .firstWhere((c) => c.category == _selectedCategory)
                        .label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          _buildMiniAppGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Banner ──────────────────────────────────────────────
  Widget _buildBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC0392B), Color(0xFFE74C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám phá Super App',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trải nghiệm các ứng dụng mini\nngay trong app thể thao của bạn',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${dummyMiniApps.where((a) => a.isActive).length} ứng dụng đang hoạt động',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.apps_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  // ── Category filter chips ──────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _buildChip(null, 'Tất cả', Icons.apps_outlined),
          ...miniAppCategories.map(
            (cat) => _buildChip(cat.category, cat.label, cat.icon),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(MiniAppCategory? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selectedColor: AppColors.primarySurface,
        backgroundColor: AppColors.surfaceVariant,
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        onSelected: (_) {
          setState(() => _selectedCategory = category);
        },
      ),
    );
  }

  // ── Featured section (horizontal scroll) ───────────────
  Widget _buildFeaturedSection(BuildContext context) {
    final featured = dummyMiniApps
        .where((a) => a.rating != null && a.rating! >= 4.5)
        .toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 6),
              Text(
                'Nổi bật',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _FeaturedCard(app: featured[index]),
          ),
        ),
      ],
    );
  }

  // ── Mini app grid ──────────────────────────────────────
  Widget _buildMiniAppGrid() {
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'Chưa có ứng dụng nào trong danh mục này',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _MiniAppCard(app: apps[index]),
          childCount: apps.length,
        ),
      ),
    );
  }
}

// ── Featured card (horizontal) ────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final MiniApp app;
  const _FeaturedCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: app.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: app.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: app.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(app.icon, color: app.color, size: 20),
                ),
                const Spacer(),
                if (app.rating != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFFFB300)),
                        const SizedBox(width: 2),
                        Text(
                          app.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              app.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                app.description,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${_formatCount(app.userCount)} người dùng',
              style: TextStyle(
                fontSize: 10,
                color: app.color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (!app.isActive) {
      AppSnackBar.show(
        context,
        app.isComingSoon
            ? '${app.name} sắp ra mắt!'
            : '${app.name} đang bảo trì',
      );
      return;
    }
    if (app.hasWebView) {
      context.push('/mini-app', extra: {
        'title': app.name,
        'assetPath': app.assetPath,
      });
    } else {
      AppSnackBar.show(context, '${app.name} đang phát triển...');
    }
  }
}

// ── Mini app card (grid item) ─────────────────────────────
class _MiniAppCard extends StatelessWidget {
  final MiniApp app;
  const _MiniAppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: app.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(app.icon, color: app.color, size: 26),
                ),
                if (app.isComingSoon)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Sớm',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (app.status == MiniAppStatus.maintenance)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              app.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            // User count or status
            Text(
              app.isActive
                  ? '${_formatCount(app.userCount)} dùng'
                  : app.isComingSoon
                      ? 'Sắp ra mắt'
                      : 'Bảo trì',
              style: TextStyle(
                fontSize: 10,
                color: app.isActive
                    ? AppColors.textSecondary
                    : app.isComingSoon
                        ? const Color(0xFFFFB300)
                        : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (!app.isActive) {
      AppSnackBar.show(
        context,
        app.isComingSoon
            ? '${app.name} sắp ra mắt!'
            : '${app.name} đang bảo trì',
      );
      return;
    }
    if (app.hasWebView) {
      context.push('/mini-app', extra: {
        'title': app.name,
        'assetPath': app.assetPath,
      });
    } else {
      AppSnackBar.show(context, '${app.name} đang phát triển...');
    }
  }
}

String _formatCount(int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}
