import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/core/logic/menu_search.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

MenuItem dish(
  String id, {
  String category = 'c1',
  String? en,
  String? bn,
  String? sku,
  String? shortEn,
  double price = 100,
  double? discount,
  bool active = true,
  bool featured = false,
  bool soldOut = false,
  DateTime? soldOutUntil,
  List<String> labels = const [],
  List<String> images = const [],
  int order = 0,
  DateTime? created,
  DateTime? deleted,
}) => MenuItem(
  id: id,
  businessId: 'b',
  categoryId: category,
  nameEn: en,
  nameBn: bn,
  sku: sku,
  shortDescriptionEn: shortEn,
  price: price,
  discountPrice: discount,
  isActive: active,
  isFeatured: featured,
  isSoldOut: soldOut,
  soldOutUntil: soldOutUntil,
  labels: labels,
  imageUrls: images,
  sortOrder: order,
  createdAt: created,
  deletedAt: deleted,
);

BranchItemSetting setting(
  String itemId, {
  bool offered = true,
  double? price,
  double? discount,
  bool soldOut = false,
  DateTime? until,
}) => BranchItemSetting(
  branchId: 'br',
  itemId: itemId,
  isOffered: offered,
  price: price,
  discountPrice: discount,
  isSoldOut: soldOut,
  soldOutUntil: until,
);

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);

  group('itemMatchesQuery', () {
    final item = dish('1', en: 'Chicken Burger', bn: 'চিকেন বার্গার', sku: 'CB-01', shortEn: 'Juicy grilled patty');

    test('empty query matches', () => expect(itemMatchesQuery(item, '  '), isTrue));
    test('English is case-insensitive', () => expect(itemMatchesQuery(item, 'BURGER'), isTrue));
    test('Bangla matches by contains', () => expect(itemMatchesQuery(item, 'বার্গার'), isTrue));
    test('SKU matches', () => expect(itemMatchesQuery(item, 'cb-0'), isTrue));
    test('short description matches', () => expect(itemMatchesQuery(item, 'grilled'), isTrue));
    test('no match', () => expect(itemMatchesQuery(item, 'pizza'), isFalse));
    test('missing fields do not crash', () => expect(itemMatchesQuery(dish('2'), 'x'), isFalse));
  });

  group('effective price and branch state', () {
    test('base price without override', () {
      final p = effectivePriceAt(dish('1', price: 200, discount: 150), null);
      expect(p.price, equals(200));
      expect(p.payable, equals(150));
      expect(p.isBranchPrice, isFalse);
    });

    test('branch price replaces both regular and discount price', () {
      final p = effectivePriceAt(dish('1', price: 200, discount: 150), setting('1', price: 300));
      expect(p.price, equals(300));
      expect(p.discountPrice, isNull);
      expect(p.payable, equals(300));
      expect(p.isBranchPrice, isTrue);
    });

    test('branch discount applies to the branch price', () {
      final p = effectivePriceAt(dish('1', price: 200), setting('1', price: 300, discount: 250));
      expect(p.payable, equals(250));
    });

    test('a discount that is not lower is ignored', () {
      final p = effectivePriceAt(dish('1', price: 100, discount: 100), null);
      expect(p.hasDiscount, isFalse);
      expect(p.payable, equals(100));
    });

    test('an override without price keeps the base price', () {
      final p = effectivePriceAt(dish('1', price: 200), setting('1', soldOut: true));
      expect(p.price, equals(200));
      expect(p.isBranchPrice, isFalse);
    });

    test('hidden at branch', () {
      expect(isHiddenAtBranch(setting('1', offered: false)), isTrue);
      expect(isHiddenAtBranch(setting('1')), isFalse);
      expect(isHiddenAtBranch(null), isFalse);
    });

    test('visible needs active and offered', () {
      expect(isVisibleToCustomers(dish('1'), null), isTrue);
      expect(isVisibleToCustomers(dish('1', active: false), null), isFalse);
      expect(isVisibleToCustomers(dish('1'), setting('1', offered: false)), isFalse);
    });
  });

  group('isSoldOutNow', () {
    test('master switch with no return time', () {
      expect(isSoldOutNow(dish('1', soldOut: true), null, now), isTrue);
    });

    test('master switch with a future return time', () {
      expect(isSoldOutNow(dish('1', soldOut: true, soldOutUntil: now.add(const Duration(hours: 1))), null, now), isTrue);
    });

    test('master switch with a passed return time is available again', () {
      expect(isSoldOutNow(dish('1', soldOut: true, soldOutUntil: now.subtract(const Duration(minutes: 1))), null, now), isFalse);
    });

    test('branch sold out only', () {
      expect(isSoldOutNow(dish('1'), setting('1', soldOut: true), now), isTrue);
      expect(isSoldOutNow(dish('1'), setting('1', soldOut: true, until: now.subtract(const Duration(hours: 1))), now), isFalse);
    });

    test('not sold out', () {
      expect(isSoldOutNow(dish('1'), null, now), isFalse);
    });
  });

  group('categoryWithDescendants', () {
    test('includes the category and its children only', () {
      const cats = [
        MenuCategory(id: 'a', businessId: 'b'),
        MenuCategory(id: 'a1', businessId: 'b', parentId: 'a'),
        MenuCategory(id: 'b', businessId: 'b'),
        MenuCategory(id: 'b1', businessId: 'b', parentId: 'b'),
      ];
      expect(categoryWithDescendants('a', cats), equals({'a', 'a1'}));
      expect(categoryWithDescendants('a1', cats), equals({'a1'}));
    });
  });

  group('filterItems', () {
    final items = [
      dish('1', en: 'Burger', category: 'c1', labels: ['spicy'], images: ['x'], featured: true),
      dish('2', en: 'Pizza', category: 'c2', active: false),
      dish('3', en: 'Soup', category: 'c1', soldOut: true),
      dish('4', en: 'Old', category: 'c1', deleted: DateTime.utc(2026)),
    ];

    List<String> ids(List<MenuItem> list) => [for (final i in list) i.id];

    test('deleted dishes never show', () {
      expect(ids(filterItems(items, now: now)), equals(['1', '2', '3']));
    });

    test('category filter', () {
      expect(ids(filterItems(items, categoryIds: {'c1'}, now: now)), equals(['1', '3']));
    });

    test('status filters', () {
      expect(ids(filterItems(items, status: ItemStatusFilter.visible, now: now)), equals(['1', '3']));
      expect(ids(filterItems(items, status: ItemStatusFilter.hidden, now: now)), equals(['2']));
      expect(ids(filterItems(items, status: ItemStatusFilter.soldOut, now: now)), equals(['3']));
      expect(ids(filterItems(items, status: ItemStatusFilter.featured, now: now)), equals(['1']));
      expect(ids(filterItems(items, status: ItemStatusFilter.noPhoto, now: now)), equals(['2', '3']));
    });

    test('label filter', () {
      expect(ids(filterItems(items, label: 'spicy', now: now)), equals(['1']));
    });

    test('branch settings change visibility and sold out', () {
      final settings = {'1': setting('1', offered: false), '2': setting('2', soldOut: true)};
      expect(ids(filterItems(items, status: ItemStatusFilter.hidden, settings: settings, now: now)), equals(['1', '2']));
      expect(ids(filterItems(items, status: ItemStatusFilter.soldOut, settings: settings, now: now)), equals(['2', '3']));
    });

    test('combined query and status', () {
      expect(ids(filterItems(items, query: 'so', status: ItemStatusFilter.soldOut, now: now)), equals(['3']));
    });
  });

  group('sortItems', () {
    final a = dish('a', en: 'banana', price: 50, order: 2, created: DateTime.utc(2026, 1, 1));
    final b = dish('b', en: 'Apple', price: 80, order: 1, created: DateTime.utc(2026, 3, 1));
    final c = dish('c', en: 'cherry', price: 50, order: 3, created: DateTime.utc(2026, 2, 1));

    List<String> ids(List<MenuItem> list) => [for (final i in list) i.id];

    test('menu order uses category rank then sort order', () {
      final d = dish('d', category: 'c0', order: 9);
      final result = sortItems([a, b, d], ItemSort.menuOrder, categoryRank: {'c0': 0, 'c1': 1});
      expect(ids(result), equals(['d', 'b', 'a']));
    });

    test('name sort ignores case', () {
      expect(ids(sortItems([a, b, c], ItemSort.nameAsc)), equals(['b', 'a', 'c']));
    });

    test('price sort is stable for equal prices', () {
      expect(ids(sortItems([a, b, c], ItemSort.priceLow)), equals(['a', 'c', 'b']));
      expect(ids(sortItems([a, b, c], ItemSort.priceHigh)), equals(['b', 'a', 'c']));
    });

    test('price sort uses the branch price', () {
      final result = sortItems([a, b], ItemSort.priceLow, settings: {'a': setting('a', price: 500)});
      expect(ids(result), equals(['b', 'a']));
    });

    test('newest first, missing dates last', () {
      final d = dish('d');
      expect(ids(sortItems([d, a, b, c], ItemSort.newest)), equals(['b', 'c', 'a', 'd']));
    });

    test('does not change the input list', () {
      final list = [b, a];
      sortItems(list, ItemSort.nameAsc);
      expect(ids(list), equals(['b', 'a']));
    });
  });

  group('categoryRankOf', () {
    test('parents are followed by their children', () {
      const cats = [
        MenuCategory(id: 'b', businessId: 'x', sortOrder: 2),
        MenuCategory(id: 'a', businessId: 'x', sortOrder: 1),
        MenuCategory(id: 'a2', businessId: 'x', parentId: 'a', sortOrder: 2),
        MenuCategory(id: 'a1', businessId: 'x', parentId: 'a', sortOrder: 1),
      ];
      final rank = categoryRankOf(cats);
      expect(rank['a'], equals(0));
      expect(rank['a1'], equals(1));
      expect(rank['a2'], equals(2));
      expect(rank['b'], equals(3));
    });
  });

  group('reorderedItemIds', () {
    test('moves an id', () {
      expect(reorderedItemIds(['a', 'b', 'c'], 0, 3), equals(['b', 'c', 'a']));
      expect(reorderedItemIds(['a', 'b', 'c'], 2, 0), equals(['c', 'a', 'b']));
    });
  });

  group('parseQuickAdd', () {
    test('name and price with a comma', () {
      final rows = parseQuickAdd('Chicken Burger, 250');
      expect(rows.length, equals(1));
      expect(rows.first.name, equals('Chicken Burger'));
      expect(rows.first.price, equals(250));
      expect(rows.first.isValid, isTrue);
    });

    test('bar separator', () {
      final rows = parseQuickAdd('Beef Burger | 320.50');
      expect(rows.first.name, equals('Beef Burger'));
      expect(rows.first.price, equals(320.5));
    });

    test('currency words and symbols', () {
      expect(parseQuickAdd('Tea, tk 30').first.price, equals(30));
      expect(parseQuickAdd('Tea, 30 tk').first.price, equals(30));
      expect(parseQuickAdd('Tea, ৳30').first.price, equals(30));
      expect(parseQuickAdd('Tea | 30 BDT').first.price, equals(30));
      expect(parseQuickAdd('Tea, 30/-').first.price, equals(30));
    });

    test('Bangla digits and Bangla names', () {
      final rows = parseQuickAdd('চিকেন বার্গার, ২৫০');
      expect(rows.first.name, equals('চিকেন বার্গার'));
      expect(rows.first.price, equals(250));
    });

    test('thousands separators', () {
      final rows = parseQuickAdd('Family Pack, 1,250');
      expect(rows.first.name, equals('Family Pack'));
      expect(rows.first.price, equals(1250));
    });

    test('a comma inside the name is kept when no price follows', () {
      final rows = parseQuickAdd('Chicken, Fried, 280');
      expect(rows.first.name, equals('Chicken, Fried'));
      expect(rows.first.price, equals(280));
      final plain = parseQuickAdd('Chicken, Fried');
      expect(plain.first.name, equals('Chicken, Fried'));
      expect(plain.first.price, isNull);
      expect(plain.first.isValid, isTrue);
    });

    test('price is optional and warns', () {
      final row = parseQuickAdd('Water').first;
      expect(row.isValid, isTrue);
      expect(row.price, isNull);
      expect(row.warning, isNotNull);
    });

    test('empty lines are skipped and line numbers are kept', () {
      final rows = parseQuickAdd('A, 1\n\n   \nB, 2');
      expect(rows.length, equals(2));
      expect(rows[0].line, equals(1));
      expect(rows[1].line, equals(4));
    });

    test('windows line endings', () {
      expect(parseQuickAdd('A, 1\r\nB, 2').length, equals(2));
    });

    test('duplicate names are errors on the later line', () {
      final rows = parseQuickAdd('Tea, 10\ntea, 20');
      expect(rows[0].isValid, isTrue);
      expect(rows[1].error, contains('line 1'));
    });

    test('a name that is too long', () {
      final rows = parseQuickAdd('${'a' * 161}, 10');
      expect(rows.first.isValid, isFalse);
      expect(rows.first.error, contains('160'));
      expect(parseQuickAdd('${'a' * 160}, 10').first.isValid, isTrue);
    });

    test('an invalid price is an error', () {
      final rows = parseQuickAdd('Burger, 12abc');
      expect(rows.first.isValid, isFalse);
      expect(rows.first.error, contains('12abc'));
    });

    test('a negative price is an error', () {
      expect(parseQuickAdd('Burger, -50').first.isValid, isFalse);
    });

    test('a missing name is an error', () {
      final rows = parseQuickAdd(', 250');
      expect(rows.first.isValid, isFalse);
    });

    test('a huge price is an error', () {
      expect(parseQuickAdd('Gold plate, 99999999').first.isValid, isFalse);
    });

    test('empty text gives no rows', () {
      expect(parseQuickAdd(''), isEmpty);
      expect(parseQuickAdd('  \n  '), isEmpty);
    });
  });

  group('quickAddValues', () {
    test('English names go to name_en', () {
      final row = parseQuickAdd('Tea, 30').first;
      final values = quickAddValues(row, categoryId: 'c', sortOrder: 4);
      expect(values['name_en'], equals('Tea'));
      expect(values.containsKey('name_bn'), isFalse);
      expect(values['price'], equals(30));
      expect(values['sort_order'], equals(4));
      expect(values['category_id'], equals('c'));
    });

    test('Bangla names go to name_bn and a missing price is zero', () {
      final row = parseQuickAdd('চা').first;
      final values = quickAddValues(row, categoryId: 'c', sortOrder: 0);
      expect(values['name_bn'], equals('চা'));
      expect(values.containsKey('name_en'), isFalse);
      expect(values['price'], equals(0));
    });
  });

  group('nextItemSortOrder', () {
    test('is zero for an empty category and max + 1 otherwise', () {
      expect(nextItemSortOrder(const []), equals(0));
      expect(nextItemSortOrder([dish('1', order: 4), dish('2', order: 9)]), equals(10));
    });
  });
}
