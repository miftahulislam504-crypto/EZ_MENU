import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/availability_logic.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

final DateTime now = DateTime(2026, 11, 21, 12, 0);

MenuItem dish(
  String id, {
  String category = 'c1',
  String? en,
  String? bn,
  bool active = true,
  bool soldOut = false,
  DateTime? until,
  int order = 0,
  DateTime? deleted,
  String? sku,
}) => MenuItem(
  id: id,
  businessId: 'b',
  categoryId: category,
  nameEn: en ?? id,
  nameBn: bn,
  isActive: active,
  isSoldOut: soldOut,
  soldOutUntil: until,
  sortOrder: order,
  deletedAt: deleted,
  sku: sku,
);

BranchItemSetting branchSetting(
  String itemId, {
  bool soldOut = false,
  DateTime? until,
}) => BranchItemSetting(
  branchId: 'br',
  itemId: itemId,
  isSoldOut: soldOut,
  soldOutUntil: until,
);

MenuCategory category(String id, {String? parent, String? en, int order = 0}) =>
    MenuCategory(
      id: id,
      businessId: 'b',
      parentId: parent,
      nameEn: en ?? id,
      sortOrder: order,
    );

void main() {
  group('stockStatus', () {
    test('a normal dish is available', () {
      final s = stockStatus(dish('a'), null, now);
      expect(s.soldOut, isFalse);
      expect(s.until, isNull);
      expect(s.byMaster, isFalse);
      expect(s.byBranch, isFalse);
    });

    test('master switch without a time stays sold out', () {
      final s = stockStatus(dish('a', soldOut: true), null, now);
      expect(s.soldOut, isTrue);
      expect(s.until, isNull);
      expect(s.byMaster, isTrue);
      expect(s.scheduled, isFalse);
      expect(s.branchOnly, isFalse);
    });

    test('a future back-at time is scheduled', () {
      final back = now.add(const Duration(hours: 2));
      final s = stockStatus(dish('a', soldOut: true, until: back), null, now);
      expect(s.soldOut, isTrue);
      expect(s.scheduled, isTrue);
      expect(s.until, equals(back));
    });

    test('an expired back-at time means available again', () {
      final past = now.subtract(const Duration(minutes: 1));
      final s = stockStatus(dish('a', soldOut: true, until: past), null, now);
      expect(s.soldOut, isFalse);
    });

    test('a back-at time exactly now is already available', () {
      final s = stockStatus(dish('a', soldOut: true, until: now), null, now);
      expect(s.soldOut, isFalse);
    });

    test('branch override alone is branch only', () {
      final s = stockStatus(
        dish('a'),
        branchSetting('a', soldOut: true),
        now,
      );
      expect(s.soldOut, isTrue);
      expect(s.byBranch, isTrue);
      expect(s.byMaster, isFalse);
      expect(s.branchOnly, isTrue);
    });

    test('a branch row that is not sold out changes nothing', () {
      final s = stockStatus(dish('a'), branchSetting('a'), now);
      expect(s.soldOut, isFalse);
    });

    test('an expired branch time means available', () {
      final s = stockStatus(
        dish('a'),
        branchSetting(
          'a',
          soldOut: true,
          until: now.subtract(const Duration(hours: 1)),
        ),
        now,
      );
      expect(s.soldOut, isFalse);
    });

    test('both switches on: manual one wins over a time', () {
      final s = stockStatus(
        dish('a', soldOut: true),
        branchSetting(
          'a',
          soldOut: true,
          until: now.add(const Duration(hours: 1)),
        ),
        now,
      );
      expect(s.soldOut, isTrue);
      expect(s.until, isNull);
      expect(s.byMaster, isTrue);
      expect(s.byBranch, isTrue);
      expect(s.branchOnly, isFalse);
    });

    test('both switches with times: the later one counts', () {
      final early = now.add(const Duration(hours: 1));
      final late = now.add(const Duration(hours: 5));
      final s = stockStatus(
        dish('a', soldOut: true, until: early),
        branchSetting('a', soldOut: true, until: late),
        now,
      );
      expect(s.until, equals(late));
      final t = stockStatus(
        dish('a', soldOut: true, until: late),
        branchSetting('a', soldOut: true, until: early),
        now,
      );
      expect(t.until, equals(late));
    });

    test('master expired but branch active leaves branch only', () {
      final s = stockStatus(
        dish('a', soldOut: true, until: now.subtract(const Duration(hours: 1))),
        branchSetting('a', soldOut: true),
        now,
      );
      expect(s.branchOnly, isTrue);
      expect(s.until, isNull);
    });

    test('all branches view ignores branch rows because none are passed', () {
      final s = stockStatus(dish('a'), null, now);
      expect(s.soldOut, isFalse);
    });

    test('statuses compare by value', () {
      expect(
        stockStatus(dish('a', soldOut: true), null, now),
        equals(const StockStatus(soldOut: true, byMaster: true)),
      );
      expect(StockStatus.available, equals(const StockStatus(soldOut: false)));
    });
  });

  group('buildStockView', () {
    test('skips deleted dishes and counts hidden ones', () {
      final view = buildStockView(
        [
          dish('a'),
          dish('b', active: false),
          dish('c', deleted: DateTime(2026, 11, 1)),
          dish('d', active: false),
        ],
        settings: const {},
        now: now,
      );
      expect(view.entries.map((e) => e.item.id).toList(), equals(['a']));
      expect(view.hiddenCount, equals(2));
    });

    test('uses the branch rows it is given', () {
      final view = buildStockView(
        [dish('a'), dish('b')],
        settings: {'b': branchSetting('b', soldOut: true)},
        now: now,
      );
      expect(view.entries[0].status.soldOut, isFalse);
      expect(view.entries[1].status.branchOnly, isTrue);
    });

    test('an optimistic override replaces the stored status', () {
      final view = buildStockView(
        [dish('a')],
        settings: const {},
        now: now,
        overrides: {
          'a': optimisticSoldOut(until: null, branchWrite: false),
        },
      );
      expect(view.entries.single.status.soldOut, isTrue);
      expect(view.entries.single.status.byMaster, isTrue);
    });

    test('empty input gives an empty view', () {
      final view = buildStockView(const [], settings: const {}, now: now);
      expect(view.entries, isEmpty);
      expect(view.hiddenCount, equals(0));
    });
  });

  group('countStock', () {
    test('splits available, sold out and scheduled', () {
      final view = buildStockView(
        [
          dish('a'),
          dish('b'),
          dish('c', soldOut: true),
          dish('d', soldOut: true, until: now.add(const Duration(hours: 1))),
          dish('e', soldOut: true, until: now.subtract(const Duration(hours: 1))),
        ],
        settings: const {},
        now: now,
      );
      final counts = countStock(view.entries);
      expect(counts.available, equals(3));
      expect(counts.soldOut, equals(1));
      expect(counts.scheduled, equals(1));
      expect(counts.total, equals(5));
      expect(counts.unavailable, equals(2));
    });

    test('empty list counts zero', () {
      final counts = countStock(const []);
      expect(counts.total, equals(0));
      expect(counts.unavailable, equals(0));
    });
  });

  group('filterStock', () {
    final entries = buildStockView(
      [
        dish('a', en: 'Chicken Biryani', bn: 'চিকেন বিরিয়ানি', sku: 'BR-1', category: 'c1'),
        dish('b', en: 'Beef Tehari', bn: 'বিফ তেহারি', category: 'c1'),
        dish('c', en: 'Mango Lassi', bn: 'আম লাচ্ছি', category: 'c2'),
      ],
      settings: const {},
      now: now,
    ).entries;

    test('no filter keeps everything', () {
      expect(filterStock(entries), hasLength(3));
    });

    test('matches English words ignoring case and spaces', () {
      final found = filterStock(entries, query: '  BIRYANI ');
      expect(found.map((e) => e.item.id).toList(), equals(['a']));
    });

    test('matches Bangla words', () {
      final found = filterStock(entries, query: 'তেহারি');
      expect(found.map((e) => e.item.id).toList(), equals(['b']));
    });

    test('matches the SKU', () {
      expect(filterStock(entries, query: 'br-1').single.item.id, equals('a'));
    });

    test('narrows by category ids', () {
      final found = filterStock(entries, categoryIds: {'c2'});
      expect(found.single.item.id, equals('c'));
    });

    test('category and query combine', () {
      expect(filterStock(entries, query: 'mango', categoryIds: {'c1'}), isEmpty);
    });

    test('an empty category set matches nothing', () {
      expect(filterStock(entries, categoryIds: <String>{}), isEmpty);
    });
  });

  group('groupStock', () {
    final categories = [
      category('drinks', en: 'Drinks', order: 2),
      category('mains', en: 'Mains', order: 1),
      category('rice', parent: 'mains', en: 'Rice', order: 1),
    ];

    List<StockEntry> entriesOf(List<MenuItem> items) =>
        buildStockView(items, settings: const {}, now: now).entries;

    test('follows menu order with subcategories after their parent', () {
      final groups = groupStock(
        entriesOf([
          dish('d1', category: 'drinks'),
          dish('r1', category: 'rice'),
          dish('m1', category: 'mains'),
        ]),
        categories,
      );
      expect(
        groups.map((g) => g.name).toList(),
        equals(['Mains', 'Mains / Rice', 'Drinks']),
      );
    });

    test('leaves out empty categories', () {
      final groups = groupStock(entriesOf([dish('m1', category: 'mains')]), categories);
      expect(groups.map((g) => g.id).toList(), equals(['mains']));
    });

    test('dishes inside a group follow sort order then name', () {
      final groups = groupStock(
        entriesOf([
          dish('z', category: 'mains', en: 'Zebra', order: 1),
          dish('b', category: 'mains', en: 'banana', order: 0),
          dish('a', category: 'mains', en: 'Apple', order: 0),
        ]),
        categories,
      );
      expect(
        groups.single.entries.map((e) => e.item.id).toList(),
        equals(['a', 'b', 'z']),
      );
    });

    test('a dish whose category is gone goes to Uncategorised last', () {
      final groups = groupStock(
        entriesOf([
          dish('x', category: 'gone'),
          dish('d1', category: 'drinks'),
        ]),
        categories,
      );
      expect(groups.map((g) => g.id).toList(), equals(['drinks', uncategorisedGroupId]));
      expect(groups.last.name, equals('Uncategorised'));
    });

    test('group counts', () {
      final groups = groupStock(
        entriesOf([
          dish('a', category: 'mains', soldOut: true),
          dish('b', category: 'mains'),
          dish('c', category: 'mains'),
        ]),
        categories,
      );
      expect(groups.single.soldOutCount, equals(1));
      expect(groups.single.availableCount, equals(2));
    });

    test('no entries gives no groups', () {
      expect(groupStock(const [], categories), isEmpty);
    });
  });

  group('stockCaption', () {
    test('available dish', () {
      expect(stockCaption(StockStatus.available, now), equals('Available'));
    });

    test('manual sold out', () {
      expect(
        stockCaption(const StockStatus(soldOut: true, byMaster: true), now),
        equals('Until switched back on'),
      );
    });

    test('back later today', () {
      final status = StockStatus(
        soldOut: true,
        byMaster: true,
        until: DateTime(2026, 11, 21, 15, 30),
      );
      expect(stockCaption(status, now), equals('Back at 3:30 PM'));
    });

    test('back tomorrow', () {
      final status = StockStatus(
        soldOut: true,
        byMaster: true,
        until: DateTime(2026, 11, 22, 10, 0),
      );
      expect(stockCaption(status, now), equals('Back tomorrow at 10:00 AM'));
    });

    test('branch view says where it applies', () {
      expect(
        stockCaption(
          const StockStatus(soldOut: true, byBranch: true),
          now,
          showScope: true,
        ),
        equals('Until switched back on  -  This branch only'),
      );
      expect(
        stockCaption(
          const StockStatus(soldOut: true, byMaster: true),
          now,
          showScope: true,
        ),
        equals('Until switched back on  -  All branches'),
      );
    });

    test('scope is left out when not asked for', () {
      expect(
        stockCaption(const StockStatus(soldOut: true, byBranch: true), now),
        equals('Until switched back on'),
      );
    });
  });

  group('restock and bulk helpers', () {
    final entries = buildStockView(
      [
        dish('master', soldOut: true),
        dish('branch'),
        dish('both', soldOut: true),
        dish('free'),
      ],
      settings: {
        'branch': branchSetting('branch', soldOut: true),
        'both': branchSetting('both', soldOut: true),
      },
      now: now,
    ).entries;

    test('planRestock clears only the switches that are on', () {
      final plan = planRestock(entries);
      expect(plan.masterIds, equals(['master', 'both']));
      expect(plan.branchIds, equals(['branch', 'both']));
      expect(plan.isEmpty, isFalse);
    });

    test('planRestock of available dishes is empty', () {
      expect(planRestock(entries.where((e) => !e.status.soldOut)).isEmpty, isTrue);
    });

    test('availableIds and soldOutIds partition the list', () {
      expect(availableIds(entries), equals(['free']));
      expect(soldOutIds(entries), equals(['master', 'branch', 'both']));
    });

    test('optimisticSoldOut marks the right scope', () {
      final branch = optimisticSoldOut(until: null, branchWrite: true);
      expect(branch.branchOnly, isTrue);
      final all = optimisticSoldOut(until: now, branchWrite: false);
      expect(all.byMaster, isTrue);
      expect(all.byBranch, isFalse);
      expect(all.until, equals(now));
    });

    test('dishCount wording', () {
      expect(dishCount(0), equals('0 dishes'));
      expect(dishCount(1), equals('1 dish'));
      expect(dishCount(12), equals('12 dishes'));
    });
  });
}
