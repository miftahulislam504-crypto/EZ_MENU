import 'package:flutter_test/flutter_test.dart';

import 'package:ez_menu/core/logic/pricing.dart';
import 'package:ez_menu/features/public_menu/public_menu_models.dart';

Map<String, dynamic> _payload() => {
  'generated_at': '2026-11-22T10:30:00Z',
  'is_preview': true,
  'business': {
    'id': 'biz1',
    'slug': 'burger-house',
    'name_en': 'Burger House',
    'name_bn': 'বার্গার হাউস',
    'logo_url': 'https://cdn/logo.png',
    'phone': '01712345678',
    'currency': 'BDT',
    'default_language': 'en',
    'brand_color': '#C2410C',
    'menu_theme': 'warm',
    'menu_layout': 'grid',
    'welcome_message_en': 'Welcome',
  },
  'branch': {
    'id': 'br1',
    'slug': 'gulshan',
    'name_en': 'Gulshan',
    'latitude': 23.79,
    'longitude': '90.41',
    'outside_hours_behavior': 'allow_scheduled',
  },
  'branches': [
    {'slug': 'gulshan', 'name_en': 'Gulshan', 'area': 'Gulshan 2'},
    {'slug': 'banani', 'name_en': 'Banani'},
  ],
  'status': {'status': 'open', 'is_open': true, 'closes_at': '22:00:00'},
  'hours': {
    'weekly': [
      {'weekday': 6, 'open_time': '10:00:00', 'close_time': '22:00:00'},
    ],
    'special': [
      {'date': '2026-12-16', 'is_closed': true, 'label_en': 'Victory Day'},
    ],
  },
  'context': {'kind': 'table', 'qr_token': 'tok', 'table_id': 't1', 'table_name': '5'},
  'categories': [
    {'id': 'c1', 'parent_id': null, 'name_en': 'Burgers', 'sort_order': 1},
    {'id': 'c2', 'parent_id': 'c1', 'name_bn': 'চিকেন', 'sort_order': 2},
  ],
  'items': [
    {
      'id': 'i1',
      'category_id': 'c1',
      'name_en': 'Classic',
      'price': 350,
      'discount_price': '300.5',
      'labels': ['popular', 'halal'],
      'allergens': ['milk'],
      'spice_level': 2,
      'calories': 640,
      'nutrition': {'protein_g': 25, 'fat_g': '18.5', 'bad': 'x'},
      'image_urls': ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
      'is_featured': true,
      'availability': 'scheduled',
      'schedules': [
        {'weekdays': [1, 2], 'start_time': '18:00:00', 'end_time': '22:00:00'},
        {'weekdays': ['5'], 'start_date': '2026-12-01'},
      ],
      'option_groups': [
        {
          'id': 'g1',
          'name_en': 'Size',
          'select_type': 'single',
          'price_mode': 'absolute',
          'is_required': true,
          'min_select': 1,
          'max_select': 1,
          'options': [
            {'id': 'o1', 'name_en': 'Regular', 'price': 350, 'is_default': true},
            {'id': 'o2', 'name_en': 'Large', 'price': 450, 'discount_price': 400, 'is_available': false},
          ],
        },
        {
          'id': 'g2',
          'select_type': 'multiple',
          'price_mode': 'additional',
          'max_select': 2,
          'options': [],
        },
      ],
    },
  ],
};

void main() {
  group('PublicMenuProblem.parse', () {
    test('maps every code of the function', () {
      expect(PublicMenuProblem.parse('not_found'), PublicMenuProblem.notFound);
      expect(PublicMenuProblem.parse('qr_inactive'), PublicMenuProblem.qrInactive);
      expect(PublicMenuProblem.parse('table_inactive'), PublicMenuProblem.tableInactive);
      expect(PublicMenuProblem.parse('branch_inactive'), PublicMenuProblem.branchInactive);
      expect(PublicMenuProblem.parse('unpublished'), PublicMenuProblem.unpublished);
      expect(PublicMenuProblem.parse('something else'), PublicMenuProblem.unknown);
      expect(PublicMenuProblem.parse(null), PublicMenuProblem.unknown);
    });
  });

  group('PublicMenuResult.fromJson', () {
    test('an error payload becomes a failure', () {
      final result = PublicMenuResult.fromJson({'error': 'qr_inactive'});
      expect(result.data, isNull);
      expect(result.problem, PublicMenuProblem.qrInactive);
    });

    test('something that is not a map is an unknown failure', () {
      expect(PublicMenuResult.fromJson(null).problem, PublicMenuProblem.unknown);
      expect(PublicMenuResult.fromJson('oops').problem, PublicMenuProblem.unknown);
      expect(PublicMenuResult.fromJson(const [1, 2]).problem, PublicMenuProblem.unknown);
    });

    test('a full payload is parsed', () {
      final result = PublicMenuResult.fromJson(_payload());
      expect(result.problem, isNull);
      final data = result.data!;
      expect(data.isPreview, isTrue);
      expect(data.generatedAt, isNotNull);

      expect(data.business.slug, 'burger-house');
      expect(data.business.startsInBangla, isFalse);
      expect(data.business.isGrid, isTrue);
      expect(data.business.menuTheme, 'warm');
      expect(data.business.welcomeEn, 'Welcome');

      expect(data.branch.slug, 'gulshan');
      expect(data.branch.latitude, 23.79);
      expect(data.branch.longitude, 90.41);
      expect(data.branch.outsideHoursBehavior, 'allow_scheduled');

      expect(data.branches.length, 2);
      expect(data.hasMultipleBranches, isTrue);
      expect(data.branches.first.area, 'Gulshan 2');

      expect(data.status.isOpen, isTrue);
      expect(data.status.closesAt, '22:00:00');
      expect(data.status.isTemporarilyClosed, isFalse);

      expect(data.weeklyHours.single.weekday, 6);
      expect(data.specialHours.single.isClosed, isTrue);
      expect(data.specialHours.single.labelEn, 'Victory Day');

      expect(data.context.isTable, isTrue);
      expect(data.context.tableName, '5');
      expect(data.context.isTakeaway, isFalse);

      expect(data.categories.length, 2);
      expect(data.categories[1].parentId, 'c1');
    });

    test('dishes keep prices, labels, nutrition, schedules and choices', () {
      final item = PublicMenuResult.fromJson(_payload()).data!.items.single;
      expect(item.price, 350);
      expect(item.discountPrice, 300.5);
      expect(item.hasDiscount, isTrue);
      expect(item.labels, ['popular', 'halal']);
      expect(item.hasLabel('halal'), isTrue);
      expect(item.allergens, ['milk']);
      expect(item.spiceLevel, 2);
      expect(item.calories, 640);
      expect(item.nutrition, {'protein_g': 25.0, 'fat_g': 18.5});
      expect(item.firstImage, 'https://cdn/a.jpg');
      expect(item.isFeatured, isTrue);
      expect(item.availability, ItemAvailability.scheduled);
      expect(item.availability.canOrder, isFalse);

      expect(item.schedules.length, 2);
      expect(item.schedules.first.weekdays, [1, 2]);
      expect(item.schedules.last.weekdays, [5]);
      expect(item.schedules.last.startDate, '2026-12-01');

      final size = item.optionGroups.first;
      expect(size.multiple, isFalse);
      expect(size.mode, OptionPriceMode.absolute);
      expect(size.isRequired, isTrue);
      expect(size.options.length, 2);
      expect(size.options.first.isDefault, isTrue);
      expect(size.options.last.isAvailable, isFalse);
      expect(size.options.last.discountPrice, 400);

      final extras = item.optionGroups.last;
      expect(extras.multiple, isTrue);
      expect(extras.mode, OptionPriceMode.additional);
      expect(extras.maxSelect, 2);
    });

    test('option groups convert for the price calculator', () {
      final group = PublicMenuResult.fromJson(_payload()).data!.items.single.optionGroups.first;
      final priced = group.toPriced();
      expect(priced.mode, OptionPriceMode.absolute);
      expect(priced.options.length, 2);
      expect(priced.options.last.isAvailable, isFalse);
      expect(priced.effectiveMin, 1);
      expect(priced.effectiveMax, 1);
    });

    test('missing sections give empty lists and defaults', () {
      final result = PublicMenuResult.fromJson({
        'business': {'id': 'b', 'slug': 's'},
        'branch': {'id': 'br', 'slug': 'x'},
      });
      final data = result.data!;
      expect(data.items, isEmpty);
      expect(data.categories, isEmpty);
      expect(data.branches, isEmpty);
      expect(data.weeklyHours, isEmpty);
      expect(data.status.status, 'closed');
      expect(data.context.kind, 'menu');
      expect(data.business.currency, 'BDT');
      expect(data.business.startsInBangla, isTrue);
      expect(data.isPreview, isFalse);
    });

    test('a temporary closure keeps its end time', () {
      final result = PublicMenuResult.fromJson({
        'business': {'id': 'b', 'slug': 's'},
        'branch': {'id': 'br', 'slug': 'x'},
        'status': {'status': 'temporarily_closed', 'is_open': false, 'until': '2026-11-25T08:00:00Z'},
      });
      final status = result.data!.status;
      expect(status.isTemporarilyClosed, isTrue);
      expect(status.until, DateTime.utc(2026, 11, 25, 8));
    });
  });

  group('ItemAvailability.parse', () {
    test('known values and the default', () {
      expect(ItemAvailability.parse('sold_out'), ItemAvailability.soldOut);
      expect(ItemAvailability.parse('scheduled'), ItemAvailability.scheduled);
      expect(ItemAvailability.parse('available'), ItemAvailability.available);
      expect(ItemAvailability.parse(null), ItemAvailability.available);
      expect(ItemAvailability.available.canOrder, isTrue);
      expect(ItemAvailability.soldOut.canOrder, isFalse);
    });
  });
}
