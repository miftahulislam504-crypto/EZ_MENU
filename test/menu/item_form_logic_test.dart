import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/item_form_logic.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

ItemFormInput form({
  String nameEn = 'Burger',
  String nameBn = '',
  String price = '250',
  String discount = '',
  String? category = 'c1',
  List<String> images = const [],
  bool soldOut = false,
  DateTime? until,
  Map<String, String> nutrition = const {},
  String prep = '',
  String calories = '',
  String sku = '',
  List<String> labels = const [],
  List<String> allergens = const [],
}) => ItemFormInput(
  nameEn: nameEn,
  nameBn: nameBn,
  price: price,
  discountPrice: discount,
  categoryId: category,
  imageUrls: images,
  isSoldOut: soldOut,
  soldOutUntil: until,
  nutrition: nutrition,
  prepTime: prep,
  calories: calories,
  sku: sku,
  labels: labels,
  allergens: allergens,
);

void main() {
  group('parseMoneyText', () {
    test('plain, decimal and grouped numbers', () {
      expect(parseMoneyText('250'), equals(250));
      expect(parseMoneyText('99.50'), equals(99.5));
      expect(parseMoneyText('1,250.75'), equals(1250.75));
    });

    test('Bangla digits', () {
      expect(parseMoneyText('২৫০'), equals(250));
      expect(parseMoneyText('১,২৫০.৫'), equals(1250.5));
    });

    test('currency words and symbols', () {
      expect(parseMoneyText('tk 99'), equals(99));
      expect(parseMoneyText('99 Tk.'), equals(99));
      expect(parseMoneyText('৳ 120'), equals(120));
      expect(parseMoneyText('120/-'), equals(120));
      expect(parseMoneyText('BDT 45'), equals(45));
    });

    test('empty and junk', () {
      expect(parseMoneyText(null), isNull);
      expect(parseMoneyText('   '), isNull);
      expect(parseMoneyText('abc'), isNull);
      expect(parseMoneyText('12abc'), isNull);
      expect(parseMoneyText('1.2.3'), isNull);
    });

    test('negative, exponent and infinity are rejected', () {
      expect(parseMoneyText('-5'), isNull);
      expect(parseMoneyText('1e5'), isNull);
      expect(parseMoneyText('Infinity'), isNull);
      expect(parseMoneyText('NaN'), isNull);
    });

    test('zero is a number', () {
      expect(parseMoneyText('0'), equals(0));
    });

    test('half-typed decimals', () {
      expect(parseMoneyText('5.'), equals(5));
      expect(parseMoneyText('.5'), equals(0.5));
      expect(parseMoneyText('.'), isNull);
    });
  });

  group('parseWholeNumber', () {
    test('whole numbers only', () {
      expect(parseWholeNumber('20'), equals(20));
      expect(parseWholeNumber('২০'), equals(20));
      expect(parseWholeNumber('20.0'), equals(20));
      expect(parseWholeNumber('20.5'), isNull);
      expect(parseWholeNumber(''), isNull);
    });
  });

  group('savingFor', () {
    test('amount and percent', () {
      final s = savingFor(200, 150)!;
      expect(s.amount, equals(50));
      expect(s.percent, equals(25));
    });

    test('rounds the percent and shows at least 1', () {
      expect(savingFor(300, 200)!.percent, equals(33));
      expect(savingFor(1000, 999.5)!.percent, equals(1));
    });

    test('no saving for equal, higher, missing or zero price', () {
      expect(savingFor(100, 100), isNull);
      expect(savingFor(100, 120), isNull);
      expect(savingFor(null, 50), isNull);
      expect(savingFor(100, null), isNull);
      expect(savingFor(0, 0), isNull);
    });
  });

  group('validateItemForm', () {
    test('a valid form', () {
      expect(validateItemForm(form()), isEmpty);
    });

    test('a name in either language is enough', () {
      expect(validateItemForm(form(nameEn: '', nameBn: 'বার্গার')), isEmpty);
      expect(validateItemForm(form(nameEn: '  ', nameBn: '')).containsKey('name'), isTrue);
    });

    test('name length 160', () {
      expect(validateItemForm(form(nameEn: 'a' * 161)).containsKey('nameEn'), isTrue);
      expect(validateItemForm(form(nameEn: 'a' * 160)), isEmpty);
      expect(validateItemForm(form(nameBn: 'ক' * 161)).containsKey('nameBn'), isTrue);
    });

    test('description limits', () {
      expect(validateItemForm(const ItemFormInput(nameEn: 'A', price: '1', categoryId: 'c', shortEn: 'x')), isEmpty);
      final tooLong = ItemFormInput(
        nameEn: 'A',
        price: '1',
        categoryId: 'c',
        shortEn: 'a' * 201,
        descBn: 'ক' * 2001,
        ingredientsEn: 'a' * 801,
        allergenNote: 'a' * 401,
        dietaryInfo: 'a' * 401,
        sku: 'a' * 61,
      );
      final errors = validateItemForm(tooLong);
      for (final key in ['shortEn', 'descBn', 'ingredientsEn', 'allergenNote', 'dietaryInfo', 'sku']) {
        expect(errors.containsKey(key), isTrue);
      }
    });

    test('price is required and must be a number', () {
      expect(validateItemForm(form(price: '')).containsKey('price'), isTrue);
      expect(validateItemForm(form(price: 'abc')).containsKey('price'), isTrue);
      expect(validateItemForm(form(price: '-5'))['price'], equals('The price cannot be negative.'));
      expect(validateItemForm(form(price: '0')), isEmpty);
      expect(validateItemForm(form(price: '২৫০')), isEmpty);
    });

    test('price upper limit', () {
      expect(validateItemForm(form(price: '10000000')), isEmpty);
      expect(validateItemForm(form(price: '10000001')).containsKey('price'), isTrue);
    });

    test('discount must be a number lower than the price', () {
      expect(validateItemForm(form(discount: '200')), isEmpty);
      expect(validateItemForm(form(discount: '250')).containsKey('discount'), isTrue);
      expect(validateItemForm(form(discount: '300')).containsKey('discount'), isTrue);
      expect(validateItemForm(form(discount: 'x')).containsKey('discount'), isTrue);
      expect(validateItemForm(form(discount: '-1'))['discount'], equals('The discount price cannot be negative.'));
    });

    test('a discount is not compared with an invalid price', () {
      final errors = validateItemForm(form(price: 'abc', discount: '10'));
      expect(errors.containsKey('price'), isTrue);
      expect(errors.containsKey('discount'), isFalse);
    });

    test('preparation time 0 to 600', () {
      expect(validateItemForm(form(prep: '0')), isEmpty);
      expect(validateItemForm(form(prep: '600')), isEmpty);
      expect(validateItemForm(form(prep: '601')).containsKey('prepTime'), isTrue);
      expect(validateItemForm(form(prep: '5.5')).containsKey('prepTime'), isTrue);
      expect(validateItemForm(form(prep: '-1')).containsKey('prepTime'), isTrue);
      expect(validateItemForm(form(prep: '২০')), isEmpty);
    });

    test('calories', () {
      expect(validateItemForm(form(calories: '350')), isEmpty);
      expect(validateItemForm(form(calories: '-3')).containsKey('calories'), isTrue);
      expect(validateItemForm(form(calories: '3.5')).containsKey('calories'), isTrue);
    });

    test('nutrition values', () {
      expect(validateItemForm(form(nutrition: {'protein_g': '12.5', 'sodium_mg': ''})), isEmpty);
      expect(validateItemForm(form(nutrition: {'protein_g': 'lots'})).containsKey('nutrition.protein_g'), isTrue);
      expect(validateItemForm(form(nutrition: {'fat_g': '-2'})).containsKey('nutrition.fat_g'), isTrue);
    });

    test('a category is required', () {
      expect(validateItemForm(form(category: null)).containsKey('category'), isTrue);
      expect(validateItemForm(form(category: '')).containsKey('category'), isTrue);
    });

    test('photo limit', () {
      expect(validateItemForm(form(images: List.generate(8, (i) => 'u$i'))), isEmpty);
      expect(validateItemForm(form(images: List.generate(9, (i) => 'u$i'))).containsKey('images'), isTrue);
    });

    test('the return time must be in the future when sold out', () {
      final now = DateTime(2026, 11, 20, 12);
      expect(validateItemForm(form(soldOut: true, until: DateTime(2026, 11, 20, 11)), now: now).containsKey('soldOutUntil'), isTrue);
      expect(validateItemForm(form(soldOut: true, until: DateTime(2026, 11, 20, 13)), now: now), isEmpty);
      expect(validateItemForm(form(soldOut: false, until: DateTime(2026, 11, 20, 11)), now: now), isEmpty);
    });

    test('several problems at once', () {
      final errors = validateItemForm(form(nameEn: '', price: '', category: null));
      expect(errors.keys.toSet(), equals({'name', 'price', 'category'}));
    });
  });

  group('itemValues', () {
    test('trims, nulls empty text and parses numbers', () {
      final values = itemValues(
        form(nameEn: '  Burger ', nameBn: '', price: '১,২৫০', discount: '1000', prep: '15', calories: '450', sku: ' CB-1 '),
        sortOrder: 7,
      );
      expect(values['name_en'], equals('Burger'));
      expect(values['name_bn'], isNull);
      expect(values['price'], equals(1250));
      expect(values['discount_price'], equals(1000));
      expect(values['prep_time_min'], equals(15));
      expect(values['calories'], equals(450));
      expect(values['sku'], equals('CB-1'));
      expect(values['sort_order'], equals(7));
      expect(values['category_id'], equals('c1'));
    });

    test('sort order is omitted when not given', () {
      expect(itemValues(form()).containsKey('sort_order'), isFalse);
    });

    test('no discount gives null', () {
      expect(itemValues(form())['discount_price'], isNull);
    });

    test('nutrition keeps only filled values and whole numbers become ints', () {
      final values = itemValues(form(nutrition: {'protein_g': '12', 'fat_g': '3.5', 'sugar_g': '', 'sodium_mg': '  '}));
      expect(values['nutrition'], equals({'protein_g': 12, 'fat_g': 3.5}));
    });

    test('labels and allergens are filtered to known ids without duplicates', () {
      final values = itemValues(form(labels: ['spicy', 'bogus', 'spicy', 'halal'], allergens: ['milk', 'nope', 'eggs']));
      expect(values['labels'], equals(['spicy', 'halal']));
      expect(values['allergens'], equals(['milk', 'eggs']));
    });

    test('sold out time is stored in UTC only while sold out', () {
      final until = DateTime.utc(2026, 11, 20, 12);
      expect(itemValues(form(soldOut: true, until: until))['sold_out_until'], equals('2026-11-20T12:00:00.000Z'));
      expect(itemValues(form(soldOut: false, until: until))['sold_out_until'], isNull);
    });

    test('image urls pass through', () {
      expect(itemValues(form(images: ['a', 'b']))['image_urls'], equals(['a', 'b']));
    });
  });

  group('itemFormSignature', () {
    test('equal forms give equal signatures', () {
      expect(itemFormSignature(form()), equals(itemFormSignature(form())));
    });

    test('any change shows', () {
      expect(itemFormSignature(form()), isNot(equals(itemFormSignature(form(nameEn: 'Burgers')))));
      expect(itemFormSignature(form()), isNot(equals(itemFormSignature(form(images: ['a'])))));
      expect(itemFormSignature(form()), isNot(equals(itemFormSignature(form(nutrition: {'fat_g': '1'})))));
    });

    test('label order does not matter', () {
      expect(
        itemFormSignature(form(labels: ['spicy', 'halal'])),
        equals(itemFormSignature(form(labels: ['halal', 'spicy']))),
      );
    });
  });

  group('photos', () {
    test('makeCover moves a photo to the front', () {
      expect(makeCover(['a', 'b', 'c'], 2), equals(['c', 'a', 'b']));
      expect(makeCover(['a', 'b'], 0), equals(['a', 'b']));
      expect(makeCover(['a', 'b'], 5), equals(['a', 'b']));
    });

    test('removeImageAt', () {
      expect(removeImageAt(['a', 'b', 'c'], 1), equals(['a', 'c']));
      expect(removeImageAt(['a'], 3), equals(['a']));
    });

    test('moveImage', () {
      expect(moveImage(['a', 'b', 'c'], 0, 3), equals(['b', 'c', 'a']));
      expect(moveImage(['a', 'b', 'c'], 2, 0), equals(['c', 'a', 'b']));
    });

    test('imagesToDeleteAfterSave', () {
      final result = imagesToDeleteAfterSave(
        original: ['a', 'b'],
        current: ['b', 'c'],
        sessionUploads: ['c', 'd'],
      );
      expect(result.toSet(), equals({'a', 'd'}));
    });

    test('nothing to delete when nothing changed', () {
      expect(imagesToDeleteAfterSave(original: ['a'], current: ['a'], sessionUploads: const []), isEmpty);
    });

    test('imagesToDeleteOnDiscard removes only this session uploads', () {
      final result = imagesToDeleteOnDiscard(original: ['a', 'b'], sessionUploads: ['b', 'c', 'c']);
      expect(result, equals(['c']));
    });
  });

  group('signatures', () {
    OptionGroup grp({String name = 'Size', bool def = false, double price = 0}) => OptionGroup(
      id: 'g1',
      nameEn: name,
      options: [ItemOption(id: 'o1', nameEn: 'S', price: price, isDefault: def)],
    );

    test('option groups: equal and changed', () {
      expect(optionGroupsSignature([grp()]), equals(optionGroupsSignature([grp()])));
      expect(optionGroupsSignature([grp()]), isNot(equals(optionGroupsSignature([grp(name: 'Sizes')]))));
      expect(optionGroupsSignature([grp()]), isNot(equals(optionGroupsSignature([grp(def: true)]))));
      expect(optionGroupsSignature([grp()]), isNot(equals(optionGroupsSignature([grp(price: 5)]))));
      expect(optionGroupsSignature([]), equals(''));
    });

    test('option groups: order matters', () {
      const a = OptionGroup(id: 'a');
      const b = OptionGroup(id: 'b');
      expect(optionGroupsSignature([a, b]), isNot(equals(optionGroupsSignature([b, a]))));
    });

    test('schedules ignore weekday order and label spaces', () {
      const one = ItemSchedule(weekdays: [5, 6], startTime: '10:00', endTime: '12:00', label: ' Lunch ');
      const two = ItemSchedule(weekdays: [6, 5], startTime: '10:00', endTime: '12:00', label: 'Lunch');
      expect(schedulesSignature([one]), equals(schedulesSignature([two])));
      const three = ItemSchedule(weekdays: [5], startTime: '10:00', endTime: '12:00', label: 'Lunch');
      expect(schedulesSignature([one]), isNot(equals(schedulesSignature([three]))));
    });

    test('branch settings ignore order and an unused discount', () {
      const a = BranchItemSetting(branchId: 'b1', itemId: 'i', price: 100, discountPrice: 80);
      const b = BranchItemSetting(branchId: 'b2', itemId: 'i', isOffered: false);
      expect(branchSettingsSignature([a, b]), equals(branchSettingsSignature([b, a])));
      const noPriceA = BranchItemSetting(branchId: 'b1', itemId: 'i', discountPrice: 50);
      const noPriceB = BranchItemSetting(branchId: 'b1', itemId: 'i');
      expect(branchSettingSignature(noPriceA), equals(branchSettingSignature(noPriceB)));
      expect(branchSettingSignature(a), isNot(equals(branchSettingSignature(b))));
    });

    test('branch sold out time only counts while sold out', () {
      final until = DateTime.utc(2026, 11, 22, 10);
      final off = BranchItemSetting(branchId: 'b', itemId: 'i', soldOutUntil: until);
      const base = BranchItemSetting(branchId: 'b', itemId: 'i');
      expect(branchSettingSignature(off), equals(branchSettingSignature(base)));
      final on = BranchItemSetting(branchId: 'b', itemId: 'i', isSoldOut: true, soldOutUntil: until);
      expect(branchSettingSignature(on), isNot(equals(branchSettingSignature(base))));
    });
  });
}
