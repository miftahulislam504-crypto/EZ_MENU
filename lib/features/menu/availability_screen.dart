import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/logic/menu_search.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'availability_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/availability_display_card.dart';
import 'widgets/availability_header.dart';
import 'widgets/availability_row.dart';
import 'widgets/sold_out_sheet.dart';

/// The quickest place to mark dishes sold out during service: search, one
/// switch per dish, a list of what is sold out right now with a one-tap
/// "Back in stock", bulk actions per category, and the setting that decides
/// how sold-out dishes appear to customers.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  Timer? _clock;

  String _query = '';
  String? _categoryId;
  StockScope _scope = StockScope.thisBranch;

  /// What each dish should look like while its write is in flight.
  final Map<String, StockStatus> _optimistic = {};

  @override
  void initState() {
    super.initState();
    // Dishes that come back by themselves should flip without a reload.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _refresh() async {
    ref.refreshMenu();
    try {
      await ref.read(menuItemsProvider.future);
    } catch (_) {
      // The error state of the list explains it.
    }
  }

  // ---- writes ---------------------------------------------------------------

  /// Runs a write with the optimistic statuses in [next] on screen. On success
  /// the stored data is reloaded before the temporary statuses are dropped, so
  /// nothing flickers back; on failure they are dropped at once and the error
  /// is shown.
  Future<bool> _write(
    Map<String, StockStatus> next,
    Future<void> Function() action,
  ) async {
    setState(() => _optimistic.addAll(next));
    final ok = await runWithToast(context, action, onError: friendlyError);
    if (ok) {
      ref.refreshMenu();
      try {
        final branch = ref.read(selectedBranchProvider);
        await Future.wait([
          ref.read(menuItemsProvider.future),
          if (branch != null)
            ref.read(branchItemSettingsProvider(branch.id).future),
        ]);
      } catch (_) {
        // A failed reload shows through the normal error state.
      }
    }
    if (mounted) setState(() => _optimistic.removeWhere((id, _) => next.containsKey(id)));
    return ok;
  }

  bool get _multiBranch =>
      (ref.read(branchesProvider).valueOrNull?.length ?? 0) > 1;

  /// True when a "sold out" write goes to this branch only.
  bool get _writesToBranch =>
      _multiBranch &&
      _scope == StockScope.thisBranch &&
      ref.read(selectedBranchProvider) != null;

  Future<void> _markSoldOut(List<StockEntry> entries, {required String title}) async {
    if (entries.isEmpty) return;
    final branch = ref.read(selectedBranchProvider);
    final branchWrite = _writesToBranch;
    final choice = await showSoldOutSheet(
      context,
      title: branchWrite && branch != null ? '$title at ${branch.name}' : title,
    );
    if (choice == null || !mounted) return;

    final ids = [for (final e in entries) e.item.id];
    final status = optimisticSoldOut(until: choice.until, branchWrite: branchWrite);
    final repo = ref.read(menuRepositoryProvider);
    await _write({for (final id in ids) id: status}, () async {
      if (branchWrite && branch != null) {
        await repo.setBranchSoldOut(
          branchId: branch.id,
          itemIds: ids,
          soldOut: true,
          until: choice.until,
        );
      } else {
        await repo.setItemsSoldOut(ids, true, until: choice.until);
      }
    });
  }

  Future<void> _restock(List<StockEntry> entries) async {
    final plan = planRestock(entries);
    if (plan.isEmpty) return;
    final branch = ref.read(selectedBranchProvider);
    final repo = ref.read(menuRepositoryProvider);
    await _write(
      {for (final e in entries) e.item.id: StockStatus.available},
      () async {
        if (plan.masterIds.isNotEmpty) {
          await repo.setItemsSoldOut(plan.masterIds, false);
        }
        if (branch != null && plan.branchIds.isNotEmpty) {
          await repo.setBranchSoldOut(
            branchId: branch.id,
            itemIds: plan.branchIds,
            soldOut: false,
          );
        }
      },
    );
  }

  Future<void> _toggle(StockEntry entry, bool soldOut) {
    if (soldOut) {
      return _markSoldOut([entry], title: 'Mark ${entry.item.displayName} as sold out');
    }
    return _restock([entry]);
  }

  Future<void> _markGroupSoldOut(StockGroup group) async {
    final targets = [for (final e in group.entries) if (!e.status.soldOut) e];
    if (targets.isEmpty) {
      showToast(context, 'Everything in ${group.name} is already sold out.');
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Mark ${dishCount(targets.length)} in ${group.name} as sold out?',
      message: _writesToBranch
          ? 'You will choose for how long. This applies to '
                '${ref.read(selectedBranchProvider)?.name ?? 'this branch'} only.'
          : 'You will choose for how long. This applies to all branches.',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !mounted) return;
    await _markSoldOut(targets, title: 'Mark everything in ${group.name} as sold out');
  }

  Future<void> _restockGroup(StockGroup group) async {
    final targets = [for (final e in group.entries) if (e.status.soldOut) e];
    if (targets.isEmpty) {
      showToast(context, 'Nothing in ${group.name} is sold out.');
      return;
    }
    await _restock(targets);
  }

  Future<void> _restockAll(List<StockEntry> soldOut) async {
    final confirmed = await confirmAction(
      context,
      title: 'Bring ${dishCount(soldOut.length)} back in stock?',
      message: 'They can be ordered again straight away.',
      confirmLabel: 'Back in stock',
    );
    if (!confirmed || !mounted) return;
    await _restock(soldOut);
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(menuItemsProvider);
    final categories =
        ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branch = ref.watch(selectedBranchProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final multi = branches.length > 1;

    // The "all branches" view looks at the master switch only; every other
    // view also counts the branch's own overrides.
    final viewsBranch = branch != null && !(multi && _scope == StockScope.allBranches);
    final settings = viewsBranch
        ? (ref.watch(branchItemSettingsProvider(branch.id)).valueOrNull ??
              const <String, BranchItemSetting>{})
        : const <String, BranchItemSetting>{};

    final now = DateTime.now();
    final data = itemsAsync.valueOrNull;

    Widget body;
    if (data == null && itemsAsync.isLoading) {
      body = const _AvailabilitySkeleton();
    } else if (data == null && itemsAsync.hasError) {
      body = ErrorState(
        message: friendlyError(itemsAsync.error),
        onRetry: () => ref.invalidate(menuItemsProvider),
      );
    } else if (data == null || data.where((i) => !i.isDeleted).isEmpty) {
      body = EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No dishes yet',
        message: 'Add dishes first, then come back here to mark them sold out '
            'in one tap.',
        actionLabel: 'Add dish',
        onAction: () => context.push(AppRoutes.itemNew),
      );
    } else {
      body = _content(
        context,
        items: data,
        categories: categories,
        settings: settings,
        now: now,
        business: business,
        branch: branch,
        multi: multi,
        viewsBranch: viewsBranch,
      );
    }

    return AppPage(
      title: 'Availability',
      subtitle: 'Mark dishes sold out in one tap',
      onRefresh: _refresh,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(
            data == null ? (itemsAsync.hasError ? 'error' : 'loading') : 'ready',
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required List<MenuItem> items,
    required List<MenuCategory> categories,
    required Map<String, BranchItemSetting> settings,
    required DateTime now,
    required Business? business,
    required Branch? branch,
    required bool multi,
    required bool viewsBranch,
  }) {
    final view = buildStockView(
      items,
      settings: settings,
      now: now,
      overrides: _optimistic,
    );
    final counts = countStock(view.entries);
    final topLevel = [
      for (final c in categories)
        if (c.parentId == null && !c.isDeleted) c,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final categoryIds = _categoryId == null
        ? null
        : categoryWithDescendants(_categoryId!, categories);
    final shown = filterStock(view.entries, query: _query, categoryIds: categoryIds);
    final filtering = _query.trim().isNotEmpty || _categoryId != null;
    final groups = groupStock(shown, categories);
    final soldOutNow = [for (final e in shown) if (e.status.soldOut) e];
    final showScope = viewsBranch && multi;

    Widget row(StockEntry entry, {bool restock = false, String? categoryName}) {
      return AvailabilityRow(
        key: ValueKey('${restock ? 'r' : 'a'}-${entry.item.id}'),
        entry: entry,
        now: now,
        showScope: showScope,
        busy: _optimistic.containsKey(entry.item.id),
        categoryName: categoryName,
        onToggle: (v) => _toggle(entry, v),
        onRestock: restock ? () => _restock([entry]) : null,
      );
    }

    final catName = {
      for (final g in groupStock(view.entries, categories)) g.id: g.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvailabilityHeader(
          counts: counts,
          search: _search,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _clearSearch,
          categories: topLevel,
          categoryId: _categoryId,
          onCategory: (id) => setState(() => _categoryId = id),
          branchName: multi ? branch?.name : null,
          scope: _scope,
          onScope: multi
              ? (value) => setState(() {
                  _scope = value;
                  _optimistic.clear();
                })
              : null,
        ),
        const SizedBox(height: Sp.xl),
        if (soldOutNow.isNotEmpty) ...[
          ListGroup(
            title: 'Sold out now (${soldOutNow.length})',
            trailing: soldOutNow.length > 1
                ? TextButton.icon(
                    onPressed: () => _restockAll(soldOutNow),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('All back in stock'),
                  )
                : null,
            children: [
              for (final entry in soldOutNow)
                row(entry, restock: true, categoryName: catName[entry.item.categoryId]),
            ],
          ),
        ],
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.xl),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: filtering ? 'No dishes match' : 'No dishes to show',
              message: filtering
                  ? 'Try different words or another category.'
                  : 'Dishes that are switched off are not listed here.',
              actionLabel: filtering ? 'Clear search' : null,
              onAction: filtering
                  ? () {
                      _clearSearch();
                      setState(() => _categoryId = null);
                    }
                  : null,
            ),
          )
        else
          for (final group in groups)
            ListGroup(
              key: ValueKey('group-${group.id}'),
              title: '${group.name} (${group.availableCount}/${group.entries.length})',
              trailing: group.id == uncategorisedGroupId
                  ? null
                  : _GroupMenu(
                      onSoldOut: () => _markGroupSoldOut(group),
                      onRestock: () => _restockGroup(group),
                    ),
              children: [for (final entry in group.entries) row(entry)],
            ),
        if (view.hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.xl),
            child: Text(
              '${dishCount(view.hiddenCount)} switched off and not listed here.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
        if (business != null)
          SoldOutDisplayCard(business: business, branch: branch),
      ],
    );
  }
}

class _GroupMenu extends StatelessWidget {
  const _GroupMenu({required this.onSoldOut, required this.onRestock});

  final VoidCallback onSoldOut;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Category actions',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (soldOut) => soldOut ? onSoldOut() : onRestock(),
      itemBuilder: (context) => const [
        PopupMenuItem(value: true, child: Text('Mark all sold out')),
        PopupMenuItem(value: false, child: Text('Mark all available')),
      ],
    );
  }
}

class _AvailabilitySkeleton extends StatelessWidget {
  const _AvailabilitySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 72, radius: 16)),
            SizedBox(width: Sp.sm),
            Expanded(child: SkeletonBox(height: 72, radius: 16)),
            SizedBox(width: Sp.sm),
            Expanded(child: SkeletonBox(height: 72, radius: 16)),
          ],
        ),
        SizedBox(height: Sp.lg),
        SkeletonBox(height: 52, radius: 12),
        SizedBox(height: Sp.xl),
        _SkeletonRow(),
        SizedBox(height: Sp.md),
        _SkeletonRow(),
        SizedBox(height: Sp.md),
        _SkeletonRow(),
        SizedBox(height: Sp.md),
        _SkeletonRow(),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 48, height: 48, radius: 12),
        SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 110, height: 12),
            ],
          ),
        ),
        SizedBox(width: Sp.md),
        SkeletonBox(width: 48, height: 28, radius: 14),
      ],
    );
  }
}
