import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/menu_models.dart';
import 'package:ez_menu/features/menu/option_groups_logic.dart';

IdGenerator counter() {
  var n = 0;
  return () => 'id${++n}';
}

ItemOption opt(String id, {String? en = 'A', String? bn, double price = 0, double? discount, bool def = false, bool available = true}) =>
    ItemOption(id: id, nameEn: en, nameBn: bn, price: price, discountPrice: discount, isDefault: def, isAvailable: available);

OptionGroup og({
  String id = 'g',
  String? en = 'Size',
  String? bn,
  String type = 'single',
  String mode = 'additional',
  bool required = false,
  int min = 0,
  int? max = 1,
  List<ItemOption>? options,
}) => OptionGroup(
  id: id,
  nameEn: en,
  nameBn: bn,
  selectType: type,
  priceMode: mode,
  isRequired: required,
  minSelect: min,
  maxSelect: max,
  options: options ?? [opt('o1')],
);

void main() {
  group('presetGroup', () {
    test('size is a required absolute single choice priced at the dish price', () {
      final g = presetGroup(OptionPreset.size, basePrice: 250, newId: counter());
      expect(g.nameEn, equals('Size'));
      expect(g.nameBn, equals('সাইজ'));
      expect(g.isSingle, isTrue);
      expect(g.isAbsolute, isTrue);
      expect(g.isRequired, isTrue);
      expect(g.minSelect, equals(1));
      expect(g.maxSelect, equals(1));
      expect(g.options.map((o) => o.nameEn).toList(), equals(['Small', 'Medium', 'Large']));
      expect(g.options.every((o) => o.price == 250), isTrue);
      expect(g.options.where((o) => o.isDefault).length, equals(1));
      expect(validateOptionGroups([g]), isEmpty);
    });

    test('extras is a multiple optional additional group', () {
      final g = presetGroup(OptionPreset.extras, basePrice: 0, newId: counter());
      expect(g.isSingle, isFalse);
      expect(g.isRequired, isFalse);
      expect(g.maxSelect, isNull);
      expect(g.options.length, equals(3));
      expect(validateOptionGroups([g]), isEmpty);
    });

    test('every preset is valid and has unique ids', () {
      final newId = counter();
      final ids = <String>{};
      for (final preset in OptionPreset.values) {
        final g = presetGroup(preset, basePrice: 100, newId: newId);
        ids.add(g.id);
        for (final o in g.options) {
          ids.add(o.id);
        }
        if (preset != OptionPreset.blank) {
          expect(validateOptionGroups([g]), isEmpty);
        }
      }
      final total = OptionPreset.values.fold<int>(
        0,
        (sum, p) => sum + presetGroup(p, basePrice: 1, newId: counter()).options.length + 1,
      );
      expect(ids.length, equals(total));
    });

    test('blank has no name and one empty option', () {
      final g = presetGroup(OptionPreset.blank, basePrice: 0, newId: counter());
      expect(g.options.length, equals(1));
      expect(validateOptionGroups([g]).length, greaterThan(0));
    });

    test('every preset has a label', () {
      for (final p in OptionPreset.values) {
        expect(optionPresetLabels.containsKey(p), isTrue);
      }
    });
  });

  group('normalizeGroup', () {
    test('single required: min 1 and max 1', () {
      final g = normalizeGroup(og(required: true, min: 0, max: null));
      expect(g.minSelect, equals(1));
      expect(g.maxSelect, equals(1));
    });

    test('single optional: min 0 and max 1', () {
      final g = normalizeGroup(og(required: false, min: 3, max: 5));
      expect(g.minSelect, equals(0));
      expect(g.maxSelect, equals(1));
    });

    test('single keeps only the first default', () {
      final g = normalizeGroup(og(options: [opt('a', def: true), opt('b', def: true), opt('c')]));
      expect(g.options.where((o) => o.isDefault).map((o) => o.id).toList(), equals(['a']));
    });

    test('multiple optional resets the minimum to zero', () {
      final g = normalizeGroup(og(type: 'multiple', required: false, min: 2, max: null));
      expect(g.minSelect, equals(0));
      expect(g.maxSelect, isNull);
    });

    test('multiple required needs at least one', () {
      final g = normalizeGroup(og(type: 'multiple', required: true, min: 0, max: null));
      expect(g.minSelect, equals(1));
    });

    test('maximum below the minimum is raised', () {
      final g = normalizeGroup(og(type: 'multiple', required: true, min: 3, max: 2));
      expect(g.minSelect, equals(3));
      expect(g.maxSelect, equals(3));
    });

    test('multiple keeps defaults', () {
      final g = normalizeGroup(og(type: 'multiple', options: [opt('a', def: true), opt('b', def: true)]));
      expect(g.options.where((o) => o.isDefault).length, equals(2));
    });

    test('switching multiple to single trims min and max', () {
      final multi = og(type: 'multiple', required: true, min: 2, max: 4);
      final single = normalizeGroup(multi.copyWith(selectType: 'single'));
      expect(single.minSelect, equals(1));
      expect(single.maxSelect, equals(1));
    });
  });

  group('setDefaultOption', () {
    test('single clears the others', () {
      final g = og(options: [opt('a', def: true), opt('b')]);
      final next = setDefaultOption(g, 'b', true);
      expect(next.options.map((o) => o.isDefault).toList(), equals([false, true]));
    });

    test('single can be unset', () {
      final g = og(options: [opt('a', def: true), opt('b')]);
      final next = setDefaultOption(g, 'a', false);
      expect(next.options.any((o) => o.isDefault), isFalse);
    });

    test('multiple toggles independently', () {
      final g = og(type: 'multiple', max: null, options: [opt('a', def: true), opt('b')]);
      final next = setDefaultOption(g, 'b', true);
      expect(next.options.map((o) => o.isDefault).toList(), equals([true, true]));
    });
  });

  group('optionResultPrice', () {
    test('additional adds to the dish price', () {
      final g = og(mode: 'additional');
      expect(optionResultPrice(g, opt('a', price: 30), 200), equals(230));
    });

    test('additional with a discount uses the discount', () {
      final g = og(mode: 'additional');
      expect(optionResultPrice(g, opt('a', price: 30, discount: 20), 200), equals(220));
    });

    test('absolute replaces the dish price', () {
      final g = og(mode: 'absolute');
      expect(optionResultPrice(g, opt('a', price: 350), 200), equals(350));
    });

    test('absolute with an empty price shows the dish price', () {
      final g = og(mode: 'absolute');
      expect(optionResultPrice(g, opt('a', price: 0), 200), equals(200));
    });
  });

  group('cloning', () {
    test('cloneGroup gives new ids and keeps the content', () {
      final original = og(
        id: 'g1',
        en: 'Size',
        bn: 'সাইজ',
        options: [opt('o1', en: 'Small', bn: 'ছোট', price: 10, def: true), opt('o2', en: 'Large', price: 20)],
      );
      final copy = cloneGroup(original, counter());
      expect(copy.id, isNot(equals('g1')));
      expect(copy.nameBn, equals('সাইজ'));
      expect(copy.options.map((o) => o.id).toList(), equals(['id2', 'id3']));
      expect(copy.options.first.nameBn, equals('ছোট'));
      expect(copy.options.first.isDefault, isTrue);
      expect(copy.options.last.price, equals(20));
    });

    test('appendClones keeps the existing groups first', () {
      final existing = [og(id: 'x')];
      final result = appendClones(existing, [og(id: 'y')], counter());
      expect(result.length, equals(2));
      expect(result.first.id, equals('x'));
      expect(result.last.id, isNot(equals('y')));
    });
  });

  group('optionImageUrls', () {
    test('collects non-empty urls', () {
      final groups = [
        og(options: [
          ItemOption(id: 'a', nameEn: 'A', imageUrl: 'u1'),
          ItemOption(id: 'b', nameEn: 'B', imageUrl: ''),
          ItemOption(id: 'c', nameEn: 'C'),
        ]),
      ];
      expect(optionImageUrls(groups), equals({'u1'}));
    });
  });

  group('validateOptionGroups', () {
    test('no groups is fine', () {
      expect(validateOptionGroups(const []), isEmpty);
    });

    test('a group needs a name', () {
      final errors = validateOptionGroups([og(en: null)]);
      expect(errors, contains('Group 1 needs a name in English or Bangla.'));
    });

    test('a Bangla name alone is enough', () {
      expect(validateOptionGroups([og(en: null, bn: 'সাইজ')]), isEmpty);
    });

    test('a group needs at least one option', () {
      final errors = validateOptionGroups([og(options: [])]);
      expect(errors, contains('Group "Size": add at least one option.'));
    });

    test('an option needs a name', () {
      final errors = validateOptionGroups([og(options: [opt('a'), opt('b', en: null)])]);
      expect(errors, contains('Option 2 in Group "Size" needs a name.'));
    });

    test('a name over 120 characters', () {
      final errors = validateOptionGroups([og(en: 'a' * 121)]);
      expect(errors.any((e) => e.contains('120')), isTrue);
      final optionErrors = validateOptionGroups([og(options: [opt('a', en: 'b' * 121)])]);
      expect(optionErrors.any((e) => e.contains('120')), isTrue);
    });

    test('negative price', () {
      final errors = validateOptionGroups([og(options: [opt('a', price: -1)])]);
      expect(errors.any((e) => e.contains('cannot be negative')), isTrue);
    });

    test('discount must be lower than the price', () {
      final errors = validateOptionGroups([og(options: [opt('a', en: 'Large', price: 50, discount: 50)])]);
      expect(errors, contains('Option "Large": discount must be lower than the price.'));
      expect(validateOptionGroups([og(options: [opt('a', price: 50, discount: 49)])]), isEmpty);
    });

    test('maximum must be at least the minimum', () {
      final errors = validateOptionGroups([
        og(en: 'Extras', type: 'multiple', required: true, min: 3, max: 2, options: [opt('a'), opt('b'), opt('c')]),
      ]);
      expect(errors, contains('Group "Extras": maximum must be at least the minimum.'));
    });

    test('maximum of zero', () {
      final errors = validateOptionGroups([og(type: 'multiple', max: 0)]);
      expect(errors.any((e) => e.contains('at least 1')), isTrue);
    });

    test('single group rules', () {
      expect(validateOptionGroups([og(min: 2, max: 1)]).isNotEmpty, isTrue);
      expect(validateOptionGroups([og(min: 1, max: 3)]).isNotEmpty, isTrue);
      expect(validateOptionGroups([og(min: 1, max: null)]), isEmpty);
    });

    test('only one default in a single group', () {
      final errors = validateOptionGroups([og(options: [opt('a', def: true), opt('b', def: true)])]);
      expect(errors, contains('Group "Size": only one option can be the default.'));
    });

    test('a required group needs an available option', () {
      final errors = validateOptionGroups([
        og(required: true, min: 1, options: [opt('a', available: false)]),
      ]);
      expect(errors, contains('Group "Size": a required choice needs at least one available option.'));
    });

    test('minimum higher than available options', () {
      final errors = validateOptionGroups([
        og(type: 'multiple', required: true, min: 3, max: null, options: [opt('a'), opt('b'), opt('c', available: false)]),
      ]);
      expect(errors.any((e) => e.contains('higher than the number of available options')), isTrue);
    });

    test('group without a name uses its position in the messages', () {
      final errors = validateOptionGroups([og(en: null, bn: null, options: [])]);
      expect(errors.any((e) => e.contains('Group 1: add at least one option')), isTrue);
    });

    test('Bangla option names are accepted', () {
      expect(validateOptionGroups([og(options: [opt('a', en: null, bn: 'ছোট')])]), isEmpty);
    });
  });

  group('selectionHint', () {
    test('single groups', () {
      expect(selectionHint(og(required: true, min: 1)), equals('Choose 1'));
      expect(selectionHint(og()), equals('Optional, choose 1'));
    });

    test('multiple required', () {
      expect(selectionHint(og(type: 'multiple', required: true, min: 1, max: null)), equals('Choose at least 1'));
      expect(selectionHint(og(type: 'multiple', required: true, min: 2, max: null)), equals('Choose at least 2'));
      expect(selectionHint(og(type: 'multiple', required: true, min: 2, max: 2)), equals('Choose 2'));
      expect(selectionHint(og(type: 'multiple', required: true, min: 2, max: 4)), equals('Choose 2 to 4'));
    });

    test('multiple optional', () {
      expect(selectionHint(og(type: 'multiple', max: null)), equals('Optional, choose any'));
      expect(selectionHint(og(type: 'multiple', max: 3)), equals('Optional, choose up to 3'));
    });
  });
}
