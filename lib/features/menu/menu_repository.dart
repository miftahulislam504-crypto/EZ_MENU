import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/session_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/json_utils.dart';
import '../home/menu_stats.dart';
import 'menu_models.dart';

/// Reads and writes menu data. Every method throws on failure; screens show
/// the message with `friendlyError`.
class MenuRepository {
  MenuRepository(this._client);

  final SupabaseClient _client;

  static const int _pageSize = 1000;

  // ---- categories ---------------------------------------------------------

  /// Categories in display order (top level and subcategories together).
  /// [deleted] switches to the trash instead.
  Future<List<MenuCategory>> categories(
    String businessId, {
    bool deleted = false,
  }) async {
    var query = _client
        .from('menu_categories')
        .select()
        .eq('business_id', businessId);
    query = deleted
        ? query.not('deleted_at', 'is', null)
        : query.isFilter('deleted_at', null);
    final rows = await query.order('sort_order').order('created_at');
    return rows.map((row) => MenuCategory.fromJson(row)).toList();
  }

  /// Creates (no [id]) or updates a category and returns the saved row.
  Future<MenuCategory> saveCategory({
    String? id,
    required String businessId,
    required Map<String, dynamic> values,
  }) async {
    final Map<String, dynamic> row;
    if (id == null) {
      row = await _client
          .from('menu_categories')
          .insert({...values, 'business_id': businessId})
          .select()
          .single();
    } else {
      row = await _client
          .from('menu_categories')
          .update(values)
          .eq('id', id)
          .select()
          .single();
    }
    return MenuCategory.fromJson(row);
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await _client.rpc('reorder_menu_categories', params: {'p_ids': orderedIds});
  }

  Future<void> setCategoriesActive(List<String> ids, bool active) async {
    if (ids.isEmpty) return;
    await _client
        .from('menu_categories')
        .update({'is_active': active})
        .inFilter('id', ids);
  }

  /// Moves the category (and its subcategories and dishes) to the trash.
  Future<void> softDeleteCategory(String id) async {
    await _client.rpc('soft_delete_category', params: {'p_category_id': id});
  }

  Future<void> restoreCategory(String id) async {
    await _client.rpc('restore_category', params: {'p_category_id': id});
  }

  /// Removes the category and everything in it for good.
  Future<void> deleteCategoryForever(String id) async {
    await _client.from('menu_categories').delete().eq('id', id);
  }

  Future<String> duplicateCategory(String id, {bool includeItems = true}) async {
    final result = await _client.rpc(
      'duplicate_menu_category',
      params: {'p_category_id': id, 'p_include_items': includeItems},
    );
    return result.toString();
  }

  /// Per category: is it switched on at this branch? Categories without a row
  /// are on.
  Future<Map<String, bool>> categorySettingsForBranch(String branchId) async {
    final rows = await _client
        .from('branch_category_settings')
        .select()
        .eq('branch_id', branchId);
    return {
      for (final row in rows)
        row.requireStr('category_id'): row.boolean('is_active', fallback: true),
    };
  }

  /// Per branch: is this category switched on there?
  Future<Map<String, bool>> categorySettingsForCategory(
    String categoryId,
  ) async {
    final rows = await _client
        .from('branch_category_settings')
        .select()
        .eq('category_id', categoryId);
    return {
      for (final row in rows)
        row.requireStr('branch_id'): row.boolean('is_active', fallback: true),
    };
  }

  Future<void> setCategoryActiveAtBranch({
    required String branchId,
    required String categoryId,
    required bool active,
  }) async {
    await _client.from('branch_category_settings').upsert({
      'branch_id': branchId,
      'category_id': categoryId,
      'is_active': active,
    }, onConflict: 'branch_id,category_id');
  }

  // ---- items --------------------------------------------------------------

  /// All dishes of the business in display order. [deleted] switches to the
  /// trash. The server returns at most 1000 rows per request, so this pages.
  Future<List<MenuItem>> items(
    String businessId, {
    bool deleted = false,
  }) async {
    final result = <MenuItem>[];
    var from = 0;
    while (true) {
      var query = _client
          .from('menu_items')
          .select()
          .eq('business_id', businessId);
      query = deleted
          ? query.not('deleted_at', 'is', null)
          : query.isFilter('deleted_at', null);
      final rows = await query
          .order('sort_order')
          .order('created_at')
          .range(from, from + _pageSize - 1);
      result.addAll(rows.map((row) => MenuItem.fromJson(row)));
      if (rows.length < _pageSize) break;
      from += _pageSize;
    }
    return result;
  }

  Future<MenuItem?> item(String id) async {
    final row = await _client
        .from('menu_items')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MenuItem.fromJson(row);
  }

  /// The dish with its option groups, availability windows and branch
  /// overrides, for the editor.
  Future<ItemDetail?> itemDetail(String id) async {
    final item = await this.item(id);
    if (item == null) return null;
    final groups = await optionGroups(id);
    final windows = await schedules(id);
    final overrides = await branchSettingsForItem(id);
    return ItemDetail(
      item: item,
      groups: groups,
      schedules: windows,
      branchSettings: overrides,
    );
  }

  Future<MenuItem> createItem(
    String businessId,
    Map<String, dynamic> values,
  ) async {
    final row = await _client
        .from('menu_items')
        .insert({...values, 'business_id': businessId})
        .select()
        .single();
    return MenuItem.fromJson(row);
  }

  Future<void> updateItem(String id, Map<String, dynamic> values) async {
    await _client.from('menu_items').update(values).eq('id', id);
  }

  /// Applies the same change to several dishes.
  Future<void> updateItems(List<String> ids, Map<String, dynamic> values) async {
    if (ids.isEmpty) return;
    await _client.from('menu_items').update(values).inFilter('id', ids);
  }

  Future<void> setItemsActive(List<String> ids, bool active) =>
      updateItems(ids, {'is_active': active});

  Future<void> moveItems(List<String> ids, String categoryId) =>
      updateItems(ids, {'category_id': categoryId});

  /// Master sold-out switch. [until] is when the dish returns by itself.
  Future<void> setItemsSoldOut(
    List<String> ids,
    bool soldOut, {
    DateTime? until,
  }) => updateItems(ids, {
    'is_sold_out': soldOut,
    'sold_out_until': soldOut ? until?.toUtc().toIso8601String() : null,
  });

  Future<void> softDeleteItems(List<String> ids) =>
      updateItems(ids, {'deleted_at': DateTime.now().toUtc().toIso8601String()});

  Future<void> restoreItem(String id) async {
    await _client.rpc('restore_menu_item', params: {'p_item_id': id});
  }

  Future<void> deleteItemForever(String id) async {
    await _client.from('menu_items').delete().eq('id', id);
  }

  Future<String> duplicateItem(String id) async {
    final result = await _client.rpc(
      'duplicate_menu_item',
      params: {'p_item_id': id},
    );
    return result.toString();
  }

  Future<void> reorderItems(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    await _client.rpc('reorder_menu_items', params: {'p_ids': orderedIds});
  }

  /// Copies the variant and add-on groups of [fromItemId] onto [toItemId].
  Future<void> copyOptionGroups(String fromItemId, String toItemId) async {
    await _client.rpc(
      'copy_option_groups',
      params: {'p_from_item': fromItemId, 'p_to_item': toItemId},
    );
  }

  /// Returns how many dishes changed. [mode] is one of `percent_increase`,
  /// `percent_decrease`, `fixed_increase`, `fixed_decrease`, `set`; [target]
  /// is `price`, `discount` or `both`. With [branchId] the branch price
  /// override changes instead of the base price.
  Future<int> bulkAdjustPrices({
    required List<String> itemIds,
    required String mode,
    required double value,
    String target = 'price',
    bool roundWhole = false,
    String? branchId,
  }) async {
    final result = await _client.rpc(
      'bulk_adjust_prices',
      params: {
        'p_item_ids': itemIds,
        'p_mode': mode,
        'p_value': value,
        'p_target': target,
        'p_round_whole': roundWhole,
        'p_branch_id': branchId,
      },
    );
    if (result is num) return result.toInt();
    return int.tryParse(result.toString()) ?? 0;
  }

  /// Sends parsed spreadsheet rows to the `import_menu_items` function. At
  /// most 1000 rows per call.
  Future<ImportResult> importItems(
    String businessId,
    List<Map<String, dynamic>> rows, {
    bool updateExisting = true,
  }) async {
    final result = await _client.rpc(
      'import_menu_items',
      params: {
        'p_business_id': businessId,
        'p_rows': rows,
        'p_update_existing': updateExisting,
      },
    );
    if (result is Map) {
      return ImportResult.fromJson(Map<String, dynamic>.from(result));
    }
    return const ImportResult();
  }

  // ---- variants and add-ons ----------------------------------------------

  Future<List<OptionGroup>> optionGroups(String itemId) async {
    final groupRows = await _client
        .from('item_option_groups')
        .select()
        .eq('item_id', itemId)
        .order('sort_order')
        .order('created_at');
    if (groupRows.isEmpty) return const [];
    final groupIds = [for (final row in groupRows) row.requireStr('id')];
    final optionRows = await _client
        .from('item_options')
        .select()
        .inFilter('group_id', groupIds)
        .order('sort_order')
        .order('created_at');

    final byGroup = <String, List<ItemOption>>{};
    for (final row in optionRows) {
      byGroup
          .putIfAbsent(row.requireStr('group_id'), () => [])
          .add(ItemOption.fromJson(row));
    }
    return [
      for (final row in groupRows)
        OptionGroup.fromJson(row, options: byGroup[row.requireStr('id')] ?? []),
    ];
  }

  /// Makes the stored groups and options match [groups] (order included).
  /// Groups and options keep their ids, so nothing that refers to them breaks.
  /// New groups and options need a client generated uuid in `id`.
  Future<void> saveOptionGroups(String itemId, List<OptionGroup> groups) async {
    final existingGroups = await _client
        .from('item_option_groups')
        .select('id')
        .eq('item_id', itemId);
    final existingGroupIds = {
      for (final row in existingGroups) row.requireStr('id'),
    };
    final keepGroupIds = {for (final g in groups) g.id};

    final removedGroups = existingGroupIds.difference(keepGroupIds).toList();
    if (removedGroups.isNotEmpty) {
      await _client
          .from('item_option_groups')
          .delete()
          .inFilter('id', removedGroups);
    }

    if (groups.isNotEmpty) {
      await _client.from('item_option_groups').upsert([
        for (var i = 0; i < groups.length; i++)
          {
            'id': groups[i].id,
            'item_id': itemId,
            'name_en': emptyToNull(groups[i].nameEn),
            'name_bn': emptyToNull(groups[i].nameBn),
            'select_type': groups[i].selectType,
            'price_mode': groups[i].priceMode,
            'is_required': groups[i].isRequired,
            'min_select': groups[i].minSelect,
            'max_select': groups[i].maxSelect,
            'sort_order': i,
          },
      ], onConflict: 'id');
    }

    if (keepGroupIds.isEmpty) return;
    final existingOptions = await _client
        .from('item_options')
        .select('id')
        .inFilter('group_id', keepGroupIds.toList());
    final existingOptionIds = {
      for (final row in existingOptions) row.requireStr('id'),
    };
    final keepOptionIds = {
      for (final g in groups)
        for (final o in g.options) o.id,
    };
    final removedOptions = existingOptionIds.difference(keepOptionIds).toList();
    if (removedOptions.isNotEmpty) {
      await _client.from('item_options').delete().inFilter('id', removedOptions);
    }

    final optionRows = <Map<String, dynamic>>[];
    for (final group in groups) {
      for (var i = 0; i < group.options.length; i++) {
        final option = group.options[i];
        optionRows.add({
          'id': option.id,
          'group_id': group.id,
          'name_en': emptyToNull(option.nameEn),
          'name_bn': emptyToNull(option.nameBn),
          'price': option.price,
          'discount_price': option.discountPrice,
          'image_url': option.imageUrl,
          'is_default': option.isDefault,
          'is_available': option.isAvailable,
          'sort_order': i,
        });
      }
    }
    if (optionRows.isNotEmpty) {
      await _client.from('item_options').upsert(optionRows, onConflict: 'id');
    }
  }

  // ---- availability windows ----------------------------------------------

  Future<List<ItemSchedule>> schedules(String itemId) async {
    final rows = await _client
        .from('item_schedules')
        .select()
        .eq('item_id', itemId)
        .order('created_at');
    return rows.map((row) => ItemSchedule.fromJson(row)).toList();
  }

  /// Replaces all windows of the item. An empty list means always available.
  Future<void> saveSchedules(String itemId, List<ItemSchedule> windows) async {
    await _client.from('item_schedules').delete().eq('item_id', itemId);
    if (windows.isEmpty) return;
    await _client.from('item_schedules').insert([
      for (final window in windows) window.toRow(itemId),
    ]);
  }

  // ---- branch overrides ---------------------------------------------------

  Future<List<BranchItemSetting>> branchSettingsForItem(String itemId) async {
    final rows = await _client
        .from('branch_item_settings')
        .select()
        .eq('item_id', itemId);
    return rows.map((row) => BranchItemSetting.fromJson(row)).toList();
  }

  /// Overrides at one branch, keyed by item id.
  Future<Map<String, BranchItemSetting>> branchSettingsForBranch(
    String branchId,
  ) async {
    final rows = await _client
        .from('branch_item_settings')
        .select()
        .eq('branch_id', branchId);
    final settings = rows.map((row) => BranchItemSetting.fromJson(row));
    return {for (final setting in settings) setting.itemId: setting};
  }

  Future<void> saveBranchSetting(BranchItemSetting setting) async {
    await _client
        .from('branch_item_settings')
        .upsert(setting.toRow(), onConflict: 'branch_id,item_id');
  }

  Future<void> clearBranchSetting(String branchId, String itemId) async {
    await _client
        .from('branch_item_settings')
        .delete()
        .eq('branch_id', branchId)
        .eq('item_id', itemId);
  }

  /// Sold out (or back on sale) at one branch only. Other override fields on
  /// existing rows (price, hidden) are left alone.
  Future<void> setBranchSoldOut({
    required String branchId,
    required List<String> itemIds,
    required bool soldOut,
    DateTime? until,
  }) async {
    if (itemIds.isEmpty) return;
    await _client.from('branch_item_settings').upsert([
      for (final id in itemIds)
        {
          'branch_id': branchId,
          'item_id': id,
          'is_sold_out': soldOut,
          'sold_out_until': soldOut ? until?.toUtc().toIso8601String() : null,
        },
    ], onConflict: 'branch_id,item_id');
  }

  /// Show or hide dishes at one branch only.
  Future<void> setBranchOffered({
    required String branchId,
    required List<String> itemIds,
    required bool offered,
  }) async {
    if (itemIds.isEmpty) return;
    await _client.from('branch_item_settings').upsert([
      for (final id in itemIds)
        {'branch_id': branchId, 'item_id': id, 'is_offered': offered},
    ], onConflict: 'branch_id,item_id');
  }

  // ---- trash --------------------------------------------------------------

  Future<MenuTrash> trash(String businessId) async {
    final categories = await this.categories(businessId, deleted: true);
    final items = await this.items(businessId, deleted: true);
    return MenuTrash(categories: categories, items: items);
  }

  /// Permanently removes everything in the trash.
  Future<void> emptyTrash(String businessId) async {
    await _client
        .from('menu_items')
        .delete()
        .eq('business_id', businessId)
        .not('deleted_at', 'is', null);
    await _client
        .from('menu_categories')
        .delete()
        .eq('business_id', businessId)
        .not('deleted_at', 'is', null);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(supabaseClientProvider)),
);

/// Every category of the business (top level and sub), in display order.
final menuCategoriesProvider = FutureProvider.autoDispose<List<MenuCategory>>((
  ref,
) async {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const <MenuCategory>[];
  return ref.watch(menuRepositoryProvider).categories(businessId);
});

/// Every dish of the business, in display order.
final menuItemsProvider = FutureProvider.autoDispose<List<MenuItem>>((
  ref,
) async {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const <MenuItem>[];
  return ref.watch(menuRepositoryProvider).items(businessId);
});

/// One dish with its option groups, windows and branch overrides. Null when it
/// no longer exists.
final menuItemDetailProvider = FutureProvider.autoDispose
    .family<ItemDetail?, String>((ref, itemId) {
      return ref.watch(menuRepositoryProvider).itemDetail(itemId);
    });

/// Overrides at one branch, keyed by item id.
final branchItemSettingsProvider = FutureProvider.autoDispose
    .family<Map<String, BranchItemSetting>, String>((ref, branchId) {
      return ref.watch(menuRepositoryProvider).branchSettingsForBranch(branchId);
    });

/// Category id to "switched on at this branch".
final branchCategorySettingsProvider = FutureProvider.autoDispose
    .family<Map<String, bool>, String>((ref, branchId) {
      return ref.watch(menuRepositoryProvider).categorySettingsForBranch(branchId);
    });

final menuTrashProvider = FutureProvider.autoDispose<MenuTrash>((ref) async {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const MenuTrash();
  return ref.watch(menuRepositoryProvider).trash(businessId);
});

/// Dishes picked on the dish list, handed to the bulk price screen. The list
/// screen calls [set] and then opens `/menu/bulk-prices`; that screen reads it
/// once when it opens and calls [clear] when done.
class ItemSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void set(Iterable<String> ids) => state = {...ids};

  void clear() => state = <String>{};
}

final bulkPriceSelectionProvider =
    NotifierProvider<ItemSelectionNotifier, Set<String>>(
      ItemSelectionNotifier.new,
    );

/// Call after any change to categories, dishes, overrides or the trash so the
/// lists, the preview and the Home numbers reload.
extension MenuRefresh on WidgetRef {
  void refreshMenu() {
    invalidate(menuCategoriesProvider);
    invalidate(menuItemsProvider);
    invalidate(menuItemDetailProvider);
    invalidate(branchItemSettingsProvider);
    invalidate(branchCategorySettingsProvider);
    invalidate(menuTrashProvider);
    invalidate(menuStatsProvider);
  }
}
