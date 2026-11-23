import 'menu_models.dart';

/// Pure helpers for the category screens: tree building, counting, search,
/// reorder maths, relative time and form validation. No Flutter imports.

/// A top level category with its subcategories (one level only).
class CategoryNode {
  const CategoryNode(this.category, this.children);

  final MenuCategory category;
  final List<MenuCategory> children;
}

int _compareCategories(MenuCategory a, MenuCategory b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  if (byOrder != 0) return byOrder;
  final aTime = a.createdAt;
  final bTime = b.createdAt;
  if (aTime != null && bTime != null) {
    final byTime = aTime.compareTo(bTime);
    if (byTime != 0) return byTime;
  } else if (aTime != null) {
    return -1;
  } else if (bTime != null) {
    return 1;
  }
  return a.id.compareTo(b.id);
}

/// Parents with their children, both sorted by order then creation time.
/// A subcategory whose parent is missing from [all] is shown at top level so
/// it never disappears.
List<CategoryNode> buildCategoryTree(List<MenuCategory> all) {
  final ids = {for (final c in all) c.id};
  final tops = <MenuCategory>[];
  final byParent = <String, List<MenuCategory>>{};
  for (final category in all) {
    final parent = category.parentId;
    if (parent != null && parent != category.id && ids.contains(parent)) {
      byParent.putIfAbsent(parent, () => []).add(category);
    } else {
      tops.add(category);
    }
  }
  tops.sort(_compareCategories);
  return [
    for (final top in tops)
      CategoryNode(top, (byParent[top.id] ?? <MenuCategory>[])..sort(_compareCategories)),
  ];
}

/// Number of dishes directly inside each category id.
Map<String, int> countItemsByCategory(Iterable<MenuItem> items) {
  final counts = <String, int>{};
  for (final item in items) {
    if (item.isDeleted) continue;
    counts[item.categoryId] = (counts[item.categoryId] ?? 0) + 1;
  }
  return counts;
}

/// Dish count of each top level category including its subcategories, and the
/// own count for subcategories.
Map<String, int> countItemsWithChildren(
  List<CategoryNode> tree,
  Map<String, int> direct,
) {
  final totals = <String, int>{};
  for (final node in tree) {
    var sum = direct[node.category.id] ?? 0;
    for (final child in node.children) {
      final own = direct[child.id] ?? 0;
      totals[child.id] = own;
      sum += own;
    }
    totals[node.category.id] = sum;
  }
  return totals;
}

bool _contains(String? haystack, String needle) {
  if (haystack == null) return false;
  return haystack.toLowerCase().contains(needle);
}

/// True when the English or Bangla name contains [query] (case-insensitive).
bool categoryMatches(MenuCategory category, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return _contains(category.nameEn, needle) || _contains(category.nameBn, needle);
}

/// Keeps a parent when it or any child matches. When only a child matches the
/// parent stays with just the matching children; when the parent itself
/// matches all its children stay.
List<CategoryNode> filterCategoryTree(List<CategoryNode> tree, String query) {
  if (query.trim().isEmpty) return tree;
  final result = <CategoryNode>[];
  for (final node in tree) {
    if (categoryMatches(node.category, query)) {
      result.add(node);
      continue;
    }
    final matching = [
      for (final child in node.children)
        if (categoryMatches(child, query)) child,
    ];
    if (matching.isNotEmpty) result.add(CategoryNode(node.category, matching));
  }
  return result;
}

/// The ids in their new order after a drag, using the Flutter
/// `ReorderableListView.onReorder` convention (newIndex is before removal).
List<String> reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= ids.length) return List<String>.of(ids);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, ids.length - 1);
  final next = List<String>.of(ids);
  final moved = next.removeAt(oldIndex);
  next.insert(target, moved);
  return next;
}

/// Sort order for a new category: after the last sibling.
int nextSortOrder(Iterable<MenuCategory> siblings) {
  var max = -1;
  for (final sibling in siblings) {
    if (sibling.sortOrder > max) max = sibling.sortOrder;
  }
  return max + 1;
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "just now", "5 minutes ago", "1 hour ago", "2 days ago", then a date
/// such as "12 Nov 2026" once it is more than a week old.
String relativeTime(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (diff.inDays <= 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  final local = then.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// What the category form holds, as typed.
class CategoryFormInput {
  const CategoryFormInput({
    this.nameEn = '',
    this.nameBn = '',
    this.descriptionEn = '',
    this.descriptionBn = '',
    this.parentId,
    this.selfId,
    this.hasChildren = false,
  });

  final String nameEn;
  final String nameBn;
  final String descriptionEn;
  final String descriptionBn;
  final String? parentId;

  /// Id of the category being edited, null when new.
  final String? selfId;

  /// True when the category already has subcategories (it cannot get a parent).
  final bool hasChildren;
}

/// Field name to message. Empty map means the form is valid. Keys: `name`,
/// `nameEn`, `nameBn`, `descriptionEn`, `descriptionBn`, `parent`.
Map<String, String> validateCategoryForm(CategoryFormInput input) {
  final errors = <String, String>{};
  final en = input.nameEn.trim();
  final bn = input.nameBn.trim();
  if (en.isEmpty && bn.isEmpty) {
    errors['name'] = 'Enter a name in English or Bangla.';
  }
  if (en.length > 120) errors['nameEn'] = 'The English name must be 120 characters or fewer.';
  if (bn.length > 120) errors['nameBn'] = 'The Bangla name must be 120 characters or fewer.';
  if (input.descriptionEn.trim().length > 500) {
    errors['descriptionEn'] = 'The English description must be 500 characters or fewer.';
  }
  if (input.descriptionBn.trim().length > 500) {
    errors['descriptionBn'] = 'The Bangla description must be 500 characters or fewer.';
  }
  if (input.parentId != null) {
    if (input.parentId == input.selfId) {
      errors['parent'] = 'A category cannot be its own parent.';
    } else if (input.hasChildren) {
      errors['parent'] =
          'This category has subcategories, so it cannot go inside another one.';
    }
  }
  return errors;
}

/// Builds the column map for `saveCategory`. Empty text becomes null.
Map<String, dynamic> categoryValues(
  CategoryFormInput input, {
  required String? imageUrl,
  required String? icon,
  required bool isActive,
  int? sortOrder,
}) {
  String? clean(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  return {
    'name_en': clean(input.nameEn),
    'name_bn': clean(input.nameBn),
    'description_en': clean(input.descriptionEn),
    'description_bn': clean(input.descriptionBn),
    'parent_id': input.parentId,
    'image_url': imageUrl,
    'icon': icon,
    'is_active': isActive,
    if (sortOrder != null) 'sort_order': sortOrder,
  };
}
