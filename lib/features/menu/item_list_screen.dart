import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/logic/menu_catalog.dart';
import '../../core/logic/menu_search.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'category_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/category_picker.dart';
import 'widgets/item_list_tile.dart';
import 'widgets/item_quick_add_sheet.dart';
import 'widgets/menu_ui.dart';
import 'widgets/sold_out_sheet.dart';

/// All dishes: search, filters, sorting, one-tap visibility and sold out,
/// reordering inside a category, and bulk actions.
class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _categoryId;
  ItemStatusFilter _status = ItemStatusFilter.all;
  String? _label;
  ItemSort _sort = ItemSort.menuOrder;
  final Set<String> _selected = {};
  List<String>? _orderOverride;
  List<MenuItem>? _source;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
  }

  @override
  void didUpdateWidget(covariant ItemListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _categoryId = widget.categoryId;
      _orderOverride = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value);
    });
  }

  // ---- writes ---------------------------------------------------------------

  Future<bool> _guard(Future<void> Function() action, {String? success}) async {
    final ok = await runWithToast(context, action, onError: friendlyError, successMessage: success);
    ref.refreshMenu();
    return ok;
  }

  Future<void> _setActive(List<String> ids, bool active) =>
      _guard(() => ref.read(menuRepositoryProvider).setItemsActive(ids, active));

  Future<void> _markSoldOut(List<String> ids, {String? title}) async {
    final branch = ref.read(selectedBranchProvider);
    final multi = (ref.read(branchesProvider).valueOrNull?.length ?? 0) > 1;
    final choice = await showSoldOutSheet(
      context,
      title: title ?? 'Mark as sold out',
      offerBranchScope: multi && branch != null,
      branchName: branch?.name,
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    await _guard(() async {
      if (choice.branchOnly && branch != null) {
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

  /// Back in stock: clears the master switch and, where a branch override
  /// marks it sold out, that one too.
  Future<void> _markAvailable(
    List<MenuItem> items,
    Map<String, BranchItemSetting> settings,
  ) async {
    final repo = ref.read(menuRepositoryProvider);
    final branch = ref.read(selectedBranchProvider);
    final master = [for (final i in items) if (i.isSoldOut) i.id];
    final branchIds = [
      for (final i in items)
        if (settings[i.id]?.isSoldOut ?? false) i.id,
    ];
    await _guard(() async {
      if (master.isNotEmpty) await repo.setItemsSoldOut(master, false);
      if (branch != null && branchIds.isNotEmpty) {
        await repo.setBranchSoldOut(branchId: branch.id, itemIds: branchIds, soldOut: false);
      }
    });
  }

  Future<void> _delete(List<MenuItem> items) async {
    final single = items.length == 1;
    final confirmed = await confirmAction(
      context,
      title: single
          ? 'Move "${items.first.displayName}" to trash?'
          : 'Move ${items.length} dishes to trash?',
      message: 'You can restore them from the trash later.',
      confirmLabel: 'Move to trash',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final ids = [for (final i in items) i.id];
    final ok = await _guard(() => repo.softDeleteItems(ids));
    if (!ok || !mounted) return;
    setState(_selected.clear);
    showUndoToast(
      context,
      single ? 'Dish moved to trash' : '${ids.length} dishes moved to trash',
      onUndo: () async {
        for (final id in ids) {
          await repo.restoreItem(id);
        }
        ref.refreshMenu();
      },
      onError: friendlyError,
    );
  }

  Future<void> _duplicate(MenuItem item) async {
    String? newId;
    final ok = await _guard(() async {
      newId = await ref.read(menuRepositoryProvider).duplicateItem(item.id);
    });
    if (ok && newId != null && mounted) {
      showToast(context, 'Dish duplicated');
      context.push(AppRoutes.itemEdit(newId!));
    }
  }

  Future<void> _move(List<MenuItem> items, List<MenuCategory> categories) async {
    final pick = await showCategoryPicker(
      context,
      categories: categories,
      title: items.length == 1 ? 'Move "${items.first.displayName}" to' : 'Move ${items.length} dishes to',
      selectedId: items.length == 1 ? items.first.categoryId : null,
    );
    if (pick?.id == null || !mounted) return;
    final ok = await _guard(
      () => ref.read(menuRepositoryProvider).moveItems([for (final i in items) i.id], pick!.id!),
      success: items.length == 1 ? 'Dish moved' : 'Dishes moved',
    );
    if (ok && mounted) setState(_selected.clear);
  }

  Future<void> _persistOrder(List<String> ids) async {
    setState(() => _orderOverride = ids);
    try {
      await ref.read(menuRepositoryProvider).reorderItems(ids);
      ref.refreshMenu();
    } catch (error) {
      if (!mounted) return;
      setState(() => _orderOverride = null);
      showToast(context, friendlyError(error), isError: true);
    }
  }

  void _changePrices(List<String> ids) {
    ref.read(bulkPriceSelectionProvider.notifier).set(ids);
    context.push(AppRoutes.bulkPrices);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  bool get _hasFilters =>
      _query.trim().isNotEmpty ||
      _status != ItemStatusFilter.all ||
      _label != null ||
      (_categoryId != null && widget.categoryId == null);

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _status = ItemStatusFilter.all;
      _label = null;
      _categoryId = widget.categoryId;
    });
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(menuItemsProvider);
    final categories = ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branch = ref.watch(selectedBranchProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final settings = branch == null
        ? const <String, BranchItemSetting>{}
        : (ref.watch(branchItemSettingsProvider(branch.id)).valueOrNull ??
              const <String, BranchItemSetting>{});
    final currency = business?.currency ?? 'BDT';
    final now = DateTime.now();

    final data = itemsAsync.valueOrNull;
    if (data != null && !identical(data, _source)) {
      _source = data;
      _orderOverride = null;
    }
    final all = data ?? const <MenuItem>[];

    final catById = {for (final c in categories) c.id: c};
    final selectedCategory = _categoryId == null ? null : catById[_categoryId];
    final categoryIds = _categoryId == null ? null : categoryWithDescendants(_categoryId!, categories);
    final isLeaf = _categoryId != null && !categories.any((c) => c.parentId == _categoryId);

    var shown = sortItems(
      filterItems(
        all,
        query: _query,
        categoryIds: categoryIds,
        status: _status,
        label: _label,
        settings: settings,
        now: now,
      ),
      _sort,
      categoryRank: categoryRankOf(categories),
      settings: settings,
    );

    final canReorder = isLeaf &&
        _query.trim().isEmpty &&
        _status == ItemStatusFilter.all &&
        _label == null &&
        _sort == ItemSort.menuOrder;
    if (canReorder && _orderOverride != null) {
      final byId = {for (final i in shown) i.id: i};
      shown = [
        for (final id in _orderOverride!)
          if (byId.containsKey(id)) byId[id]!,
      ];
    }

    // Selection survives filter changes only for dishes still in the list.
    final shownIds = {for (final i in shown) i.id};
    if (_selected.any((id) => !shownIds.contains(id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected.removeWhere((id) => !shownIds.contains(id)));
      });
    }
    final selectedItems = [for (final i in shown) if (_selected.contains(i.id)) i];

    Widget body;
    if (itemsAsync.isLoading && data == null) {
      body = const SkeletonList(rows: 6);
    } else if (itemsAsync.hasError && data == null) {
      body = ErrorState(
        message: friendlyError(itemsAsync.error),
        onRetry: () => ref.invalidate(menuItemsProvider),
      );
    } else if (all.isEmpty) {
      body = EmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: 'No dishes yet',
        message: 'Add your first dish, or add several at once by typing one per line.',
        actionLabel: 'Add dish',
        onAction: () => context.push(AppRoutes.itemNew),
      );
    } else {
      Widget list;
      if (shown.isEmpty) {
        list = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: Sp.xxl),
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No dishes match',
              message: 'Try different words or remove a filter.',
              actionLabel: _hasFilters ? 'Clear filters' : null,
              onAction: _hasFilters ? _clearFilters : null,
            ),
          ],
        );
      } else {
        Widget tile(MenuItem item, int index) {
          final setting = settings[item.id];
          final soldOut = isSoldOutNow(item, setting, now);
          final until = item.isSoldOutAt(now)
              ? item.soldOutUntil
              : (setting?.isSoldOutAt(now) ?? false ? setting!.soldOutUntil : null);
          return Padding(
            key: ValueKey(item.id),
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: ItemListTile(
              item: item,
              price: effectivePriceAt(item, setting),
              currency: currency,
              now: now,
              soldOut: soldOut,
              soldOutUntil: until,
              hiddenAtBranch: isHiddenAtBranch(setting),
              categoryName: _categoryId != null && isLeaf ? null : catById[item.categoryId]?.displayName,
              selected: _selected.contains(item.id),
              selecting: _selecting,
              reorderIndex: canReorder && shown.length > 1 ? index : null,
              onLongPress: () => _toggleSelect(item.id),
              onTap: () => _selecting ? _toggleSelect(item.id) : context.push(AppRoutes.itemEdit(item.id)),
              onVisibleChanged: (v) => _setActive([item.id], v),
              onSoldOutChanged: (v) => v ? _markSoldOut([item.id]) : _markAvailable([item], settings),
              onAction: (action) {
                switch (action) {
                  case ItemAction.edit:
                    context.push(AppRoutes.itemEdit(item.id));
                  case ItemAction.duplicate:
                    _duplicate(item);
                  case ItemAction.move:
                    _move([item], categories);
                  case ItemAction.soldOut:
                    soldOut ? _markAvailable([item], settings) : _markSoldOut([item.id]);
                  case ItemAction.delete:
                    _delete([item]);
                }
              },
            ),
          );
        }

        const padding = EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, 110);
        list = canReorder
            ? ReorderableListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                buildDefaultDragHandles: false,
                itemCount: shown.length,
                onReorder: (o, n) => _persistOrder(
                  reorderedItemIds([for (final i in shown) i.id], o, n),
                ),
                itemBuilder: (context, index) => tile(shown[index], index),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                itemCount: shown.length,
                itemBuilder: (context, index) => tile(shown[index], index),
              );
      }

      body = Column(
        children: [
          _FilterHeader(
            search: _search,
            onSearchChanged: _onSearchChanged,
            query: _query,
            onClearSearch: () {
              _search.clear();
              setState(() => _query = '');
            },
            category: selectedCategory,
            onPickCategory: () async {
              final pick = await showCategoryPicker(
                context,
                categories: categories,
                allowAll: true,
                selectedId: _categoryId,
                title: 'Filter by category',
                counts: countItemsByCategory(all),
              );
              if (pick != null && mounted) {
                setState(() {
                  _categoryId = pick.id;
                  _orderOverride = null;
                });
              }
            },
            onClearCategory: () => setState(() {
              _categoryId = null;
              _orderOverride = null;
            }),
            status: _status,
            onStatus: (v) => setState(() => _status = v),
            label: _label,
            onLabel: (v) => setState(() => _label = v),
            sort: _sort,
            onSort: (v) => setState(() => _sort = v),
            count: shown.length,
            total: all.length,
            reorderHint: _categoryId == null
                ? 'Pick one category to drag dishes into a new order.'
                : (canReorder
                      ? 'Drag the handle to change the order.'
                      : (isLeaf
                            ? 'Clear search and filters, and sort by menu order, to reorder.'
                            : 'Open a subcategory to reorder its dishes.')),
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

    return AppPage(
      title: _selecting
          ? '${_selected.length} selected'
          : (selectedCategory == null ? 'Dishes' : selectedCategory.displayName),
      subtitle: _selecting
          ? null
          : (branch != null && branches.length > 1 ? 'Prices and availability for ${branch.name}' : null),
      scroll: false,
      maxWidth: 1000,
      leading: _selecting
          ? IconButton(
              tooltip: 'Cancel selection',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_selected.clear),
            )
          : null,
      actions: _selecting
          ? [
              IconButton(
                tooltip: 'Select all in view',
                icon: const Icon(Icons.select_all_rounded),
                onPressed: () => setState(() {
                  _selected
                    ..clear()
                    ..addAll(shownIds);
                }),
              ),
            ]
          : [
              IconButton(
                tooltip: 'Select dishes',
                icon: const Icon(Icons.checklist_rounded),
                onPressed: shown.isEmpty ? null : () => setState(() => _selected.add(shown.first.id)),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) {
                  switch (v) {
                    case 'quick':
                      showQuickAddSheet(
                        context,
                        categories: categories,
                        items: all,
                        initialCategoryId: _categoryId,
                      );
                    case 'import':
                      context.push(AppRoutes.importExport);
                    case 'availability':
                      context.push(AppRoutes.availability);
                    case 'trash':
                      context.push(AppRoutes.trash);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'quick', child: Text('Add several dishes')),
                  PopupMenuItem(value: 'import', child: Text('Import and export')),
                  PopupMenuItem(value: 'availability', child: Text('Availability')),
                  PopupMenuItem(value: 'trash', child: Text('Trash')),
                ],
              ),
            ],
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                _categoryId == null ? AppRoutes.itemNew : '${AppRoutes.itemNew}?category=$_categoryId',
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add dish'),
            ),
      bottomBar: _selecting
          ? _BulkBar(
              onShow: () async {
                await _setActive([for (final i in selectedItems) i.id], true);
                if (mounted) setState(_selected.clear);
              },
              onHide: () async {
                await _setActive([for (final i in selectedItems) i.id], false);
                if (mounted) setState(_selected.clear);
              },
              onSoldOut: () => _markSoldOut(
                [for (final i in selectedItems) i.id],
                title: 'Mark ${selectedItems.length} dishes as sold out',
              ).then((_) {
                if (mounted) setState(_selected.clear);
              }),
              onAvailable: () => _markAvailable(selectedItems, settings).then((_) {
                if (mounted) setState(_selected.clear);
              }),
              onMove: () => _move(selectedItems, categories),
              onPrices: () => _changePrices([for (final i in selectedItems) i.id]),
              onDelete: () => _delete(selectedItems),
            )
          : null,
      body: body,
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.search,
    required this.onSearchChanged,
    required this.query,
    required this.onClearSearch,
    required this.category,
    required this.onPickCategory,
    required this.onClearCategory,
    required this.status,
    required this.onStatus,
    required this.label,
    required this.onLabel,
    required this.sort,
    required this.onSort,
    required this.count,
    required this.total,
    required this.reorderHint,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final String query;
  final VoidCallback onClearSearch;
  final MenuCategory? category;
  final VoidCallback onPickCategory;
  final VoidCallback onClearCategory;
  final ItemStatusFilter status;
  final ValueChanged<ItemStatusFilter> onStatus;
  final String? label;
  final ValueChanged<String?> onLabel;
  final ItemSort sort;
  final ValueChanged<ItemSort> onSort;
  final int count;
  final int total;
  final String reorderHint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Search dishes',
            controller: search,
            hint: 'Name in English or Bangla, or code',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            suffix: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClearSearch,
                  ),
          ),
          const SizedBox(height: Sp.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InputChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(category == null ? 'All categories' : category!.displayName),
                  onPressed: onPickCategory,
                  onDeleted: category == null ? null : onClearCategory,
                ),
                const SizedBox(width: Sp.sm),
                for (final entry in itemStatusLabels.entries) ...[
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: status == entry.key,
                    onSelected: (_) => onStatus(entry.key),
                  ),
                  const SizedBox(width: Sp.sm),
                ],
                PopupMenuButton<String?>(
                  tooltip: 'Filter by label',
                  onSelected: (v) => onLabel(v == '' ? null : v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '', child: Text('Any label')),
                    for (final tag in menuLabels) PopupMenuItem(value: tag.id, child: Text(tag.en)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 18),
                    label: Text(label == null ? 'Label' : menuTagName(menuLabels, label!)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: reorderHint,
                  child: Text(
                    count == total ? '$total dishes' : '$count of $total dishes',
                    style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
              ),
              PopupMenuButton<ItemSort>(
                tooltip: 'Sort',
                onSelected: onSort,
                itemBuilder: (context) => [
                  for (final entry in itemSortLabels.entries)
                    CheckedPopupMenuItem(
                      value: entry.key,
                      checked: sort == entry.key,
                      child: Text(entry.value),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 18, color: palette.muted),
                      const SizedBox(width: 4),
                      Text(itemSortLabels[sort]!, style: context.textStyles.labelMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.onShow,
    required this.onHide,
    required this.onSoldOut,
    required this.onAvailable,
    required this.onMove,
    required this.onPrices,
    required this.onDelete,
  });

  final VoidCallback onShow;
  final VoidCallback onHide;
  final VoidCallback onSoldOut;
  final VoidCallback onAvailable;
  final VoidCallback onMove;
  final VoidCallback onPrices;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
      final color = danger ? context.palette.danger : context.colors.onSurface;
      return InkWell(
        borderRadius: BorderRadius.circular(Rad.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(label, style: context.textStyles.labelSmall?.copyWith(color: color)),
            ],
          ),
        ),
      );
    }

    return StickyActionBar(
      maxWidth: 1000,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            action(Icons.visibility_outlined, 'Show', onShow),
            action(Icons.visibility_off_outlined, 'Hide', onHide),
            action(Icons.block_rounded, 'Sold out', onSoldOut),
            action(Icons.check_circle_outline_rounded, 'Available', onAvailable),
            action(Icons.drive_file_move_outline, 'Move', onMove),
            action(Icons.price_change_outlined, 'Prices', onPrices),
            action(Icons.delete_outline_rounded, 'Delete', onDelete, danger: true),
          ],
        ),
      ),
    );
  }
}
