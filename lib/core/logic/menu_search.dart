import '../../features/menu/menu_models.dart';
import 'money.dart';

/// Searching, filtering, sorting and quick-add parsing for the dish list.
/// Pure Dart: it imports only the menu models, which are pure as well.

enum ItemStatusFilter { all, visible, hidden, soldOut, featured, noPhoto }

enum ItemSort { menuOrder, nameAsc, priceLow, priceHigh, newest }

const Map<ItemStatusFilter, String> itemStatusLabels = {
  ItemStatusFilter.all: 'All',
  ItemStatusFilter.visible: 'Visible',
  ItemStatusFilter.hidden: 'Hidden',
  ItemStatusFilter.soldOut: 'Sold out',
  ItemStatusFilter.featured: 'Featured',
  ItemStatusFilter.noPhoto: 'No photo',
};

const Map<ItemSort, String> itemSortLabels = {
  ItemSort.menuOrder: 'Menu order',
  ItemSort.nameAsc: 'Name A-Z',
  ItemSort.priceLow: 'Price, low to high',
  ItemSort.priceHigh: 'Price, high to low',
  ItemSort.newest: 'Newest first',
};

/// Price a customer of one branch sees for a dish.
class EffectivePrice {
  const EffectivePrice({
    required this.price,
    this.discountPrice,
    this.isBranchPrice = false,
  });

  final double price;
  final double? discountPrice;
  final bool isBranchPrice;

  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  double get payable => hasDiscount ? discountPrice! : price;
}

/// The branch price replaces BOTH the regular and the discount price.
EffectivePrice effectivePriceAt(MenuItem item, BranchItemSetting? setting) {
  if (setting != null && setting.price != null) {
    return EffectivePrice(
      price: setting.price!,
      discountPrice: setting.discountPrice,
      isBranchPrice: true,
    );
  }
  return EffectivePrice(price: item.price, discountPrice: item.discountPrice);
}

/// Hidden at this branch (a per-branch override), regardless of the master switch.
bool isHiddenAtBranch(BranchItemSetting? setting) =>
    setting != null && !setting.isOffered;

/// Sold out right now, by the master switch or by the branch override.
bool isSoldOutNow(MenuItem item, BranchItemSetting? setting, DateTime now) =>
    item.isSoldOutAt(now) || (setting?.isSoldOutAt(now) ?? false);

/// The dish customers can see at this branch: switched on and not hidden there.
bool isVisibleToCustomers(MenuItem item, BranchItemSetting? setting) =>
    item.isActive && !isHiddenAtBranch(setting);

/// `needle` must already be normalised with [normalizeSearch].
bool _has(String? haystack, String needle) =>
    haystack != null && haystack.toLowerCase().contains(needle);

String normalizeSearch(String text) => text.trim().toLowerCase();

/// English name, Bangla name, SKU and the short descriptions.
bool itemMatchesQuery(MenuItem item, String query) {
  final needle = normalizeSearch(query);
  if (needle.isEmpty) return true;
  return _has(item.nameEn, needle) ||
      _has(item.nameBn, needle) ||
      _has(item.sku, needle) ||
      _has(item.shortDescriptionEn, needle) ||
      _has(item.shortDescriptionBn, needle);
}

/// The category with all of its subcategories.
Set<String> categoryWithDescendants(
  String categoryId,
  Iterable<MenuCategory> all,
) {
  return {
    categoryId,
    for (final c in all)
      if (c.parentId == categoryId) c.id,
  };
}

bool matchesStatus(
  MenuItem item,
  ItemStatusFilter filter,
  BranchItemSetting? setting,
  DateTime now,
) {
  switch (filter) {
    case ItemStatusFilter.all:
      return true;
    case ItemStatusFilter.visible:
      return isVisibleToCustomers(item, setting);
    case ItemStatusFilter.hidden:
      return !isVisibleToCustomers(item, setting);
    case ItemStatusFilter.soldOut:
      return isSoldOutNow(item, setting, now);
    case ItemStatusFilter.featured:
      return item.isFeatured;
    case ItemStatusFilter.noPhoto:
      return item.imageUrls.isEmpty;
  }
}

/// Everything the dish list can narrow by.
List<MenuItem> filterItems(
  List<MenuItem> items, {
  String query = '',
  Set<String>? categoryIds,
  ItemStatusFilter status = ItemStatusFilter.all,
  String? label,
  Map<String, BranchItemSetting> settings = const {},
  required DateTime now,
}) {
  return [
    for (final item in items)
      if (!item.isDeleted &&
          itemMatchesQuery(item, query) &&
          (categoryIds == null || categoryIds.contains(item.categoryId)) &&
          (label == null || item.labels.contains(label)) &&
          matchesStatus(item, status, settings[item.id], now))
        item,
  ];
}

/// Stable sort. [categoryRank] maps a category id to its position in the menu
/// and is used by [ItemSort.menuOrder].
List<MenuItem> sortItems(
  List<MenuItem> items,
  ItemSort sort, {
  Map<String, int> categoryRank = const {},
  Map<String, BranchItemSetting> settings = const {},
}) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  int compare((int, MenuItem) a, (int, MenuItem) b) {
    final x = a.$2;
    final y = b.$2;
    int result;
    switch (sort) {
      case ItemSort.menuOrder:
        result = (categoryRank[x.categoryId] ?? 1 << 30).compareTo(
          categoryRank[y.categoryId] ?? 1 << 30,
        );
        if (result == 0) result = x.sortOrder.compareTo(y.sortOrder);
      case ItemSort.nameAsc:
        result = x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase());
      case ItemSort.priceLow:
        result = effectivePriceAt(x, settings[x.id]).payable.compareTo(
          effectivePriceAt(y, settings[y.id]).payable,
        );
      case ItemSort.priceHigh:
        result = effectivePriceAt(y, settings[y.id]).payable.compareTo(
          effectivePriceAt(x, settings[x.id]).payable,
        );
      case ItemSort.newest:
        final xt = x.createdAt;
        final yt = y.createdAt;
        if (xt == null && yt == null) {
          result = 0;
        } else if (xt == null) {
          result = 1;
        } else if (yt == null) {
          result = -1;
        } else {
          result = yt.compareTo(xt);
        }
    }
    return result != 0 ? result : a.$1.compareTo(b.$1);
  }

  indexed.sort(compare);
  return [for (final entry in indexed) entry.$2];
}

/// Positions of categories in menu order (top level in order, each followed by
/// its subcategories), for [ItemSort.menuOrder].
Map<String, int> categoryRankOf(List<MenuCategory> all) {
  int byOrder(MenuCategory a, MenuCategory b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  final ids = {for (final c in all) c.id};
  final tops = [
    for (final c in all)
      if (c.parentId == null || !ids.contains(c.parentId)) c,
  ]..sort(byOrder);
  final rank = <String, int>{};
  var next = 0;
  for (final top in tops) {
    rank[top.id] = next++;
    final children = [
      for (final c in all)
        if (c.parentId == top.id) c,
    ]..sort(byOrder);
    for (final child in children) {
      rank[child.id] = next++;
    }
  }
  return rank;
}

/// New order of ids after a drag (Flutter `onReorder` convention).
List<String> reorderedItemIds(List<String> ids, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= ids.length) return List<String>.of(ids);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, ids.length - 1);
  final next = List<String>.of(ids);
  next.insert(target, next.removeAt(oldIndex));
  return next;
}

// ---------------------------------------------------------------------------
// Quick add: one dish per line
// ---------------------------------------------------------------------------

/// One parsed line of the quick add box.
class QuickAddRow {
  const QuickAddRow({
    required this.line,
    required this.raw,
    this.name,
    this.price,
    this.error,
    this.warning,
  });

  /// 1-based line number in the text the person typed.
  final int line;
  final String raw;
  final String? name;
  final double? price;
  final String? error;
  final String? warning;

  bool get isValid => error == null && name != null;
}

const int quickAddMaxNameLength = 160;
const double quickAddMaxPrice = 10000000;

final RegExp _digit = RegExp(r'[0-9০-৯]');
final RegExp _bangla = RegExp(r'[ঀ-৿]');

// A separator (comma or bar) followed by a price such as "250", "1,250.50",
// "tk 250", "৳250", "250 tk", "২৫০".
final RegExp _priceTail = RegExp(
  r'^(.*?)\s*[,|]\s*(?:(?:tk\.?|taka|bdt|৳)\s*)?'
  r'([0-9০-৯][0-9০-৯,]*(?:\.[0-9০-৯]+)?)'
  r'\s*(?:/-|tk\.?|taka|bdt|৳)?\s*$',
  caseSensitive: false,
);

bool containsBangla(String text) => _bangla.hasMatch(text);

/// Parses `Name, price` or `Name | price`, one dish per line.
///
/// * the price is optional; a missing price becomes 0 with a warning
/// * Bangla digits, "tk", "BDT", "৳", thousands separators are accepted
/// * a comma inside a name is fine when no valid price follows it
/// * empty lines are skipped; duplicate names in the text are errors
List<QuickAddRow> parseQuickAdd(String text) {
  final rows = <QuickAddRow>[];
  final seen = <String, int>{};
  final lines = text.split(RegExp(r'\r?\n'));
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final lineNumber = i + 1;

    String name;
    double? price;
    String? error;

    final match = _priceTail.firstMatch(trimmed);
    if (match != null) {
      name = match.group(1)!.trim();
      price = parseAmount(match.group(2));
      if (price == null) error = 'The price is not a number.';
    } else {
      // No valid price. If something after the last separator looks like a
      // number the person probably mistyped a price.
      final cut = _lastSeparator(trimmed);
      final tail = cut < 0 ? '' : trimmed.substring(cut + 1);
      if (cut >= 0 && _digit.hasMatch(tail)) {
        name = trimmed.substring(0, cut).trim();
        error = 'The price "${tail.trim()}" is not a valid number.';
      } else {
        name = trimmed;
      }
    }

    String? warning;
    if (error == null) {
      if (name.isEmpty) {
        error = 'The dish name is missing.';
      } else if (name.length > quickAddMaxNameLength) {
        error = 'The name is longer than $quickAddMaxNameLength characters.';
      } else if (price != null && price > quickAddMaxPrice) {
        error = 'That price is too high.';
      } else if (price == null) {
        warning = 'No price given, it will be set to 0.';
      }
    }

    if (error == null) {
      final key = name.toLowerCase();
      final first = seen[key];
      if (first != null) {
        error = 'Same name as line $first.';
      } else {
        seen[key] = lineNumber;
      }
    }

    rows.add(
      QuickAddRow(
        line: lineNumber,
        raw: trimmed,
        name: name.isEmpty ? null : name,
        price: price,
        error: error,
        warning: warning,
      ),
    );
  }
  return rows;
}

int _lastSeparator(String text) {
  final comma = text.lastIndexOf(',');
  final bar = text.lastIndexOf('|');
  return comma > bar ? comma : bar;
}

/// Column values for creating the dish. The name goes into the Bangla column
/// when it contains Bangla letters, else into the English one.
Map<String, dynamic> quickAddValues(
  QuickAddRow row, {
  required String categoryId,
  required int sortOrder,
}) {
  final name = row.name ?? '';
  final isBangla = containsBangla(name);
  return {
    'category_id': categoryId,
    if (isBangla) 'name_bn': name else 'name_en': name,
    'price': row.price ?? 0,
    'sort_order': sortOrder,
    'is_active': true,
  };
}

/// Sort order for a dish added to the end of a category.
int nextItemSortOrder(Iterable<MenuItem> itemsInCategory) {
  var max = -1;
  for (final item in itemsInCategory) {
    if (item.sortOrder > max) max = item.sortOrder;
  }
  return max + 1;
}
