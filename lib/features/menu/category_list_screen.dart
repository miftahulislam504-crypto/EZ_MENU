import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'category_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/category_branch_sheet.dart';
import 'widgets/category_tile.dart';
import 'widgets/menu_ui.dart';

/// Categories and subcategories: reorder, show or hide, per-branch switches,
/// duplicate, move to trash. Long press selects several.
class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  final Set<String> _selected = {};
  final Set<String> _collapsed = {};

  /// Optimistic order per group: 'top' or a parent id.
  final Map<String, List<String>> _orders = {};
  List<MenuCategory>? _source;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MenuCategory> _ordered(List<MenuCategory> list, String group) {
    final order = _orders[group];
    if (order == null) return list;
    final byId = {for (final c in list) c.id: c};
    final sorted = <MenuCategory>[
      for (final id in order)
        if (byId.containsKey(id)) byId[id]!,
    ];
    for (final c in list) {
      if (!order.contains(c.id)) sorted.add(c);
    }
    return sorted;
  }

  Future<void> _persistOrder(String group, List<String> ids) async {
    setState(() => _orders[group] = ids);
    try {
      await ref.read(menuRepositoryProvider).reorderCategories(ids);
      ref.refreshMenu();
    } catch (error) {
      if (!mounted) return;
      setState(() => _orders.remove(group));
      showToast(context, friendlyError(error), isError: true);
    }
  }

  Future<void> _setActive(List<String> ids, bool active) async {
    final ok = await runWithToast(
      context,
      () => ref.read(menuRepositoryProvider).setCategoriesActive(ids, active),
      onError: friendlyError,
    );
    if (ok) ref.refreshMenu();
  }

  Future<void> _softDelete(List<MenuCategory> categories) async {
    final single = categories.length == 1;
    final confirmed = await confirmAction(
      context,
      title: single
          ? 'Move "${categories.first.displayName}" to trash?'
          : 'Move ${categories.length} categories to trash?',
      message:
          'Their dishes and subcategories move to the trash too. You can '
          'restore everything from the trash.',
      confirmLabel: 'Move to trash',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final picked = {for (final c in categories) c.id};
    // A subcategory goes with its parent, so only send the top ones.
    final ids = [
      for (final c in categories)
        if (c.parentId == null || !picked.contains(c.parentId)) c.id,
    ];
    final ok = await runWithToast(context, () async {
      for (final id in ids) {
        await repo.softDeleteCategory(id);
      }
    }, onError: friendlyError);
    ref.refreshMenu();
    if (!ok || !mounted) return;
    setState(_selected.clear);
    showUndoToast(
      context,
      single ? 'Category moved to trash' : '${ids.length} categories moved to trash',
      onUndo: () async {
        for (final id in ids) {
          await repo.restoreCategory(id);
        }
        ref.refreshMenu();
      },
      onError: friendlyError,
    );
  }

  Future<void> _duplicate(MenuCategory category) async {
    final withDishes = await showAppSheet<bool>(
      context,
      title: 'Duplicate "${category.displayName}"',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const IconBadge(Icons.copy_all_rounded),
            title: const Text('Copy with its dishes'),
            subtitle: const Text('Dishes, photos, variants and add-ons are copied.'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          ListTile(
            leading: const IconBadge(Icons.folder_open_rounded),
            title: const Text('Copy as an empty category'),
            subtitle: const Text('Only the category itself is copied.'),
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: Sp.md),
        ],
      ),
    );
    if (withDishes == null || !mounted) return;
    final ok = await runWithToast(
      context,
      () => ref
          .read(menuRepositoryProvider)
          .duplicateCategory(category.id, includeItems: withDishes),
      onError: friendlyError,
      successMessage: 'Category duplicated',
    );
    if (ok) ref.refreshMenu();
  }

  void _onAction(
    CategoryAction action,
    MenuCategory category,
    List<Branch> branches,
  ) {
    switch (action) {
      case CategoryAction.edit:
        context.push(AppRoutes.categoryEdit(category.id));
      case CategoryAction.addSub:
        context.push('${AppRoutes.categoryNew}?parent=${category.id}');
      case CategoryAction.viewDishes:
        context.push('${AppRoutes.items}?category=${category.id}');
      case CategoryAction.branches:
        showCategoryBranchSheet(context, category: category, branches: branches);
      case CategoryAction.duplicate:
        _duplicate(category);
      case CategoryAction.delete:
        _softDelete([category]);
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final items = ref.watch(menuItemsProvider).valueOrNull ?? const <MenuItem>[];
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final multiBranch = branches.length > 1;

    final data = categoriesAsync.valueOrNull;
    if (data != null && !identical(data, _source)) {
      _source = data;
      _orders.clear();
    }

    // Per category: in how many branches it is switched off.
    final offCounts = <String, int>{};
    if (multiBranch) {
      for (final branch in branches) {
        final settings =
            ref.watch(branchCategorySettingsProvider(branch.id)).valueOrNull;
        settings?.forEach((categoryId, active) {
          if (!active) offCounts[categoryId] = (offCounts[categoryId] ?? 0) + 1;
        });
      }
    }

    Widget body;
    if (categoriesAsync.isLoading && data == null) {
      body = const SkeletonList(rows: 5);
    } else if (categoriesAsync.hasError && data == null) {
      body = ErrorState(
        message: friendlyError(categoriesAsync.error),
        onRetry: () => ref.invalidate(menuCategoriesProvider),
      );
    } else if ((data ?? const <MenuCategory>[]).isEmpty) {
      body = EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories yet',
        message:
            'Categories group your dishes, like Starters, Main course or '
            'Drinks. Add the first one to start building the menu.',
        actionLabel: 'Add category',
        onAction: () => context.push(AppRoutes.categoryNew),
      );
    } else {
      final tree = buildCategoryTree(data!);
      final direct = countItemsByCategory(items);
      final totals = countItemsWithChildren(tree, direct);
      final filtered = filterCategoryTree(tree, _query);
      final searching = _query.trim().isNotEmpty;
      final canReorder = !searching && !_selecting;
      final tops = _ordered([for (final n in filtered) n.category], 'top');
      final nodeById = {for (final n in filtered) n.category.id: n};

      Widget list;
      if (filtered.isEmpty) {
        list = const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No category matches',
          message: 'Try a different name, in English or Bangla.',
        );
      } else {
        list = ReorderableListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, 104),
          buildDefaultDragHandles: false,
          itemCount: tops.length,
          onReorder: (oldIndex, newIndex) => _persistOrder(
            'top',
            reorderedIds([for (final c in tops) c.id], oldIndex, newIndex),
          ),
          itemBuilder: (context, index) {
            final top = tops[index];
            final node = nodeById[top.id]!;
            final children = _ordered(node.children, top.id);
            final expanded = searching || !_collapsed.contains(top.id);
            return Padding(
              key: ValueKey(top.id),
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: Column(
                children: [
                  CategoryTile(
                    category: top,
                    dishCount: totals[top.id] ?? 0,
                    selected: _selected.contains(top.id),
                    selecting: _selecting,
                    reorderIndex: canReorder && tops.length > 1 ? index : null,
                    offBranches: offCounts[top.id] ?? 0,
                    showBranchAction: multiBranch,
                    onLongPress: () => _toggleSelect(top.id),
                    onTap: () => _selecting
                        ? _toggleSelect(top.id)
                        : context.push(AppRoutes.categoryEdit(top.id)),
                    onActiveChanged: (v) => _setActive([top.id], v),
                    onAction: (a) => _onAction(a, top, branches),
                    leadingExtra: children.isEmpty
                        ? null
                        : InkResponse(
                            radius: 22,
                            onTap: () => setState(() {
                              if (!_collapsed.add(top.id)) _collapsed.remove(top.id);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.only(right: Sp.xs),
                              child: AnimatedRotation(
                                turns: expanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.palette.muted,
                                ),
                              ),
                            ),
                          ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: (expanded && children.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.only(left: Sp.xl, top: Sp.sm),
                            child: ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: children.length,
                              onReorder: (oldIndex, newIndex) => _persistOrder(
                                top.id,
                                reorderedIds(
                                  [for (final c in children) c.id],
                                  oldIndex,
                                  newIndex,
                                ),
                              ),
                              itemBuilder: (context, i) {
                                final child = children[i];
                                return Padding(
                                  key: ValueKey(child.id),
                                  padding: const EdgeInsets.only(bottom: Sp.sm),
                                  child: CategoryTile(
                                    category: child,
                                    compact: true,
                                    dishCount: totals[child.id] ?? 0,
                                    selected: _selected.contains(child.id),
                                    selecting: _selecting,
                                    reorderIndex: canReorder && children.length > 1 ? i : null,
                                    offBranches: offCounts[child.id] ?? 0,
                                    showBranchAction: multiBranch,
                                    onLongPress: () => _toggleSelect(child.id),
                                    onTap: () => _selecting
                                        ? _toggleSelect(child.id)
                                        : context.push(AppRoutes.categoryEdit(child.id)),
                                    onActiveChanged: (v) => _setActive([child.id], v),
                                    onAction: (a) => _onAction(a, child, branches),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            );
          },
        );
      }

      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.sm),
            child: AppTextField(
              label: 'Search categories',
              controller: _search,
              hint: 'Type a name in English or Bangla',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              suffix: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refreshMenu(),
              child: list,
            ),
          ),
        ],
      );
    }

    final all = data ?? const <MenuCategory>[];
    final selectedCategories = [
      for (final c in all)
        if (_selected.contains(c.id)) c,
    ];

    return AppPage(
      title: _selecting ? '${_selected.length} selected' : 'Categories',
      subtitle: _selecting ? null : 'Group dishes and choose their order',
      scroll: false,
      leading: _selecting
          ? IconButton(
              tooltip: 'Cancel selection',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_selected.clear),
            )
          : null,
      actions: [
        if (_selecting)
          IconButton(
            tooltip: 'Select all',
            icon: const Icon(Icons.select_all_rounded),
            onPressed: () => setState(() {
              _selected
                ..clear()
                ..addAll([for (final c in all) c.id]);
            }),
          )
        else
          IconButton(
            tooltip: 'Trash',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => context.push(AppRoutes.trash),
          ),
      ],
      floatingActionButton: _selecting || all.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.categoryNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category'),
            ),
      bottomBar: _selecting
          ? StickyActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Show',
                      icon: Icons.visibility_outlined,
                      kind: AppButtonKind.secondary,
                      onPressed: () async {
                        await _setActive(_selected.toList(), true);
                        if (mounted) setState(_selected.clear);
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Hide',
                      icon: Icons.visibility_off_outlined,
                      kind: AppButtonKind.secondary,
                      onPressed: () async {
                        await _setActive(_selected.toList(), false);
                        if (mounted) setState(_selected.clear);
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      kind: AppButtonKind.danger,
                      onPressed: () => _softDelete(selectedCategories),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: body,
    );
  }
}
