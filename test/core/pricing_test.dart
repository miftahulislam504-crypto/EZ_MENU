import 'package:ez_menu/core/logic/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

PricedGroup _sizeGroup({double? largeDiscount}) => PricedGroup(
  id: 'size',
  mode: OptionPriceMode.absolute,
  isRequired: true,
  minSelect: 1,
  options: [
    const PricedOption(id: 'regular', price: 350),
    PricedOption(id: 'large', price: 450, discountPrice: largeDiscount),
  ],
);

const _extras = PricedGroup(
  id: 'extras',
  multiple: true,
  maxSelect: 3,
  options: [
    PricedOption(id: 'cheese', price: 40),
    PricedOption(id: 'egg', price: 20),
    PricedOption(id: 'bacon', price: 80),
    PricedOption(id: 'sauce', price: 10),
  ],
);

void main() {
  group('computeItemPrice', () {
    test('plain item without options', () {
      final r = computeItemPrice(
        basePrice: 120,
        groups: const [],
        selections: const {},
      );
      expect(r.unitPrice, 120);
      expect(r.unitOriginalPrice, 120);
      expect(r.hasDiscount, isFalse);
      expect(r.isValid, isTrue);
    });

    test(
      'item discount applies when no absolute option replaces the price',
      () {
        final r = computeItemPrice(
          basePrice: 350,
          baseDiscountPrice: 300,
          groups: const [_extras],
          selections: const {},
        );
        expect(r.unitPrice, 300);
        expect(r.unitOriginalPrice, 350);
        expect(r.hasDiscount, isTrue);
      },
    );

    test('a required size must be chosen but the price is still shown', () {
      final r = computeItemPrice(
        basePrice: 350,
        groups: [_sizeGroup(), _extras],
        selections: const {},
      );
      expect(r.unitPrice, 350);
      expect(r.isValid, isFalse);
      expect(r.issues.single.groupId, 'size');
      expect(r.issues.single.problem, SelectionProblem.required);
    });

    test('absolute option replaces the item price', () {
      final r = computeItemPrice(
        basePrice: 350,
        groups: [_sizeGroup(), _extras],
        selections: {
          'size': {'large'},
        },
      );
      expect(r.unitPrice, 450);
      expect(r.isValid, isTrue);
    });

    test('add-ons are added on top of the size', () {
      final r = computeItemPrice(
        basePrice: 350,
        groups: [_sizeGroup(), _extras],
        selections: {
          'size': {'large'},
          'extras': {'cheese', 'bacon'},
        },
      );
      expect(r.unitPrice, 570);
    });

    test(
      'item discount is replaced by an absolute option, option discount wins',
      () {
        final replaced = computeItemPrice(
          basePrice: 350,
          baseDiscountPrice: 300,
          groups: [_sizeGroup()],
          selections: {
            'size': {'large'},
          },
        );
        expect(replaced.unitPrice, 450);
        expect(replaced.hasDiscount, isFalse);

        final discounted = computeItemPrice(
          basePrice: 350,
          baseDiscountPrice: 300,
          groups: [_sizeGroup(largeDiscount: 400)],
          selections: {
            'size': {'large'},
          },
        );
        expect(discounted.unitPrice, 400);
        expect(discounted.unitOriginalPrice, 450);
        expect(discounted.hasDiscount, isTrue);
      },
    );

    test('too many add-ons is reported', () {
      final r = computeItemPrice(
        basePrice: 350,
        groups: [_extras],
        selections: {
          'extras': {'cheese', 'egg', 'bacon', 'sauce'},
        },
      );
      expect(r.issues.single.problem, SelectionProblem.tooMany);
      expect(r.unitPrice, 500);
    });

    test('two choices in a single-choice group is reported', () {
      final r = computeItemPrice(
        basePrice: 350,
        groups: [_sizeGroup()],
        selections: {
          'size': {'regular', 'large'},
        },
      );
      expect(
        r.issues.map((i) => i.problem),
        contains(SelectionProblem.tooMany),
      );
    });

    test('minimum selection on an optional group', () {
      const g = PricedGroup(
        id: 'sauces',
        multiple: true,
        minSelect: 2,
        options: [
          PricedOption(id: 'a', price: 0),
          PricedOption(id: 'b', price: 0),
          PricedOption(id: 'c', price: 0),
        ],
      );
      final none = computeItemPrice(
        basePrice: 100,
        groups: const [g],
        selections: const {},
      );
      expect(none.isValid, isFalse);
      final one = computeItemPrice(
        basePrice: 100,
        groups: const [g],
        selections: {
          'sauces': {'a'},
        },
      );
      expect(one.issues.single.problem, SelectionProblem.tooFew);
      final two = computeItemPrice(
        basePrice: 100,
        groups: const [g],
        selections: {
          'sauces': {'a', 'b'},
        },
      );
      expect(two.isValid, isTrue);
    });

    test('unavailable options are reported', () {
      const g = PricedGroup(
        id: 'extras',
        multiple: true,
        options: [PricedOption(id: 'cheese', price: 40, isAvailable: false)],
      );
      final r = computeItemPrice(
        basePrice: 100,
        groups: const [g],
        selections: {
          'extras': {'cheese'},
        },
      );
      expect(r.issues.single.problem, SelectionProblem.unavailable);
    });

    test('unknown option ids are ignored', () {
      final r = computeItemPrice(
        basePrice: 100,
        groups: const [_extras],
        selections: {
          'extras': {'ghost'},
        },
      );
      expect(r.unitPrice, 100);
      expect(r.isValid, isTrue);
    });

    test('line totals round to two decimals', () {
      final r = computeItemPrice(
        basePrice: 99.99,
        groups: const [],
        selections: const {},
      );
      expect(r.lineTotal(3), 299.97);
      expect(r.lineOriginalTotal(2), 199.98);
    });
  });

  group('defaultSelections', () {
    test('keeps defaults and never more than one in single groups', () {
      final result = defaultSelections(
        [_sizeGroup(), _extras],
        {'regular', 'large', 'cheese'},
      );
      expect(result['size']!.length, 1);
      expect(result['extras'], {'cheese'});
    });
    test('skips unavailable defaults and empty groups', () {
      const g = PricedGroup(
        id: 'g',
        options: [PricedOption(id: 'a', price: 0, isAvailable: false)],
      );
      expect(defaultSelections(const [g], {'a'}), isEmpty);
    });
  });
}
