import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import '../public_menu/public_menu_logic.dart';
import '../public_menu/public_menu_models.dart';
import '../public_menu/public_menu_repository.dart';
import '../public_menu/widgets/menu_states.dart';
import '../public_menu/widgets/public_menu_view.dart';
import 'widgets/phone_frame.dart';

/// Shows the menu the way a customer sees it, inside a phone frame, using the
/// same screen customers get. Works while the menu is unpublished.
class CustomerPreviewScreen extends ConsumerStatefulWidget {
  const CustomerPreviewScreen({super.key});

  @override
  ConsumerState<CustomerPreviewScreen> createState() => _CustomerPreviewScreenState();
}

class _CustomerPreviewScreenState extends ConsumerState<CustomerPreviewScreen> {
  static const String _title = 'Customer preview';
  static const String _subtitle = 'Your menu exactly as customers see it';

  String? _branchId;

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showToast(context, 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(currentBusinessProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final business = businessAsync.valueOrNull;
    final branches = branchesAsync.valueOrNull;

    if (businessAsync.hasError || branchesAsync.hasError) {
      return AppPage(
        title: _title,
        scroll: false,
        body: ErrorState(
          message: friendlyError(businessAsync.error ?? branchesAsync.error),
          onRetry: () => ref.refreshBusiness(),
        ),
      );
    }
    if (business == null || branches == null) {
      if (businessAsync.isLoading || branchesAsync.isLoading) {
        return const AppPage(title: _title, scroll: false, body: LoadingView());
      }
      return const AppPage(
        title: _title,
        scroll: false,
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Finish setting up first',
          message: 'Add your restaurant details to preview your menu.',
        ),
      );
    }

    final active = [for (final branch in branches) if (branch.isActive) branch];
    if (active.isEmpty) {
      return AppPage(
        title: _title,
        scroll: false,
        body: EmptyState(
          icon: Icons.store_mall_directory_outlined,
          title: 'No active branch',
          message: 'Switch a branch on to preview its menu.',
          actionLabel: 'Open branches',
          onAction: () => context.go(AppRoutes.branches),
        ),
      );
    }

    final fallback = ref.watch(selectedBranchProvider);
    Branch branch = active.first;
    for (final candidate in active) {
      if (candidate.id == (_branchId ?? fallback?.id)) branch = candidate;
    }
    final request = PublicMenuRequest(
      businessSlug: business.slug,
      branchSlug: branch.slug,
      preview: true,
    );
    final menu = ref.watch(publicMenuPreviewProvider(request));
    final link = PublicLinks.branchMenu(business.slug, branch.slug);
    final wide = MediaQuery.sizeOf(context).width >= 980;

    final controls = _Controls(
      business: business,
      active: active,
      branch: branch,
      link: link,
      onBranch: (id) => setState(() => _branchId = id),
      onCopy: () => _copy(link),
      menu: menu.valueOrNull?.data,
    );
    final frame = _Frame(
      branch: branch,
      menu: menu,
      onRetry: () => ref.invalidate(publicMenuPreviewProvider(request)),
    );

    return AppPage(
      title: _title,
      subtitle: _subtitle,
      maxWidth: 1040,
      actions: [
        IconButton(
          tooltip: 'Refresh preview',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(publicMenuPreviewProvider(request)),
        ),
      ],
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: controls),
                const SizedBox(width: Sp.xl),
                frame,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                controls,
                const SizedBox(height: Sp.lg),
                Center(child: frame),
              ],
            ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.branch, required this.menu, required this.onRetry});

  final Branch branch;
  final AsyncValue<PublicMenuResult> menu;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - Sp.lg * 2).clamp(300.0, 390.0);
    final height = (size.height - 190).clamp(560.0, 780.0);

    Widget content;
    if (menu.hasError && !menu.isLoading) {
      content = ErrorState(
        title: 'Could not load the preview',
        message: friendlyError(menu.error),
        onRetry: onRetry,
      );
    } else if (!menu.hasValue) {
      content = const MenuLoadingView();
    } else {
      final result = menu.requireValue;
      final data = result.data;
      content = data == null
          ? MenuProblemView(problem: result.problem ?? PublicMenuProblem.unknown, onRetry: onRetry)
          : PublicMenuView(key: ValueKey('preview-${branch.id}'), data: data, embedded: true);
    }
    return PhoneFrame(
      width: width,
      height: height,
      child: ColoredBox(color: context.colors.surface, child: content),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.business,
    required this.active,
    required this.branch,
    required this.link,
    required this.onBranch,
    required this.onCopy,
    required this.menu,
  });

  final Business business;
  final List<Branch> active;
  final Branch branch;
  final String link;
  final ValueChanged<String> onBranch;
  final VoidCallback onCopy;
  final PublicMenuData? menu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!business.menuPublished)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.lg),
            child: Container(
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: palette.warningSoft,
                borderRadius: BorderRadius.circular(Rad.panel),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.public_off_outlined, color: palette.warning),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your menu is not published', style: context.textStyles.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Customers see a message that the menu is not available. '
                          'You can still see it here because you are signed in.',
                          style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                        ),
                        const SizedBox(height: Sp.sm),
                        AppButton(
                          label: 'Publish menu',
                          kind: AppButtonKind.tonal,
                          onPressed: () => context.go(AppRoutes.publicLink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (active.length > 1)
          FormSection(
            title: 'Branch',
            subtitle: 'Prices and availability can differ by branch',
            children: [
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  for (final item in active)
                    ChoiceChip(
                      label: Text(item.name),
                      selected: item.id == branch.id,
                      onSelected: (_) => onBranch(item.id),
                    ),
                ],
              ),
            ],
          ),
        if (data != null)
          FormSection(
            title: 'At a glance',
            children: [
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  StatusPill(_count(data.items.length, 'dish', 'dishes'), icon: Icons.restaurant_menu_rounded),
                  StatusPill(_count(data.categories.length, 'category', 'categories'), icon: Icons.category_outlined),
                  StatusPill(
                    statusHeadline(data.status, bangla: false),
                    tone: data.status.isOpen ? PillTone.success : PillTone.warning,
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
            ],
          ),
        FormSection(
          title: 'Link for ${branch.name}',
          subtitle: 'The address customers open',
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Rad.control),
                border: Border.all(color: palette.line),
              ),
              child: SelectableText(link, style: context.textStyles.titleSmall),
            ),
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.sm,
              children: [
                AppButton(label: 'Copy link', icon: Icons.copy_rounded, kind: AppButtonKind.tonal, onPressed: onCopy),
                AppButton(
                  label: 'Open',
                  icon: Icons.open_in_new_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: () => openUrl(link),
                ),
                AppButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: () => Share.share('See our menu: $link', subject: business.name),
                ),
              ],
            ),
            if (!PublicLinks.isConfigured)
              Text(
                'The web address of your menu site is not set, so this link may be '
                'incomplete. Set PUBLIC_BASE_URL when building the app.',
                style: context.textStyles.bodySmall?.copyWith(color: palette.warning),
              ),
          ],
        ),
        ListGroup(
          children: [
            ListRow(
              leading: const IconBadge(Icons.palette_outlined),
              title: 'Colours, theme and layout',
              subtitle: 'Change how the menu looks',
              onTap: () => context.go(AppRoutes.branding),
            ),
            ListRow(
              leading: const IconBadge(Icons.qr_code_2_rounded),
              title: 'QR codes',
              subtitle: 'Print codes for tables and the counter',
              onTap: () => context.go(AppRoutes.qr),
            ),
          ],
        ),
      ],
    );
  }

  static String _count(int value, String one, String many) => '$value ${value == 1 ? one : many}';
}
