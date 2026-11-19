import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../core/session/branch_status.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import 'menu_stats.dart';

/// The landing screen after sign in: branch status, menu numbers, shortcuts
/// and the setup checklist. Only menu data exists in Phase 1, so there are no
/// sales figures here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branch = ref.watch(selectedBranchProvider);
    if (business == null) {
      return const AppPage(title: 'Home', scroll: false, body: LoadingView());
    }

    final key = (businessId: business.id, branchId: branch?.id);
    final stats = ref.watch(menuStatsProvider(key));

    Future<void> refresh() async {
      ref.invalidate(menuStatsProvider(key));
      if (branch != null) ref.invalidate(branchStatusProvider(branch.id));
      ref.refreshBusiness();
      await ref
          .read(menuStatsProvider(key).future)
          .catchError((_) => const MenuStats());
    }

    return AppPage(
      title: business.name,
      subtitle: branch == null ? null : branch.name,
      onRefresh: refresh,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (branch != null) _BranchStatusCard(branch: branch),
          const SizedBox(height: Sp.lg),
          _QuickActions(branch: branch),
          const SizedBox(height: Sp.xl),
          stats.when(
            skipLoadingOnReload: true,
            loading: () => const SkeletonList(rows: 4),
            error: (error, _) => ErrorState(
              title: 'Could not load menu numbers',
              message: friendlyError(error),
              onRetry: () => ref.invalidate(menuStatsProvider(key)),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SetupChecklist(stats: value),
                _StatsGroup(stats: value),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),
          _ShareCard(business: business, branch: branch),
          const SizedBox(height: Sp.xl),
          const _LaterNote(),
        ],
      ),
    );
  }
}

class _BranchStatusCard extends ConsumerWidget {
  const _BranchStatusCard({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(branchStatusProvider(branch.id));
    return ListGroup(
      children: [
        ListRow(
          title: status.when(
            skipLoadingOnReload: true,
            loading: () => 'Checking opening hours',
            error: (_, __) => 'Opening status unavailable',
            data: (s) => s.summary,
          ),
          subtitle: 'Based on the hours you set for ${branch.name}',
          leading: const IconBadge(Icons.schedule_rounded),
          trailing: status.maybeWhen(
            data: (s) => StatusPill(
              s.isOpen ? 'Open' : (s.isTemporarilyClosed ? 'Paused' : 'Closed'),
              tone: s.isOpen ? PillTone.success : PillTone.warning,
            ),
            orElse: () => null,
          ),
          onTap: () => context.push(AppRoutes.branchHours(branch.id)),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.branch});

  final Branch? branch;

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, String path})>[
      (icon: Icons.add_rounded, label: 'Add dish', path: AppRoutes.itemNew),
      (icon: Icons.qr_code_2_rounded, label: 'View QR', path: AppRoutes.qr),
      (
        icon: Icons.block_rounded,
        label: 'Mark sold out',
        path: AppRoutes.availability,
      ),
      (
        icon: Icons.visibility_outlined,
        label: 'Preview menu',
        path: AppRoutes.preview,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final gap = Sp.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _ActionTile(
                  icon: action.icon,
                  label: action.label,
                  onTap: () => context.push(action.path),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(Rad.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.panel),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: Sp.lg,
            horizontal: Sp.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.panel),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({required this.stats});

  final MenuStats stats;

  @override
  Widget build(BuildContext context) {
    final steps = <({bool done, String title, String subtitle, String path})>[
      (
        done: stats.hasMenu,
        title: 'Add your dishes',
        subtitle: 'Create categories and add the dishes you serve.',
        path: AppRoutes.items,
      ),
      (
        done: stats.hasMenu && stats.itemsWithoutImage == 0,
        title: 'Add photos to dishes',
        subtitle: stats.itemsWithoutImage == 0
            ? 'Every dish has a photo.'
            : '${stats.itemsWithoutImage} dishes have no photo yet.',
        path: AppRoutes.items,
      ),
      (
        done: stats.qrScans > 0,
        title: 'Print or share your QR code',
        subtitle: 'Place it on tables or share the link with customers.',
        path: AppRoutes.qr,
      ),
    ];
    if (steps.every((s) => s.done)) return const SizedBox.shrink();
    final finished = steps.where((s) => s.done).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: ListGroup(
        title: 'Finish setting up ($finished of ${steps.length} done)',
        children: [
          for (final step in steps)
            ListRow(
              title: step.title,
              subtitle: step.subtitle,
              leading: IconBadge(
                step.done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: step.done ? context.palette.success : null,
              ),
              onTap: step.done ? null : () => context.push(step.path),
            ),
        ],
      ),
    );
  }
}

class _StatsGroup extends StatelessWidget {
  const _StatsGroup({required this.stats});

  final MenuStats stats;

  @override
  Widget build(BuildContext context) {
    return ListGroup(
      title: 'Your menu',
      children: [
        ListRow(
          title: 'Dishes',
          subtitle: '${stats.visibleItems} visible to customers',
          leading: const IconBadge(Icons.restaurant_menu_rounded),
          trailing: Text(
            '${stats.items}',
            style: context.textStyles.titleMedium,
          ),
          onTap: () => context.push(AppRoutes.items),
        ),
        ListRow(
          title: 'Categories',
          leading: const IconBadge(Icons.category_outlined),
          trailing: Text(
            '${stats.categories}',
            style: context.textStyles.titleMedium,
          ),
          onTap: () => context.push(AppRoutes.categories),
        ),
        ListRow(
          title: 'Sold out now',
          leading: const IconBadge(Icons.block_rounded),
          trailing: Text(
            '${stats.soldOutItems}',
            style: context.textStyles.titleMedium,
          ),
          onTap: () => context.push(AppRoutes.availability),
        ),
        ListRow(
          title: 'Tables',
          leading: const IconBadge(Icons.table_restaurant_outlined),
          trailing: Text(
            '${stats.tables}',
            style: context.textStyles.titleMedium,
          ),
          onTap: () => context.go(AppRoutes.qr),
        ),
        ListRow(
          title: 'QR code scans',
          subtitle: 'Total menu opens from QR codes',
          leading: const IconBadge(Icons.qr_code_scanner_rounded),
          trailing: Text(
            '${stats.qrScans}',
            style: context.textStyles.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.business, required this.branch});

  final Business business;
  final Branch? branch;

  @override
  Widget build(BuildContext context) {
    final link = branch == null
        ? PublicLinks.businessMenu(business.slug)
        : PublicLinks.branchMenu(business.slug, branch!.slug);
    return ListGroup(
      title: 'Share your menu',
      children: [
        ListRow(
          title: link,
          subtitle: business.menuPublished
              ? 'Anyone with this link can see your menu'
              : 'Your menu is unpublished and hidden from customers',
          leading: const IconBadge(Icons.link_rounded),
          onTap: () => context.push(AppRoutes.publicLink),
        ),
        Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Copy link',
                  icon: Icons.copy_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) showToast(context, 'Link copied');
                  },
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: () => Share.share(link),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaterNote extends StatelessWidget {
  const _LaterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Orders, payments, kitchen display, staff and reports are added in later '
      'releases. Your menu and QR codes work today.',
      textAlign: TextAlign.center,
      style: context.textStyles.bodySmall?.copyWith(
        color: context.palette.muted,
      ),
    );
  }
}
