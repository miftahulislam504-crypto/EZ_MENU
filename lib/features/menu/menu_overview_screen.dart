import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/widgets/widgets.dart';
import '../home/menu_stats.dart';
import 'category_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/menu_ui.dart';

/// The Menu tab: numbers, shortcuts, and a summary of every category.
class MenuOverviewScreen extends ConsumerStatefulWidget {
  const MenuOverviewScreen({super.key});

  @override
  ConsumerState<MenuOverviewScreen> createState() => _MenuOverviewScreenState();
}

class _MenuOverviewScreenState extends ConsumerState<MenuOverviewScreen> {
  bool _seeding = false;

  Future<void> _seedSample(String businessId) async {
    final ok = await confirmAction(
      context,
      title: 'Add a sample menu?',
      message:
          'This adds example categories and dishes you can edit or delete. '
          'It is a quick way to see how the menu looks.',
      confirmLabel: 'Add sample menu',
    );
    if (!ok || !mounted) return;
    setState(() => _seeding = true);
    final done = await runWithToast(context, () async {
      await ref.read(supabaseClientProvider).rpc(
        'seed_sample_menu',
        params: {'p_business_id': businessId},
      );
    }, onError: friendlyError, successMessage: 'Sample menu added');
    if (done) ref.refreshMenu();
    if (mounted) setState(() => _seeding = false);
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branch = ref.watch(selectedBranchProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    final statsKey = business == null
        ? null
        : (businessId: business.id, branchId: branch?.id);
    final stats = statsKey == null ? null : ref.watch(menuStatsProvider(statsKey));

    final categories = categoriesAsync.valueOrNull;
    final items = itemsAsync.valueOrNull ?? const <MenuItem>[];

    Future<void> refresh() async => ref.refreshMenu();

    Widget content;
    if (business == null || (categories == null && categoriesAsync.isLoading)) {
      content = const SkeletonList(rows: 5);
    } else if (categories == null) {
      content = ErrorState(
        message: friendlyError(categoriesAsync.error),
        onRetry: () => ref.invalidate(menuCategoriesProvider),
      );
    } else if (categories.isEmpty) {
      content = _FirstRun(
        seeding: _seeding,
        onAddCategory: () => context.push(AppRoutes.categoryNew),
        onSample: () => _seedSample(business.id),
      );
    } else {
      final tree = buildCategoryTree(categories);
      final direct = countItemsByCategory(items);
      final totals = countItemsWithChildren(tree, direct);
      final data = stats?.valueOrNull ?? const MenuStats();
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
        children: [
          _Nudges(business: business, stats: data),
          _StatGrid(stats: data, loading: (stats?.isLoading ?? false) && stats?.valueOrNull == null),
          const SizedBox(height: Sp.xl),
          const SectionTitle('Shortcuts'),
          _QuickActions(trashCount: data.trash),
          const SizedBox(height: Sp.xl),
          SectionTitle(
            'Categories',
            trailing: TextButton(
              onPressed: () => context.push(AppRoutes.categories),
              child: const Text('Manage categories'),
            ),
          ),
          _CategorySummary(tree: tree, totals: totals),
        ],
      );
    }

    return AppPage(
      title: 'Menu',
      subtitle: branch == null
          ? null
          : (branches.length > 1 ? 'Showing ${branch.name}' : branch.name),
      scroll: false,
      body: RefreshIndicator(onRefresh: refresh, child: content),
    );
  }
}

class _FirstRun extends StatelessWidget {
  const _FirstRun({
    required this.seeding,
    required this.onAddCategory,
    required this.onSample,
  });

  final bool seeding;
  final VoidCallback onAddCategory;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(Icons.restaurant_menu_rounded, size: 72),
              const SizedBox(height: Sp.lg),
              Text(
                'Build your menu',
                style: context.textStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.sm),
              Text(
                'Start with a category such as Starters or Drinks, then add '
                'your dishes. Or try a ready-made sample menu and change it '
                'to match your restaurant.',
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium?.copyWith(color: context.palette.muted),
              ),
              const SizedBox(height: Sp.xl),
              AppButton(
                label: 'Add my first category',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: seeding ? null : onAddCategory,
              ),
              const SizedBox(height: Sp.md),
              AppButton(
                label: 'Use a sample menu',
                icon: Icons.auto_awesome_outlined,
                kind: AppButtonKind.secondary,
                expand: true,
                loading: seeding,
                onPressed: onSample,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nudges extends StatelessWidget {
  const _Nudges({required this.business, required this.stats});

  final Business business;
  final MenuStats stats;

  @override
  Widget build(BuildContext context) {
    final notes = <Widget>[];
    if (!business.menuPublished) {
      notes.add(
        _Nudge(
          icon: Icons.public_off_outlined,
          tone: PillTone.warning,
          text: 'Your menu is not published, so customers cannot see it yet.',
          action: 'Publish',
          onTap: () => context.push(AppRoutes.publicLink),
        ),
      );
    }
    if (stats.itemsWithoutImage > 0) {
      notes.add(
        _Nudge(
          icon: Icons.add_photo_alternate_outlined,
          tone: PillTone.info,
          text: stats.itemsWithoutImage == 1
              ? '1 dish has no photo. Dishes with photos get more attention.'
              : '${stats.itemsWithoutImage} dishes have no photo. Dishes with photos get more attention.',
          action: 'Review',
          onTap: () => context.push(AppRoutes.items),
        ),
      );
    }
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: Column(
        children: [
          for (final note in notes) ...[note, const SizedBox(height: Sp.sm)],
        ],
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final warn = tone == PillTone.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
      decoration: BoxDecoration(
        color: warn ? palette.warningSoft : context.colors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: warn ? palette.warning : context.colors.onPrimaryContainer),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium)),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.loading});

  final MenuStats stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      StatTile(
        label: 'Categories',
        value: '${stats.categories}',
        icon: Icons.category_outlined,
        onTap: () => context.push(AppRoutes.categories),
      ),
      StatTile(
        label: 'Dishes',
        value: '${stats.items}',
        icon: Icons.restaurant_menu_rounded,
        onTap: () => context.push(AppRoutes.items),
      ),
      StatTile(
        label: 'Visible to customers',
        value: '${stats.visibleItems}',
        icon: Icons.visibility_outlined,
        tone: PillTone.success,
        onTap: () => context.push(AppRoutes.items),
      ),
      StatTile(
        label: 'Sold out here',
        value: '${stats.soldOutItems}',
        icon: Icons.block_rounded,
        tone: stats.soldOutItems > 0 ? PillTone.danger : PillTone.neutral,
        onTap: () => context.push(AppRoutes.availability),
      ),
      StatTile(
        label: 'Without a photo',
        value: '${stats.itemsWithoutImage}',
        icon: Icons.image_not_supported_outlined,
        tone: stats.itemsWithoutImage > 0 ? PillTone.warning : PillTone.neutral,
        onTap: () => context.push(AppRoutes.items),
      ),
      StatTile(
        label: 'In the trash',
        value: '${stats.trash}',
        icon: Icons.delete_outline_rounded,
        onTap: () => context.push(AppRoutes.trash),
      ),
    ];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: loading ? 0.6 : 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 3 : 2;
          const gap = Sp.md;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.trashCount});

  final int trashCount;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, String route})>[
      (icon: Icons.add_circle_outline_rounded, label: 'Add dish', route: AppRoutes.itemNew),
      (icon: Icons.create_new_folder_outlined, label: 'Add category', route: AppRoutes.categoryNew),
      (icon: Icons.list_alt_rounded, label: 'All dishes', route: AppRoutes.items),
      (icon: Icons.block_rounded, label: 'Availability', route: AppRoutes.availability),
      (icon: Icons.price_change_outlined, label: 'Bulk prices', route: AppRoutes.bulkPrices),
      (icon: Icons.swap_vert_rounded, label: 'Import and export', route: AppRoutes.importExport),
      (icon: Icons.visibility_outlined, label: 'Customer preview', route: AppRoutes.preview),
      (icon: Icons.delete_outline_rounded, label: 'Trash', route: AppRoutes.trash),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const gap = Sp.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: Material(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(Rad.panel),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.panel),
                    onTap: () => context.push(action.route),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Rad.panel),
                        border: Border.all(color: context.palette.line),
                      ),
                      child: Row(
                        children: [
                          Icon(action.icon, size: 22, color: context.colors.primary),
                          const SizedBox(width: Sp.sm),
                          Expanded(
                            child: Text(
                              action.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.labelLarge,
                            ),
                          ),
                          if (action.route == AppRoutes.trash && trashCount > 0)
                            StatusPill('$trashCount', tone: PillTone.warning),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.tree, required this.totals});

  final List<CategoryNode> tree;
  final Map<String, int> totals;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        for (final node in tree)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: Material(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(Rad.panel),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.panel),
                onTap: () => context.push('${AppRoutes.items}?category=${node.category.id}'),
                child: Container(
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Rad.panel),
                    border: Border.all(color: palette.line),
                  ),
                  child: Row(
                    children: [
                      MenuThumb(
                        url: node.category.imageUrl,
                        icon: categoryIconFor(node.category.icon) ?? Icons.category_outlined,
                        size: 48,
                        dimmed: !node.category.isActive,
                      ),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.category.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                '${totals[node.category.id] ?? 0} ${(totals[node.category.id] ?? 0) == 1 ? 'dish' : 'dishes'}',
                                if (node.children.isNotEmpty)
                                  '${node.children.length} ${node.children.length == 1 ? 'subcategory' : 'subcategories'}',
                              ].join('  -  '),
                              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                      if (!node.category.isActive)
                        const Padding(
                          padding: EdgeInsets.only(right: Sp.sm),
                          child: StatusPill('Hidden', tone: PillTone.warning),
                        ),
                      Icon(Icons.chevron_right_rounded, color: palette.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
