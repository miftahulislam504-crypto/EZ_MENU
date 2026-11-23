import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/branch_override_logic.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

BranchItemSetting s(
  String branch, {
  bool offered = true,
  double? price,
  double? discount,
  bool soldOut = false,
}) => BranchItemSetting(
  branchId: branch,
  itemId: 'item',
  isOffered: offered,
  price: price,
  discountPrice: discount,
  isSoldOut: soldOut,
);

void main() {
  group('branchPriceView', () {
    test('no override uses the dish prices', () {
      final v = branchPriceView(basePrice: 200, baseDiscountPrice: 150, setting: null);
      expect(v.price, equals(200));
      expect(v.payable, equals(150));
      expect(v.isOverride, isFalse);
    });

    test('a branch price replaces both prices', () {
      final v = branchPriceView(basePrice: 200, baseDiscountPrice: 150, setting: s('a', price: 300));
      expect(v.price, equals(300));
      expect(v.discountPrice, isNull);
      expect(v.payable, equals(300));
      expect(v.isOverride, isTrue);
    });

    test('a branch discount applies to the branch price', () {
      final v = branchPriceView(basePrice: 200, setting: s('a', price: 300, discount: 250));
      expect(v.payable, equals(250));
    });

    test('an override without price keeps the dish prices', () {
      final v = branchPriceView(basePrice: 200, baseDiscountPrice: 150, setting: s('a', soldOut: true));
      expect(v.price, equals(200));
      expect(v.payable, equals(150));
      expect(v.isOverride, isFalse);
    });
  });

  group('hasOverride', () {
    test('default entry is not an override', () {
      expect(hasOverride(s('a')), isFalse);
    });

    test('hidden, priced or sold out is an override', () {
      expect(hasOverride(s('a', offered: false)), isTrue);
      expect(hasOverride(s('a', price: 10)), isTrue);
      expect(hasOverride(s('a', soldOut: true)), isTrue);
    });
  });

  group('upsertSetting', () {
    test('adds an entry', () {
      final result = upsertSetting([], s('a', price: 10));
      expect(result.length, equals(1));
    });

    test('replaces an entry and keeps the order', () {
      final result = upsertSetting([s('a', price: 10), s('b', price: 20)], s('a', price: 99));
      expect(result.map((e) => e.branchId).toList(), equals(['a', 'b']));
      expect(result.first.price, equals(99));
    });

    test('removes an entry that no longer overrides anything', () {
      final result = upsertSetting([s('a', price: 10), s('b', offered: false)], s('a'));
      expect(result.map((e) => e.branchId).toList(), equals(['b']));
    });

    test('a blank entry for a new branch is not added', () {
      expect(upsertSetting([], s('a')), isEmpty);
    });
  });

  group('removeSetting and blankSetting', () {
    test('removeSetting drops one branch', () {
      expect(removeSetting([s('a', price: 1), s('b', price: 2)], 'a').length, equals(1));
    });

    test('blankSetting has no override', () {
      expect(hasOverride(blankSetting('a', 'i')), isFalse);
    });

    test('settingOf finds by branch', () {
      expect(settingOf([s('a', price: 1)], 'a'), isNotNull);
      expect(settingOf([s('a', price: 1)], 'b'), isNull);
    });
  });

  group('withItemId and removedBranchIds', () {
    test('withItemId rewrites the dish id and keeps values', () {
      final result = withItemId([s('a', price: 10, discount: 5, soldOut: true, offered: false)], 'new');
      expect(result.first.itemId, equals('new'));
      expect(result.first.price, equals(10));
      expect(result.first.discountPrice, equals(5));
      expect(result.first.isSoldOut, isTrue);
      expect(result.first.isOffered, isFalse);
    });

    test('removedBranchIds lists branches that lost their override', () {
      final before = [s('a', price: 1), s('b', price: 2)];
      final after = [s('b', price: 2)];
      expect(removedBranchIds(before, after), equals(['a']));
      expect(removedBranchIds(before, before), isEmpty);
      expect(removedBranchIds(const [], after), isEmpty);
    });
  });

  group('validateBranchSettings', () {
    test('valid settings', () {
      expect(validateBranchSettings([s('a', price: 100, discount: 90), s('b', offered: false)], basePrice: 100), isEmpty);
    });

    test('negative price', () {
      final errors = validateBranchSettings([s('a', price: -1)], basePrice: 100, branchNames: {'a': 'Gulshan'});
      expect(errors, equals(['Gulshan: the branch price cannot be negative.']));
    });

    test('discount without price', () {
      final errors = validateBranchSettings([s('a', discount: 10)], basePrice: 100);
      expect(errors, equals(['A branch: a branch discount needs a branch price.']));
    });

    test('discount must be lower than the price', () {
      expect(validateBranchSettings([s('a', price: 100, discount: 100)], basePrice: 100).length, equals(1));
      expect(validateBranchSettings([s('a', price: 100, discount: 120)], basePrice: 100).length, equals(1));
    });

    test('a zero branch price is allowed', () {
      expect(validateBranchSettings([s('a', price: 0)], basePrice: 100), isEmpty);
    });

    test('duplicate branch ids', () {
      final errors = validateBranchSettings([s('a', price: 1), s('a', price: 2)], basePrice: 100, branchNames: {'a': 'Dhanmondi'});
      expect(errors, equals(['Dhanmondi has more than one override.']));
    });
  });
}
