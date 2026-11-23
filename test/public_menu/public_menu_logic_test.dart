import 'package:flutter_test/flutter_test.dart';

import 'package:ez_menu/core/logic/pricing.dart';
import 'package:ez_menu/features/public_menu/public_menu_logic.dart';
import 'package:ez_menu/features/public_menu/public_menu_models.dart';

PublicItem _item(
  String id,
  String category, {
  String? en,
  String? bn,
  double price = 100,
  double? discount,
  List<String> labels = const [],
  ItemAvailability availability = ItemAvailability.available,
  bool featured = false,
  List<PublicOptionGroup> groups = const [],
  String? short,
  String? ingredients,
}) => PublicItem(
  id: id,
  categoryId: category,
  nameEn: en,
  nameBn: bn,
  shortEn: short,
  ingredientsEn: ingredients,
  price: price,
  discountPrice: discount,
  labels: labels,
  availability: availability,
  isFeatured: featured,
  optionGroups: groups,
);

PublicMenuData _menu({
  List<PublicCategory>? categories,
  List<PublicItem>? items,
  PublicBusiness? business,
  PublicBranch? branch,
  BranchStatus status = const BranchStatus(),
  List<PublicHourRow> weekly = const [],
  List<PublicSpecialHour> special = const [],
  PublicContext context = const PublicContext(),
}) => PublicMenuData(
  business: business ?? const PublicBusiness(id: 'b', slug: 'burger', nameEn: 'Burger House', nameBn: 'বার্গার হাউস'),
  branch: branch ?? const PublicBranch(id: 'br', slug: 'gulshan', nameEn: 'Gulshan'),
  status: status,
  weeklyHours: weekly,
  specialHours: special,
  context: context,
  categories:
      categories ??
      const [
        PublicCategory(id: 'c1', nameEn: 'Burgers', nameBn: 'বার্গার', sortOrder: 1),
        PublicCategory(id: 'c2', parentId: 'c1', nameEn: 'Chicken', sortOrder: 2),
        PublicCategory(id: 'c3', nameEn: 'Drinks', sortOrder: 3),
      ],
  items: items ?? const [],
);

void main() {
  group('names', () {
    test('fall back to the other language and then a plain word', () {
      const business = PublicBusiness(id: 'b', slug: 's', nameEn: 'Burger House');
      expect(businessDisplayName(business, bangla: true), 'Burger House');
      expect(businessDisplayName(const PublicBusiness(id: 'b', slug: 's'), bangla: false), 'Menu');
      expect(itemDisplayName(_item('1', 'c', bn: 'বার্গার'), bangla: false), 'বার্গার');
      expect(itemDisplayName(_item('1', 'c'), bangla: false), 'Dish');
      expect(itemDisplayName(_item('1', 'c'), bangla: true), 'খাবার');
      expect(categoryDisplayName(const PublicCategory(id: 'c'), bangla: false), 'Other');
    });

    test('summary prefers the short description', () {
      final both = PublicItem(
        id: 'i',
        categoryId: 'c',
        shortEn: 'Short',
        descriptionEn: 'Long text',
      );
      expect(itemSummary(both, bangla: false), 'Short');
      final onlyLong = PublicItem(id: 'i', categoryId: 'c', descriptionEn: 'Long text');
      expect(itemSummary(onlyLong, bangla: false), 'Long text');
      expect(itemSummary(PublicItem(id: 'i', categoryId: 'c'), bangla: false), isNull);
    });

    test('table and takeaway labels', () {
      expect(contextLabel(const PublicContext(kind: 'table', tableName: '12'), bangla: false), 'Table 12');
      expect(contextLabel(const PublicContext(kind: 'table', tableName: '12'), bangla: true), 'টেবিল ১২');
      expect(contextLabel(const PublicContext(kind: 'takeaway'), bangla: false), 'Takeaway');
      expect(contextLabel(const PublicContext(), bangla: false), isNull);
      expect(contextLabel(const PublicContext(kind: 'table', tableName: ' '), bangla: false), isNull);
    });
  });

  group('search', () {
    final burger = _item('1', 'c1', en: 'Beef Burger', bn: 'বিফ বার্গার', labels: ['halal'], short: 'Juicy patty', ingredients: 'Beef, onion');
    final salad = _item('2', 'c1', en: 'Green Salad', labels: ['vegan']);

    test('an empty query matches everything', () {
      expect(matchesQuery(burger, ''), isTrue);
      expect(matchesQuery(burger, '   '), isTrue);
    });

    test('every word must match, in any order and case', () {
      expect(matchesQuery(burger, 'burger'), isTrue);
      expect(matchesQuery(burger, 'BEEF burger'), isTrue);
      expect(matchesQuery(burger, 'burger beef'), isTrue);
      expect(matchesQuery(burger, 'burger chicken'), isFalse);
    });

    test('finds Bangla names, descriptions, ingredients and labels', () {
      expect(matchesQuery(burger, 'বার্গার'), isTrue);
      expect(matchesQuery(burger, 'juicy'), isTrue);
      expect(matchesQuery(burger, 'onion'), isTrue);
      expect(matchesQuery(burger, 'halal'), isTrue);
      expect(matchesQuery(burger, 'হালাল'), isTrue);
      expect(matchesQuery(salad, 'halal'), isFalse);
    });

    test('Bangla and ASCII digits find each other', () {
      final combo = _item('3', 'c1', en: 'Combo 2');
      expect(matchesQuery(combo, 'combo ২'), isTrue);
      final bangla = _item('4', 'c1', bn: 'কম্বো ২');
      expect(matchesQuery(bangla, '2'), isTrue);
    });

    test('filters need every selected label', () {
      final both = _item('5', 'c1', labels: ['vegan', 'vegetarian']);
      expect(matchesFilters(both, {'vegan'}), isTrue);
      expect(matchesFilters(both, {'vegan', 'vegetarian'}), isTrue);
      expect(matchesFilters(both, {'vegan', 'halal'}), isFalse);
      expect(matchesFilters(both, const {}), isTrue);
    });

    test('only available hides sold out and scheduled dishes', () {
      final sold = _item('6', 'c1', availability: ItemAvailability.soldOut);
      final later = _item('7', 'c1', availability: ItemAvailability.scheduled);
      expect(matchesFilters(sold, const {}, onlyAvailable: true), isFalse);
      expect(matchesFilters(later, const {}, onlyAvailable: true), isFalse);
      expect(matchesFilters(sold, const {}), isTrue);
    });

    test('available filters follow the menu and keep a fixed order', () {
      final filters = availableFilters([
        _item('1', 'c', labels: ['halal', 'popular']),
        _item('2', 'c', labels: ['vegan', 'spicy']),
      ]);
      expect(filters, ['vegan', 'halal', 'spicy']);
      expect(availableFilters(const <PublicItem>[]), isEmpty);
    });
  });

  group('sections', () {
    final items = [
      _item('a', 'c1', en: 'Classic'),
      _item('b', 'c2', en: 'Crispy Chicken'),
      _item('c', 'c3', en: 'Cola', labels: ['vegan']),
      _item('d', 'c1', en: 'Double'),
    ];

    test('parents come first with their subcategories after', () {
      final data = _menu(items: items);
      final sections = buildSections(data, bangla: false);
      expect(sections.map((s) => s.id).toList(), ['c1', 'c2', 'c3']);
      expect(sections[0].items.map((i) => i.id).toList(), ['a', 'd']);
      expect(sections[1].parentTitle, 'Burgers');
      expect(sections[1].rootId, 'c1');
      expect(sections[2].rootId, 'c3');
      expect(countItems(sections), 4);
    });

    test('titles follow the language', () {
      final data = _menu(items: items);
      expect(buildSections(data, bangla: true).first.title, 'বার্গার');
      expect(buildSections(data, bangla: false).first.title, 'Burgers');
    });

    test('empty categories are left out and filters narrow the list', () {
      final data = _menu(items: items);
      final sections = buildSections(data, bangla: false, filters: {'vegan'});
      expect(sections.map((s) => s.id).toList(), ['c3']);
      final searched = buildSections(data, bangla: false, query: 'chicken');
      expect(searched.map((s) => s.id).toList(), ['c2']);
      expect(buildSections(data, bangla: false, query: 'pizza'), isEmpty);
    });

    test('a subcategory with dishes shows even if its parent has none', () {
      final data = _menu(items: [_item('b', 'c2', en: 'Crispy')]);
      final sections = buildSections(data, bangla: false);
      expect(sections.single.id, 'c2');
      expect(sections.single.parentTitle, 'Burgers');
    });

    test('dishes in an unknown category go to Other at the end', () {
      final data = _menu(items: [_item('a', 'c1'), _item('z', 'missing')]);
      final sections = buildSections(data, bangla: false);
      expect(sections.last.id, otherSectionId);
      expect(sections.last.title, 'Other');
      expect(buildSections(data, bangla: true).last.title, 'অন্যান্য');
    });

    test('a subcategory whose parent is missing becomes a top level one', () {
      final data = _menu(
        categories: const [PublicCategory(id: 'k', parentId: 'gone', nameEn: 'Kids')],
        items: [_item('a', 'k')],
      );
      final sections = buildSections(data, bangla: false);
      expect(sections.single.rootId, 'k');
      expect(sections.single.parentTitle, isNull);
    });

    test('the category bar lists top level categories that have dishes', () {
      final data = _menu(items: items);
      final sections = buildSections(data, bangla: false);
      final roots = buildRoots(data, sections, bangla: false);
      expect(roots.map((r) => r.id).toList(), ['c1', 'c3']);
      expect(roots.first.title, 'Burgers');
      expect(buildRoots(data, const [], bangla: false), isEmpty);
    });
  });

  group('highlights', () {
    test('rails appear only when they have dishes, available ones first', () {
      final rails = buildHighlights([
        _item('1', 'c', featured: true, availability: ItemAvailability.soldOut),
        _item('2', 'c', featured: true),
        _item('3', 'c', labels: ['popular', 'new']),
        _item('4', 'c', labels: ['recommended']),
      ]);
      expect(rails.map((r) => r.id).toList(), ['featured', 'popular', 'new', 'recommended']);
      expect(rails.first.items.map((i) => i.id).toList(), ['2', '1']);
      expect(rails.first.title(bangla: true), 'বিশেষ');
      expect(rails.first.title(bangla: false), 'Featured');
    });

    test('the limit applies to each rail', () {
      final many = [for (var i = 0; i < 20; i++) _item('$i', 'c', labels: ['popular'])];
      expect(buildHighlights(many, limit: 5).single.items.length, 5);
    });

    test('nothing highlighted gives no rails', () {
      expect(buildHighlights([_item('1', 'c')]), isEmpty);
    });
  });

  group('prices', () {
    PublicOptionGroup sizes({bool required = true, List<PublicOption>? options}) => PublicOptionGroup(
      id: 'g',
      mode: OptionPriceMode.absolute,
      isRequired: required,
      options:
          options ??
          const [
            PublicOption(id: 'h', price: 250),
            PublicOption(id: 'f', price: 450),
          ],
    );

    test('plain and discounted dishes', () {
      final plain = priceDisplay(_item('1', 'c', price: 300));
      expect(plain.amount, 300);
      expect(plain.hasDiscount, isFalse);
      expect(plain.from, isFalse);

      final cheaper = priceDisplay(_item('2', 'c', price: 300, discount: 240));
      expect(cheaper.amount, 240);
      expect(cheaper.original, 300);
      expect(cheaper.hasDiscount, isTrue);
    });

    test('a discount that is not lower is ignored', () {
      final item = _item('1', 'c', price: 300, discount: 300);
      expect(item.hasDiscount, isFalse);
      expect(priceDisplay(item).amount, 300);
      expect(discountPercent(item), isNull);
    });

    test('a required size choice shows from the cheapest size', () {
      final price = priceDisplay(_item('1', 'c', price: 999, groups: [sizes()]));
      expect(price.amount, 250);
      expect(price.from, isTrue);
    });

    test('equal sizes are not shown as from', () {
      final group = sizes(options: const [PublicOption(id: 'a', price: 250), PublicOption(id: 'b', price: 250)]);
      expect(priceDisplay(_item('1', 'c', groups: [group])).from, isFalse);
    });

    test('a sold out size is ignored and a size discount is kept', () {
      final group = sizes(
        options: const [
          PublicOption(id: 'a', price: 200, isAvailable: false),
          PublicOption(id: 'b', price: 300, discountPrice: 270),
          PublicOption(id: 'c', price: 500),
        ],
      );
      final price = priceDisplay(_item('1', 'c', groups: [group]));
      expect(price.amount, 270);
      expect(price.original, 300);
      expect(price.from, isTrue);
    });

    test('an optional size group does not change the card price', () {
      final price = priceDisplay(_item('1', 'c', price: 300, groups: [sizes(required: false)]));
      expect(price.amount, 300);
      expect(price.from, isFalse);
    });

    test('add-on groups never change the card price', () {
      const extras = PublicOptionGroup(
        id: 'x',
        isRequired: true,
        options: [PublicOption(id: 'e', price: 40)],
      );
      expect(priceDisplay(_item('1', 'c', price: 300, groups: [extras])).amount, 300);
    });

    test('discount percent rounds and ignores tiny discounts', () {
      expect(discountPercent(_item('1', 'c', price: 300, discount: 240)), 20);
      expect(discountPercent(_item('2', 'c', price: 1000, discount: 999.9)), isNull);
      expect(discountPercent(_item('3', 'c', price: 0, discount: 0)), isNull);
    });

    test('price text in English and Bangla', () {
      const display = PriceDisplay(amount: 1250);
      expect(formatPriceDisplay(display, currency: 'BDT', bangla: false), '৳ 1,250');
      expect(formatPriceDisplay(display, currency: 'BDT', bangla: true), '৳ ১,২৫০');
      const from = PriceDisplay(amount: 250, from: true);
      expect(formatPriceDisplay(from, currency: 'BDT', bangla: false), 'From ৳ 250');
      expect(formatPriceDisplay(from, currency: 'BDT', bangla: true), '৳ ২৫০ থেকে');
    });
  });

  group('dish facts', () {
    test('facts skip what is missing', () {
      const item = PublicItem(
        id: 'i',
        categoryId: 'c',
        prepTimeMin: 15,
        spiceLevel: 2,
        calories: 640,
      );
      expect(itemFacts(item, bangla: false), ['15 min', 'Medium', '640 kcal']);
      expect(itemFacts(item, bangla: true), ['১৫ মিনিট', 'মাঝারি ঝাল', '৬৪০ ক্যালরি']);
      expect(itemFacts(const PublicItem(id: 'i', categoryId: 'c', spiceLevel: 0), bangla: false), isEmpty);
    });

    test('label and allergen names skip unknown ids', () {
      const item = PublicItem(
        id: 'i',
        categoryId: 'c',
        labels: ['halal', 'mystery', 'popular'],
        allergens: ['milk', 'unknown'],
      );
      expect(labelNames(item, bangla: false), ['Halal', 'Popular']);
      expect(labelNames(item, bangla: true), ['হালাল', 'জনপ্রিয়']);
      expect(labelNames(item, bangla: false, limit: 1), ['Halal']);
      expect(allergenNames(item, bangla: false), ['Milk']);
      expect(allergenNames(item, bangla: true), ['দুধ']);
    });

    test('nutrition lines follow the fixed field order', () {
      const item = PublicItem(
        id: 'i',
        categoryId: 'c',
        nutrition: {'fat_g': 18.5, 'protein_g': 25},
      );
      expect(nutritionLines(item, bangla: false), ['Protein 25 g', 'Fat 18.50 g']);
      expect(nutritionLines(const PublicItem(id: 'i', categoryId: 'c'), bangla: false), isEmpty);
    });

    test('availability wording', () {
      expect(availabilityLabel(_item('1', 'c'), bangla: false), isNull);
      expect(availabilityLabel(_item('1', 'c', availability: ItemAvailability.soldOut), bangla: false), 'Sold out');
      expect(availabilityLabel(_item('1', 'c', availability: ItemAvailability.soldOut), bangla: true), 'শেষ');
      expect(
        availabilityLabel(_item('1', 'c', availability: ItemAvailability.scheduled), bangla: false),
        'Not available now',
      );
    });

    test('schedule lines describe each window', () {
      const item = PublicItem(
        id: 'i',
        categoryId: 'c',
        schedules: [
          PublicSchedule(weekdays: [1, 2], startTime: '18:00:00', endTime: '22:00:00'),
          PublicSchedule(),
        ],
      );
      final lines = scheduleLines(item, bangla: false);
      expect(lines.length, 2);
      expect(lines.first, contains('Mon, Tue'));
      expect(lines.first, contains('6:00 PM - 10:00 PM'));
      expect(lines.last, contains('Every day'));
    });
  });

  group('choices', () {
    const size = PublicOptionGroup(
      id: 'size',
      mode: OptionPriceMode.absolute,
      isRequired: true,
      options: [
        PublicOption(id: 'h', price: 250, isDefault: true),
        PublicOption(id: 'f', price: 450),
        PublicOption(id: 'x', price: 500, isAvailable: false),
      ],
    );
    const extras = PublicOptionGroup(
      id: 'extras',
      multiple: true,
      maxSelect: 2,
      options: [
        PublicOption(id: 'cheese', price: 40),
        PublicOption(id: 'egg', price: 30),
        PublicOption(id: 'sauce', price: 0),
      ],
    );
    final dish = _item('1', 'c', price: 200, groups: const [size, extras]);

    test('defaults are chosen at the start', () {
      expect(initialSelections(dish), {'size': {'h'}});
      expect(initialSelections(_item('2', 'c')), isEmpty);
    });

    test('a single choice switches and a required one cannot be cleared', () {
      var selections = initialSelections(dish);
      selections = toggleOption(selections, size, 'f');
      expect(selections['size'], {'f'});
      final same = toggleOption(selections, size, 'f');
      expect(same['size'], {'f'});
    });

    test('an optional single choice clears when tapped again', () {
      const optional = PublicOptionGroup(
        id: 'o',
        options: [PublicOption(id: 'a', price: 0), PublicOption(id: 'b', price: 0)],
      );
      var selections = toggleOption(const {}, optional, 'a');
      expect(selections['o'], {'a'});
      selections = toggleOption(selections, optional, 'a');
      expect(selections.containsKey('o'), isFalse);
    });

    test('a multiple choice toggles and stops at its maximum', () {
      var selections = <String, Set<String>>{};
      selections = toggleOption(selections, extras, 'cheese');
      selections = toggleOption(selections, extras, 'egg');
      expect(selections['extras'], {'cheese', 'egg'});
      final blocked = toggleOption(selections, extras, 'sauce');
      expect(blocked['extras'], {'cheese', 'egg'});
      final removed = toggleOption(selections, extras, 'cheese');
      expect(removed['extras'], {'egg'});
    });

    test('an unavailable or unknown option cannot be chosen', () {
      final start = initialSelections(dish);
      expect(toggleOption(start, size, 'x')['size'], {'h'});
      expect(toggleOption(start, size, 'nope')['size'], {'h'});
    });

    test('toggling does not change the selection it was given', () {
      final start = initialSelections(dish);
      toggleOption(start, size, 'f');
      expect(start['size'], {'h'});
    });

    test('price follows the choices with the dashboard rules', () {
      var selections = initialSelections(dish);
      expect(priceFor(dish, selections).unitPrice, 250);
      selections = toggleOption(selections, extras, 'cheese');
      expect(priceFor(dish, selections).unitPrice, 290);
      selections = toggleOption(selections, size, 'f');
      expect(priceFor(dish, selections).unitPrice, 490);
      expect(priceFor(dish, selections).isValid, isTrue);
    });

    test('a missing required choice is reported', () {
      final breakdown = priceFor(dish, const {});
      expect(breakdown.isValid, isFalse);
      expect(breakdown.issues.single.problem, SelectionProblem.required);
      expect(
        selectionProblemText(breakdown.issues.single, size, bangla: false),
        'Choose an option for Options',
      );
    });

    test('rule text reads naturally', () {
      expect(groupRuleText(size, bangla: false), 'Choose 1');
      expect(groupRuleText(extras, bangla: false), 'Optional, up to 2');
      const range = PublicOptionGroup(id: 'r', multiple: true, minSelect: 2, maxSelect: 4);
      expect(groupRuleText(range, bangla: false), 'Choose 2 to 4');
      const exact = PublicOptionGroup(id: 'e', multiple: true, minSelect: 2, maxSelect: 2);
      expect(groupRuleText(exact, bangla: false), 'Choose 2');
      const atLeast = PublicOptionGroup(id: 'a', multiple: true, minSelect: 1);
      expect(groupRuleText(atLeast, bangla: false), 'Choose at least 1');
      const free = PublicOptionGroup(id: 'f', multiple: true);
      expect(groupRuleText(free, bangla: false), 'Optional');
      const optionalSingle = PublicOptionGroup(id: 's');
      expect(groupRuleText(optionalSingle, bangla: false), 'Optional, choose 1');
      expect(groupRuleText(range, bangla: true), '২ থেকে ৪টি বেছে নিন');
    });

    test('option price text', () {
      expect(optionPriceText(size.options.first, size, currency: 'BDT', bangla: false), '৳ 250');
      expect(optionPriceText(extras.options.first, extras, currency: 'BDT', bangla: false), '+ ৳ 40');
      expect(optionPriceText(extras.options.last, extras, currency: 'BDT', bangla: false), '');
      const discounted = PublicOption(id: 'd', price: 450, discountPrice: 400);
      expect(optionPriceText(discounted, size, currency: 'BDT', bangla: false), '৳ 400');
      expect(optionPriceText(extras.options.first, extras, currency: 'BDT', bangla: true), '+ ৳ ৪০');
    });
  });

  group('opening status', () {
    test('headlines', () {
      expect(statusHeadline(const BranchStatus(status: 'open', isOpen: true), bangla: false), 'Open now');
      expect(statusHeadline(const BranchStatus(), bangla: false), 'Closed');
      expect(statusHeadline(const BranchStatus(status: 'temporarily_closed'), bangla: false), 'Temporarily closed');
      expect(statusHeadline(const BranchStatus(status: 'open', isOpen: true), bangla: true), 'এখন খোলা');
    });

    test('open shows the closing time', () {
      final data = _menu(status: const BranchStatus(status: 'open', isOpen: true, closesAt: '22:00:00'));
      expect(statusDetail(data, bangla: false), 'Closes at 10:00 PM');
      expect(statusDetail(data, bangla: true), contains('পর্যন্ত খোলা'));
      expect(
        statusDetail(_menu(status: const BranchStatus(status: 'open', isOpen: true)), bangla: false),
        isNull,
      );
    });

    test('closed shows when it opens today, or nothing', () {
      final data = _menu(status: const BranchStatus(opensAt: '11:30:00'));
      expect(statusDetail(data, bangla: false), 'Opens today at 11:30 AM');
      expect(statusDetail(_menu(), bangla: false), isNull);
    });

    test('a temporary closure prefers the restaurant message, then the end date', () {
      final withMessage = _menu(
        status: const BranchStatus(status: 'temporarily_closed'),
        branch: const PublicBranch(id: 'b', slug: 's', tempClosedMessageEn: 'Back after Eid', tempClosedMessageBn: 'ঈদের পর'),
      );
      expect(statusDetail(withMessage, bangla: false), 'Back after Eid');
      expect(statusDetail(withMessage, bangla: true), 'ঈদের পর');

      final withDate = _menu(
        status: BranchStatus(status: 'temporarily_closed', until: DateTime(2026, 11, 25, 12)),
      );
      expect(statusDetail(withDate, bangla: false), 'Back on 25 Nov');
      expect(statusDetail(withDate, bangla: true), '২৫ নভেম্বর তারিখে আবার খুলবে');

      final bare = _menu(status: const BranchStatus(status: 'temporarily_closed'));
      expect(statusDetail(bare, bangla: false), 'We are closed for a while');
    });
  });

  group('hours', () {
    final week = [
      for (final day in [6, 7, 1, 2, 3, 4])
        PublicHourRow(weekday: day, open: '10:00:00', close: '22:00:00'),
    ];

    test('days with the same hours are joined and Friday is closed', () {
      final lines = weeklyHoursLines(_menu(weekly: week), bangla: false);
      expect(lines.length, 2);
      expect(lines.first.days, 'Sat - Thu');
      expect(lines.first.times, '10:00 AM - 10:00 PM');
      expect(lines.first.closed, isFalse);
      expect(lines.last.days, 'Fri');
      expect(lines.last.times, 'Closed');
      expect(lines.last.closed, isTrue);
    });

    test('today is marked on its own line', () {
      final onMonday = weeklyHoursLines(_menu(weekly: week), bangla: false, todayWeekday: DateTime.monday);
      expect(onMonday.first.isToday, isTrue);
      expect(onMonday.last.isToday, isFalse);
      final onFriday = weeklyHoursLines(_menu(weekly: week), bangla: false, todayWeekday: DateTime.friday);
      expect(onFriday.first.isToday, isFalse);
      expect(onFriday.last.isToday, isTrue);
    });

    test('two periods in a day are listed together, with their labels', () {
      final lines = weeklyHoursLines(
        _menu(
          weekly: const [
            PublicHourRow(weekday: 1, open: '12:00:00', close: '15:00:00', labelEn: 'Lunch'),
            PublicHourRow(weekday: 1, open: '19:00:00', close: '23:00:00', labelEn: 'Dinner'),
          ],
        ),
        bangla: false,
      );
      final monday = lines.firstWhere((l) => !l.closed);
      expect(monday.times, 'Lunch 12:00 PM - 3:00 PM, Dinner 7:00 PM - 11:00 PM');
    });

    test('no weekly hours means no lines', () {
      expect(weeklyHoursLines(_menu(), bangla: false), isEmpty);
    });

    test('special days show the date, label and hours', () {
      final lines = specialHoursLines(
        _menu(
          special: const [
            PublicSpecialHour(date: '2026-12-16', isClosed: true, labelEn: 'Victory Day'),
            PublicSpecialHour(date: '2026-12-24', endDate: '2026-12-26', open: '12:00:00', close: '18:00:00'),
          ],
        ),
        bangla: false,
      );
      expect(lines.first.days, 'Wed 16 Dec');
      expect(lines.first.times, 'Victory Day: Closed');
      expect(lines.first.closed, isTrue);
      expect(lines.last.days, 'Thu 24 Dec - Sat 26 Dec');
      expect(lines.last.times, '12:00 PM - 6:00 PM');
    });

    test('short dates in Bangla and bad input', () {
      expect(formatShortDate('2026-12-16', bangla: true), 'বুধ ১৬ ডিসেম্বর');
      expect(formatShortDate('not a date', bangla: false), 'not a date');
      expect(formatShortDate(null, bangla: false), '');
    });
  });

  group('contact', () {
    test('a full business lists every way to reach it', () {
      final data = _menu(
        business: const PublicBusiness(
          id: 'b',
          slug: 's',
          phone: '01712-345678',
          whatsappNumber: '+8801812345678',
          email: 'hello@burger.com',
          websiteUrl: 'https://www.burger.com/menu',
          facebookUrl: 'facebook.com/burger',
          instagramUrl: 'https://instagram.com/burger',
        ),
        branch: const PublicBranch(
          id: 'br',
          slug: 'g',
          phone: '01912345678',
          mapUrl: 'https://maps.app.goo.gl/abc',
          address: 'House 4, Road 11',
          area: 'Gulshan 2',
        ),
      );
      final actions = contactActions(data, bangla: false);
      expect(actions.map((a) => a.kind).toList(), [
        ContactKind.call,
        ContactKind.whatsapp,
        ContactKind.email,
        ContactKind.map,
        ContactKind.website,
        ContactKind.facebook,
        ContactKind.instagram,
      ]);
      expect(actions[0].url, 'tel:+8801912345678');
      expect(actions[0].value, '01912-345678');
      expect(actions[1].url, 'https://wa.me/8801812345678');
      expect(actions[2].url, 'mailto:hello@burger.com');
      expect(actions[3].url, 'https://maps.app.goo.gl/abc');
      expect(actions[3].value, 'House 4, Road 11, Gulshan 2');
      expect(actions[4].value, 'burger.com');
      expect(actions[5].value, 'facebook.com');
    });

    test('the branch phone wins over the business phone and falls back to it', () {
      const business = PublicBusiness(id: 'b', slug: 's', phone: '01712345678');
      final fallback = contactActions(_menu(business: business), bangla: false);
      expect(fallback.single.url, 'tel:+8801712345678');
    });

    test('a map link is built from coordinates when there is none', () {
      final data = _menu(branch: const PublicBranch(id: 'b', slug: 's', latitude: 23.79, longitude: 90.41));
      final map = contactActions(data, bangla: false).single;
      expect(map.kind, ContactKind.map);
      expect(map.url, 'https://www.google.com/maps/search/?api=1&query=23.79,90.41');
    });

    test('a foreign whatsapp number still gets a link', () {
      final data = _menu(business: const PublicBusiness(id: 'b', slug: 's', whatsappNumber: '+44 7700 900123'));
      final action = contactActions(data, bangla: false).single;
      expect(action.url, 'https://wa.me/447700900123');
    });

    test('nothing filled in gives no actions', () {
      expect(contactActions(_menu(), bangla: false), isEmpty);
    });

    test('labels follow the language', () {
      final data = _menu(business: const PublicBusiness(id: 'b', slug: 's', phone: '01712345678'));
      expect(contactActions(data, bangla: true).single.label, 'ফোন করুন');
      expect(contactActions(data, bangla: false).single.label, 'Call');
    });

    test('address prefers the branch and does not repeat the area', () {
      expect(displayAddress(_menu()), isNull);
      expect(
        displayAddress(_menu(business: const PublicBusiness(id: 'b', slug: 's', address: 'Dhaka'))),
        'Dhaka',
      );
      expect(
        displayAddress(_menu(branch: const PublicBranch(id: 'b', slug: 's', address: 'Road 5, Gulshan', area: 'Gulshan'))),
        'Road 5, Gulshan',
      );
      expect(
        displayAddress(_menu(branch: const PublicBranch(id: 'b', slug: 's', area: 'Banani'))),
        'Banani',
      );
    });
  });

  group('about', () {
    test('only the notes the restaurant wrote are listed', () {
      const business = PublicBusiness(
        id: 'b',
        slug: 's',
        descriptionEn: 'Best burgers',
        allergenNoticeBn: 'বাদাম আছে',
        termsEn: 'Be nice',
      );
      final english = infoBlocks(business, bangla: false);
      expect(english.map((b) => b.title).toList(), ['About us', 'Allergen notice', 'Terms']);
      expect(english[1].body, 'বাদাম আছে');
      final bangla = infoBlocks(business, bangla: true);
      expect(bangla.first.title, 'আমাদের সম্পর্কে');
      expect(infoBlocks(const PublicBusiness(id: 'b', slug: 's'), bangla: false), isEmpty);
    });

    test('welcome text follows the language', () {
      const business = PublicBusiness(id: 'b', slug: 's', welcomeEn: 'Welcome', welcomeBn: 'স্বাগতম');
      expect(welcomeText(business, bangla: false), 'Welcome');
      expect(welcomeText(business, bangla: true), 'স্বাগতম');
      expect(welcomeText(const PublicBusiness(id: 'b', slug: 's'), bangla: false), isNull);
    });
  });
  group('when there is no menu', () {
    test('every problem has a title and a message in both languages', () {
      for (final problem in PublicMenuProblem.values) {
        for (final bangla in [false, true]) {
          final text = problemText(problem, bangla: bangla);
          expect(text.title.trim(), isNotEmpty, reason: '$problem bangla=$bangla');
          expect(text.message.trim(), isNotEmpty, reason: '$problem bangla=$bangla');
        }
      }
    });

    test('the two languages differ', () {
      final english = problemText(PublicMenuProblem.qrInactive, bangla: false);
      final bangla = problemText(PublicMenuProblem.qrInactive, bangla: true);
      expect(english.title, 'This QR code is not active');
      expect(bangla.title, isNot(english.title));
    });

    test('an unpublished menu and a missing menu say different things', () {
      expect(
        problemText(PublicMenuProblem.unpublished, bangla: false).title,
        isNot(problemText(PublicMenuProblem.notFound, bangla: false).title),
      );
    });
  });

  group('today in the restaurant time zone', () {
    test('Dhaka is six hours ahead of UTC and can be on the next day', () {
      // 20:30 UTC on Friday 2026-11-20 is 02:30 on Saturday in Dhaka.
      final now = DateTime.utc(2026, 11, 20, 20, 30);
      expect(todayWeekdayFor('Asia/Dhaka', now), DateTime.saturday);
    });

    test('Dhaka stays on the same day earlier in the day', () {
      final now = DateTime.utc(2026, 11, 20, 10, 0);
      expect(todayWeekdayFor('Asia/Dhaka', now), DateTime.friday);
    });

    test('another zone uses the weekday of the given time', () {
      final now = DateTime.utc(2026, 11, 20, 20, 30);
      expect(todayWeekdayFor('Europe/London', now), now.weekday);
    });
  });
}
