import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/category_logic.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

MenuCategory cat(
  String id, {
  String? parent,
  String? en,
  String? bn,
  int order = 0,
  DateTime? created,
}) => MenuCategory(
  id: id,
  businessId: 'b',
  parentId: parent,
  nameEn: en,
  nameBn: bn,
  sortOrder: order,
  createdAt: created,
);

MenuItem item(String id, String categoryId, {DateTime? deleted}) =>
    MenuItem(id: id, businessId: 'b', categoryId: categoryId, deletedAt: deleted);

void main() {
  group('buildCategoryTree', () {
    test('nests children and sorts by order', () {
      final tree = buildCategoryTree([
        cat('b', en: 'B', order: 2),
        cat('a', en: 'A', order: 1),
        cat('a2', parent: 'a', en: 'A2', order: 2),
        cat('a1', parent: 'a', en: 'A1', order: 1),
      ]);
      expect(tree.map((n) => n.category.id).toList(), equals(['a', 'b']));
      expect(tree.first.children.map((c) => c.id).toList(), equals(['a1', 'a2']));
      expect(tree.last.children, isEmpty);
    });

    test('ties are broken by creation time then id', () {
      final tree = buildCategoryTree([
        cat('z', en: 'Z', created: DateTime.utc(2026, 1, 2)),
        cat('y', en: 'Y', created: DateTime.utc(2026, 1, 1)),
        cat('x', en: 'X'),
      ]);
      expect(tree.map((n) => n.category.id).toList(), equals(['y', 'z', 'x']));
    });

    test('an orphan child is shown at top level', () {
      final tree = buildCategoryTree([cat('c', parent: 'missing', en: 'C')]);
      expect(tree.length, equals(1));
      expect(tree.first.category.id, equals('c'));
    });

    test('empty list gives an empty tree', () {
      expect(buildCategoryTree(const []), isEmpty);
    });
  });

  group('counting', () {
    test('countItemsByCategory skips deleted dishes', () {
      final counts = countItemsByCategory([
        item('1', 'a'),
        item('2', 'a'),
        item('3', 'b'),
        item('4', 'b', deleted: DateTime.utc(2026, 1, 1)),
      ]);
      expect(counts['a'], equals(2));
      expect(counts['b'], equals(1));
    });

    test('parents include their subcategories', () {
      final tree = buildCategoryTree([
        cat('a', en: 'A'),
        cat('a1', parent: 'a', en: 'A1'),
        cat('b', en: 'B'),
      ]);
      final totals = countItemsWithChildren(tree, {'a': 1, 'a1': 3, 'b': 2});
      expect(totals['a'], equals(4));
      expect(totals['a1'], equals(3));
      expect(totals['b'], equals(2));
    });

    test('missing counts are zero', () {
      final tree = buildCategoryTree([cat('a', en: 'A')]);
      expect(countItemsWithChildren(tree, const {})['a'], equals(0));
    });
  });

  group('search', () {
    final tree = buildCategoryTree([
      cat('a', en: 'Starters', bn: 'শুরুর খাবার'),
      cat('a1', parent: 'a', en: 'Soup', bn: 'স্যুপ'),
      cat('a2', parent: 'a', en: 'Salad'),
      cat('b', en: 'Drinks', bn: 'পানীয়'),
      cat('b1', parent: 'b', en: 'Hot coffee'),
    ]);

    test('empty query keeps everything', () {
      expect(filterCategoryTree(tree, '  ').length, equals(2));
    });

    test('matches English ignoring case', () {
      final result = filterCategoryTree(tree, 'DRINK');
      expect(result.length, equals(1));
      expect(result.first.children.length, equals(1));
    });

    test('matches Bangla names', () {
      final result = filterCategoryTree(tree, 'পানীয়');
      expect(result.length, equals(1));
      expect(result.first.category.id, equals('b'));
    });

    test('a child match keeps only matching children under the parent', () {
      final result = filterCategoryTree(tree, 'soup');
      expect(result.length, equals(1));
      expect(result.first.category.id, equals('a'));
      expect(result.first.children.map((c) => c.id).toList(), equals(['a1']));
    });

    test('no match gives an empty list', () {
      expect(filterCategoryTree(tree, 'zzz'), isEmpty);
    });

    test('categoryMatches handles a missing name', () {
      expect(categoryMatches(cat('x', bn: 'ভাত'), 'rice'), isFalse);
      expect(categoryMatches(cat('x', bn: 'ভাত'), 'ভাত'), isTrue);
    });
  });

  group('reorderedIds', () {
    test('moves down using the Flutter convention', () {
      expect(reorderedIds(['a', 'b', 'c', 'd'], 0, 3), equals(['b', 'c', 'a', 'd']));
    });

    test('moves to the end', () {
      expect(reorderedIds(['a', 'b', 'c'], 0, 3), equals(['b', 'c', 'a']));
    });

    test('moves up', () {
      expect(reorderedIds(['a', 'b', 'c'], 2, 0), equals(['c', 'a', 'b']));
    });

    test('same position keeps the order', () {
      expect(reorderedIds(['a', 'b', 'c'], 1, 1), equals(['a', 'b', 'c']));
      expect(reorderedIds(['a', 'b', 'c'], 1, 2), equals(['a', 'b', 'c']));
    });

    test('bad index returns a copy', () {
      expect(reorderedIds(['a', 'b'], 5, 0), equals(['a', 'b']));
    });
  });

  group('nextSortOrder', () {
    test('is zero for no siblings', () {
      expect(nextSortOrder(const []), equals(0));
    });

    test('is one after the largest', () {
      expect(nextSortOrder([cat('a', order: 3), cat('b', order: 7)]), equals(8));
    });
  });

  group('relativeTime', () {
    final now = DateTime.utc(2026, 11, 20, 12, 0);

    test('just now', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now), equals('just now'));
    });

    test('minutes', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 1)), now), equals('1 minute ago'));
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now), equals('5 minutes ago'));
    });

    test('hours', () {
      expect(relativeTime(now.subtract(const Duration(hours: 1)), now), equals('1 hour ago'));
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now), equals('3 hours ago'));
    });

    test('days', () {
      expect(relativeTime(now.subtract(const Duration(days: 1)), now), equals('1 day ago'));
      expect(relativeTime(now.subtract(const Duration(days: 2)), now), equals('2 days ago'));
    });

    test('older than a week shows a date', () {
      final text = relativeTime(DateTime(2026, 11, 1, 12), DateTime(2026, 11, 20, 12));
      expect(text, equals('1 Nov 2026'));
    });

    test('a future time is just now', () {
      expect(relativeTime(now.add(const Duration(hours: 1)), now), equals('just now'));
    });
  });

  group('validateCategoryForm', () {
    test('needs a name in one language', () {
      expect(validateCategoryForm(const CategoryFormInput()).containsKey('name'), isTrue);
      expect(validateCategoryForm(const CategoryFormInput(nameBn: 'ভাত')), isEmpty);
      expect(validateCategoryForm(const CategoryFormInput(nameEn: 'Rice')), isEmpty);
    });

    test('spaces only is empty', () {
      expect(validateCategoryForm(const CategoryFormInput(nameEn: '   ')).containsKey('name'), isTrue);
    });

    test('name length limit', () {
      final errors = validateCategoryForm(CategoryFormInput(nameEn: 'a' * 121));
      expect(errors.containsKey('nameEn'), isTrue);
      expect(validateCategoryForm(CategoryFormInput(nameEn: 'a' * 120)), isEmpty);
    });

    test('description length limit', () {
      final errors = validateCategoryForm(
        CategoryFormInput(nameEn: 'A', descriptionBn: 'ক' * 501),
      );
      expect(errors.containsKey('descriptionBn'), isTrue);
    });

    test('cannot be its own parent', () {
      final errors = validateCategoryForm(
        const CategoryFormInput(nameEn: 'A', parentId: 'x', selfId: 'x'),
      );
      expect(errors.containsKey('parent'), isTrue);
    });

    test('a category with children cannot get a parent', () {
      final errors = validateCategoryForm(
        const CategoryFormInput(nameEn: 'A', parentId: 'p', selfId: 'x', hasChildren: true),
      );
      expect(errors.containsKey('parent'), isTrue);
    });

    test('a normal child is fine', () {
      expect(
        validateCategoryForm(const CategoryFormInput(nameEn: 'A', parentId: 'p', selfId: 'x')),
        isEmpty,
      );
    });
  });

  group('categoryValues', () {
    test('empty text becomes null and sort order is optional', () {
      final values = categoryValues(
        const CategoryFormInput(nameEn: ' Rice ', nameBn: '', parentId: null),
        imageUrl: null,
        icon: 'rice',
        isActive: true,
      );
      expect(values['name_en'], equals('Rice'));
      expect(values['name_bn'], isNull);
      expect(values['icon'], equals('rice'));
      expect(values.containsKey('sort_order'), isFalse);
      final withOrder = categoryValues(
        const CategoryFormInput(nameEn: 'A'),
        imageUrl: 'u',
        icon: null,
        isActive: false,
        sortOrder: 4,
      );
      expect(withOrder['sort_order'], equals(4));
      expect(withOrder['is_active'], isFalse);
    });
  });
}
