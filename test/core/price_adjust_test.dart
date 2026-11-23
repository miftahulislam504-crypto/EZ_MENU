import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/core/logic/price_adjust.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

MenuItem dish(String id, double price, {double? discount, String name = 'Dish'}) => MenuItem(
  id: id,
  businessId: 'b',
  categoryId: 'c',
  nameEn: '$name $id',
  price: price,
  discountPrice: discount,
);

PriceRow rowOf(List<PriceRow> rows, String id) => rows.firstWhere((r) => r.itemId == id);

void main() {
  group('roundHalfUp', () {
    test('rounds halves up', () {
      expect(roundHalfUp(2.5, 0), equals(3));
      expect(roundHalfUp(0.5, 0), equals(1));
      expect(roundHalfUp(1.5, 0), equals(2));
      expect(roundHalfUp(2.345, 2), equals(2.35));
    });

    test('floating point halves behave like decimal numbers', () {
      expect(roundHalfUp(1.005, 2), equals(1.01));
      expect(roundHalfUp(275.005, 2), equals(275.01));
    });

    test('plain values are unchanged', () {
      expect(roundHalfUp(250, 2), equals(250));
      expect(roundHalfUp(99.99, 2), equals(99.99));
    });
  });

  group('adjustAmount', () {
    test('percent increase', () {
      expect(adjustAmount(200, PriceChangeMode.percentIncrease, 10), equals(220));
      expect(adjustAmount(199, PriceChangeMode.percentIncrease, 10), equals(218.9));
    });

    test('percent decrease', () {
      expect(adjustAmount(200, PriceChangeMode.percentDecrease, 25), equals(150));
    });

    test('fixed increase and decrease', () {
      expect(adjustAmount(120, PriceChangeMode.fixedIncrease, 15), equals(135));
      expect(adjustAmount(120, PriceChangeMode.fixedDecrease, 20), equals(100));
    });

    test('set exact ignores the old amount', () {
      expect(adjustAmount(120, PriceChangeMode.setExact, 99), equals(99));
    });

    test('never below zero', () {
      expect(adjustAmount(50, PriceChangeMode.fixedDecrease, 80), equals(0));
      expect(adjustAmount(50, PriceChangeMode.percentDecrease, 150), equals(0));
    });

    test('round to a whole number', () {
      expect(adjustAmount(199, PriceChangeMode.percentIncrease, 10, roundWhole: true), equals(219));
      expect(adjustAmount(105, PriceChangeMode.percentIncrease, 10, roundWhole: true), equals(116));
      expect(adjustAmount(10, PriceChangeMode.percentIncrease, 5, roundWhole: true), equals(11));
    });

    test('two decimals by default', () {
      expect(adjustAmount(99.99, PriceChangeMode.percentIncrease, 3), equals(102.99));
      expect(adjustAmount(33.33, PriceChangeMode.percentDecrease, 33.3), equals(22.23));
    });

    test('zero change keeps the amount', () {
      expect(adjustAmount(150, PriceChangeMode.percentIncrease, 0), equals(150));
      expect(adjustAmount(150, PriceChangeMode.fixedDecrease, 0), equals(150));
    });
  });

  group('parseChangeValue', () {
    test('plain numbers', () {
      expect(parseChangeValue('10'), equals(10));
      expect(parseChangeValue('2.5'), equals(2.5));
    });

    test('percent and currency symbols', () {
      expect(parseChangeValue('10%'), equals(10));
      expect(parseChangeValue(' 7.5 % '), equals(7.5));
      expect(parseChangeValue('tk 50'), equals(50));
      expect(parseChangeValue('50 Tk'), equals(50));
    });

    test('Bangla digits', () {
      expect(parseChangeValue('১০'), equals(10));
      expect(parseChangeValue('২.৫%'), equals(2.5));
    });

    test('empty and invalid', () {
      expect(parseChangeValue(null), isNull);
      expect(parseChangeValue(''), isNull);
      expect(parseChangeValue('ten'), isNull);
      expect(parseChangeValue('-5'), isNull);
      expect(parseChangeValue('1e3'), isNull);
    });
  });

  group('PriceChange.problem and notice', () {
    test('valid change', () {
      expect(const PriceChange(mode: PriceChangeMode.percentIncrease, value: 10).problem, isNull);
    });

    test('negative value is refused', () {
      expect(const PriceChange(mode: PriceChangeMode.fixedIncrease, value: -1).problem, isNotNull);
    });

    test('set a branch discount only is refused', () {
      const change = PriceChange(
        mode: PriceChangeMode.setExact,
        value: 50,
        target: PriceTarget.discount,
        branchId: 'br',
      );
      expect(change.problem, equals('Set a branch price instead of a branch discount only.'));
    });

    test('set a base discount only is allowed', () {
      const change = PriceChange(mode: PriceChangeMode.setExact, value: 50, target: PriceTarget.discount);
      expect(change.problem, isNull);
    });

    test('notices', () {
      expect(const PriceChange(mode: PriceChangeMode.percentDecrease, value: 120).notice, isNotNull);
      expect(const PriceChange(mode: PriceChangeMode.percentDecrease, value: 20).notice, isNull);
      expect(
        const PriceChange(mode: PriceChangeMode.setExact, value: 90, target: PriceTarget.both).notice,
        isNotNull,
      );
    });

    test('database names', () {
      expect(PriceChangeMode.percentIncrease.sql, equals('percent_increase'));
      expect(PriceChangeMode.setExact.sql, equals('set'));
      expect(PriceTarget.both.sql, equals('both'));
    });
  });

  group('previewPriceChange: base prices', () {
    test('price only leaves the discount alone while it stays lower', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 10),
      );
      expect(rows.single.newPrice, equals(220));
      expect(rows.single.newDiscount, equals(150));
      expect(rows.single.warnings, isEmpty);
    });

    test('discount only', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150), dish('b', 100)],
        change: const PriceChange(
          mode: PriceChangeMode.percentDecrease,
          value: 20,
          target: PriceTarget.discount,
        ),
      );
      expect(rowOf(rows, 'a').newPrice, equals(200));
      expect(rowOf(rows, 'a').newDiscount, equals(120));
      // A dish without a discount stays as it is.
      expect(rowOf(rows, 'b').changed, isFalse);
    });

    test('both targets', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 100)],
        change: const PriceChange(
          mode: PriceChangeMode.percentIncrease,
          value: 10,
          target: PriceTarget.both,
        ),
      );
      expect(rows.single.newPrice, equals(220));
      expect(rows.single.newDiscount, equals(110));
    });

    test('a discount that is no longer lower than the price is dropped', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: const PriceChange(mode: PriceChangeMode.fixedDecrease, value: 60),
      );
      expect(rows.single.newPrice, equals(140));
      expect(rows.single.newDiscount, isNull);
      expect(rows.single.warnings, contains(PriceWarning.discountDropped));
    });

    test('set both makes the discount equal to the price, so it is dropped', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: const PriceChange(
          mode: PriceChangeMode.setExact,
          value: 99,
          target: PriceTarget.both,
        ),
      );
      expect(rows.single.newPrice, equals(99));
      expect(rows.single.newDiscount, isNull);
    });

    test('a price brought to zero is flagged', () {
      final rows = previewPriceChange(
        items: [dish('a', 40)],
        change: const PriceChange(mode: PriceChangeMode.fixedDecrease, value: 100),
      );
      expect(rows.single.newPrice, equals(0));
      expect(rows.single.warnings, contains(PriceWarning.becomesFree));
    });

    test('zero change leaves every dish unchanged', () {
      final rows = previewPriceChange(
        items: [dish('a', 200), dish('b', 90, discount: 80)],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 0),
      );
      expect(rows.every((r) => !r.changed), isTrue);
      expect(idsToApply(rows), isEmpty);
    });

    test('round whole taka', () {
      final rows = previewPriceChange(
        items: [dish('a', 199)],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 10, roundWhole: true),
      );
      expect(rows.single.newPrice, equals(219));
    });

    test('empty selection', () {
      final rows = previewPriceChange(
        items: const [],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 10),
      );
      expect(rows, isEmpty);
      final summary = summarizePriceChange(rows);
      expect(summary.total, equals(0));
      expect(summary.changed, equals(0));
    });

    test('payable amounts', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 10),
      );
      expect(rows.single.oldPayable, equals(150));
      expect(rows.single.newPayable, equals(150));
    });
  });

  group('previewPriceChange: branch prices', () {
    const change = PriceChange(
      mode: PriceChangeMode.percentIncrease,
      value: 10,
      branchId: 'br',
    );

    test('a dish without an override starts from the dish price', () {
      final rows = previewPriceChange(items: [dish('a', 200, discount: 150)], change: change);
      final row = rows.single;
      expect(row.oldPrice, equals(200));
      expect(row.newPrice, equals(220));
      // The branch gets its own price and the discount is kept (target price).
      expect(row.newDiscount, equals(150));
      expect(row.warnings, contains(PriceWarning.createsBranchPrice));
    });

    test('a dish with an override starts from the override', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: change,
        branchSettings: const {
          'a': BranchItemSetting(branchId: 'br', itemId: 'a', price: 300, discountPrice: 250),
        },
      );
      final row = rows.single;
      expect(row.oldPrice, equals(300));
      expect(row.oldDiscount, equals(250));
      expect(row.newPrice, equals(330));
      expect(row.newDiscount, equals(250));
      expect(row.warnings, isNot(contains(PriceWarning.createsBranchPrice)));
    });

    test('an override without a price falls back to the dish price', () {
      final rows = previewPriceChange(
        items: [dish('a', 200)],
        change: change,
        branchSettings: const {'a': BranchItemSetting(branchId: 'br', itemId: 'a', isOffered: false)},
      );
      expect(rows.single.oldPrice, equals(200));
      expect(rows.single.newPrice, equals(220));
    });

    test('the dish discount is ignored when the branch has its own price', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150)],
        change: const PriceChange(
          mode: PriceChangeMode.percentDecrease,
          value: 10,
          target: PriceTarget.discount,
          branchId: 'br',
        ),
        branchSettings: const {'a': BranchItemSetting(branchId: 'br', itemId: 'a', price: 300)},
      );
      // The branch price has no discount, so there is nothing to change.
      expect(rows.single.oldDiscount, isNull);
      expect(rows.single.changed, isFalse);
    });

    test('unchanged dishes are not sent', () {
      final rows = previewPriceChange(
        items: [dish('a', 200), dish('b', 100)],
        change: const PriceChange(
          mode: PriceChangeMode.percentDecrease,
          value: 50,
          target: PriceTarget.discount,
          branchId: 'br',
        ),
      );
      expect(idsToApply(rows), isEmpty);
    });
  });

  group('summarizePriceChange', () {
    test('counts and total effect', () {
      final rows = previewPriceChange(
        items: [dish('a', 100), dish('b', 200, discount: 190), dish('c', 50)],
        change: const PriceChange(mode: PriceChangeMode.fixedIncrease, value: 10),
      );
      final summary = summarizePriceChange(rows);
      expect(summary.total, equals(3));
      expect(summary.changed, equals(3));
      expect(summary.unchanged, equals(0));
      expect(summary.totalDelta, equals(30));
      expect(summary.discountsDropped, equals(0));
    });

    test('counts dropped discounts and free dishes', () {
      final rows = previewPriceChange(
        items: [dish('a', 200, discount: 150), dish('b', 30), dish('c', 500)],
        change: const PriceChange(mode: PriceChangeMode.fixedDecrease, value: 60),
      );
      final summary = summarizePriceChange(rows);
      expect(summary.discountsDropped, equals(1));
      expect(summary.becameFree, equals(1));
      expect(summary.totalDelta, equals(-150));
    });

    test('unchanged dishes are counted apart', () {
      final rows = previewPriceChange(
        items: [dish('a', 100), dish('b', 100)],
        change: const PriceChange(mode: PriceChangeMode.setExact, value: 100),
      );
      final summary = summarizePriceChange(rows);
      expect(summary.changed, equals(0));
      expect(summary.unchanged, equals(2));
    });

    test('Bangla dish names are kept', () {
      final item = MenuItem(id: 'x', businessId: 'b', categoryId: 'c', nameBn: 'বার্গার', price: 100);
      final rows = previewPriceChange(
        items: [item],
        change: const PriceChange(mode: PriceChangeMode.percentIncrease, value: 5),
      );
      expect(rows.single.name, equals('বার্গার'));
      expect(rows.single.newPrice, equals(105));
    });
  });
}
