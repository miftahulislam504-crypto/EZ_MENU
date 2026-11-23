import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/core/logic/csv_codec.dart';
import 'package:ez_menu/core/logic/menu_csv.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

MenuItem stored(
  String id, {
  String category = 'c1',
  String? en,
  String? bn,
  String? sku,
  double price = 100,
  double? discount,
}) => MenuItem(
  id: id,
  businessId: 'b',
  categoryId: category,
  nameEn: en,
  nameBn: bn,
  sku: sku,
  price: price,
  discountPrice: discount,
);

MenuCategory cat(String id, {String? en, String? bn, String? parent}) =>
    MenuCategory(id: id, businessId: 'b', parentId: parent, nameEn: en, nameBn: bn);

const String header = 'Category,Name,Price,Discount,Labels,SKU';

void main() {
  group('headers', () {
    test('friendly and sql names map to the same field', () {
      expect(fieldForHeader('Price (Tk)'), equals('price'));
      expect(fieldForHeader('price'), equals('price'));
      expect(fieldForHeader('Name (English)'), equals('name_en'));
      expect(fieldForHeader('NAME_BN'), equals('name_bn'));
      expect(fieldForHeader('Prep time (min)'), equals('prep_time_min'));
      expect(fieldForHeader('Visible'), equals('is_active'));
      expect(fieldForHeader('Whatever'), isNull);
    });
  });

  group('parseMenuCsv file level', () {
    test('empty text', () {
      expect(parseMenuCsv('').fileErrors, isNotEmpty);
      expect(parseMenuCsv('   \n ').canImport, isFalse);
    });

    test('missing columns are reported', () {
      final p = parseMenuCsv('Foo,Bar\n1,2\n');
      expect(p.canImport, isFalse);
      expect(p.fileErrors.length, equals(3));
    });

    test('header only has no dishes', () {
      final p = parseMenuCsv('$header\n');
      expect(p.fileErrors, isNotEmpty);
    });

    test('byte order mark and semicolons are handled', () {
      final p = parseMenuCsv('﻿Category;Name;Price\nStarters;Soup;120\n');
      expect(p.fileErrors, isEmpty);
      expect(p.delimiter, equals(';'));
      expect(p.validRows.single.price, equals(120));
    });

    test('unknown and repeated headers are ignored with a note', () {
      final p = parseMenuCsv('Category,Name,Price,Price,Colour\nA,B,1,2,red\n');
      expect(p.ignoredHeaders, equals(['Price', 'Colour']));
      expect(p.fileWarnings, hasLength(1));
      expect(p.validRows.single.price, equals(1));
    });

    test('too many rows', () {
      final b = StringBuffer('Category,Name,Price\n');
      for (var i = 0; i < importMaxRows + 1; i++) {
        b.write('A,Dish $i,10\n');
      }
      expect(parseMenuCsv(b.toString()).fileErrors, isNotEmpty);
    });
  });

  group('parseMenuCsv rows', () {
    test('a valid row produces the sql payload', () {
      final p = parseMenuCsv('$header\nMains,Beef Tehari,"1,250.50",900,"Spicy; Halal",TEH-1\n');
      final r = p.validRows.single;
      expect(r.number, equals(2));
      expect(r.values['category_en'], equals('Mains'));
      expect(r.values['name_en'], equals('Beef Tehari'));
      expect(r.values['price'], equals(1250.5));
      expect(r.values['discount_price'], equals(900));
      expect(r.values['labels'], equals(['spicy', 'halal']));
      expect(r.values['sku'], equals('TEH-1'));
    });

    test('Bangla digits and currency words in prices', () {
      final p = parseMenuCsv('$header\nA,B,৳ ২৫০,,,\nA,C,Tk 99.5,,,\nA,D,120/-,,,\n');
      expect(p.validRows.map((r) => r.price).toList(), equals([250, 99.5, 120]));
    });

    test('price problems are row errors', () {
      final p = parseMenuCsv('$header\nA,B,,,,\nA,C,abc,,,\nA,D,-5,,,\nA,E,10,20,,\n');
      expect(p.validRows, isEmpty);
      expect(p.invalidRows.length, equals(4));
      expect(p.invalidRows[0].errors.single, contains('required'));
      expect(p.invalidRows[1].errors.single, contains('not a number'));
      expect(p.invalidRows[2].errors.single, contains('negative'));
      expect(p.invalidRows[3].errors.single, contains('lower than the price'));
    });

    test('discount equal to price is a warning only', () {
      final p = parseMenuCsv('$header\nA,B,10,10,,\n');
      expect(p.validRows.single.warnings, hasLength(1));
    });

    test('name and category are required', () {
      final p = parseMenuCsv('$header\n,B,10,,,\nA,,10,,,\n');
      expect(p.invalidRows.length, equals(2));
      expect(p.invalidRows[0].errors.single, contains('Category'));
      expect(p.invalidRows[1].errors.single, contains('name'));
    });

    test('Bangla in an English column moves to the Bangla field', () {
      final p = parseMenuCsv('$header\nস্টার্টার,চিকেন স্যুপ,100,,,\n');
      final r = p.validRows.single;
      expect(r.values.containsKey('name_en'), isFalse);
      expect(r.values['name_bn'], equals('চিকেন স্যুপ'));
      expect(r.values['category_bn'], equals('স্টার্টার'));
      expect(r.warnings, hasLength(2));
    });

    test('unknown labels warn and known ones match in Bangla and aliases', () {
      final p = parseMenuCsv('$header\nA,B,10,,"Veg, শেফের বিশেষ, Tasty, Halal, halal",\n');
      final r = p.validRows.single;
      expect(r.values['labels'], equals(['vegetarian', 'chefs_special', 'halal']));
      expect(r.warnings.single, contains('Tasty'));
    });

    test('yes and no columns', () {
      final p = parseMenuCsv('Category,Name,Price,Sold out,Visible,Featured\nA,B,1,Yes,না,maybe\n');
      final r = p.validRows.single;
      expect(r.values['is_sold_out'], isTrue);
      expect(r.values['is_active'], isFalse);
      expect(r.values.containsKey('is_featured'), isFalse);
      expect(r.warnings.single, contains('maybe'));
    });

    test('prep time range', () {
      final p = parseMenuCsv('Category,Name,Price,Prep time (min)\nA,B,1,15\nA,C,1,601\nA,D,1,x\n');
      expect(p.validRows.single.values['prep_time_min'], equals(15));
      expect(p.invalidRows.length, equals(2));
    });

    test('long text is an error', () {
      final long = 'x' * 161;
      final p = parseMenuCsv('Category,Name,Price\nA,$long,1\n');
      expect(p.invalidRows.single.errors.single, contains('160'));
    });

    test('repeated SKU or dish in the file is flagged', () {
      final p = parseMenuCsv('$header\nA,B,1,,,S1\nA,C,1,,,S1\nA,B,1,,,\n');
      expect(p.rows[0].warnings, isEmpty);
      expect(p.rows[1].warnings.single, contains('row 2'));
      expect(p.rows[2].warnings.single, contains('row 2'));
    });

    test('formula protection apostrophe is removed', () {
      final p = parseMenuCsv("Category,Name,Price\nA,'-Special,1\n");
      expect(p.validRows.single.values['name_en'], equals('-Special'));
    });

    test('short rows are padded', () {
      final p = parseMenuCsv('Category,Name,Price,Labels\nA,B,5\n');
      expect(p.validRows.single.values['labels'], equals(<String>[]));
    });
  });

  group('planImport', () {
    final categories = [cat('c1', en: 'Mains'), cat('c2', en: 'Rice', parent: 'c1')];

    ImportPlan plan(String csv, List<MenuItem> items, {bool update = true}) =>
        planImport(
          parseMenuCsv(csv).validRows,
          existingItems: items,
          existingCategories: categories,
          updateExisting: update,
        );

    test('new dish in a new category', () {
      final p = plan('$header\nDesserts,Cake,50,,,\n', []);
      expect(p.created, equals(1));
      expect(p.newCategories, equals(['Desserts']));
      expect(p.rows.single.newCategory, isTrue);
    });

    test('match by name inside the category ignoring case', () {
      final p = plan('$header\nmains,beef tehari,300,,,\n', [stored('i1', en: 'Beef Tehari')]);
      expect(p.updated, equals(1));
      expect(p.newCategories, isEmpty);
    });

    test('skip when updates are off', () {
      final p = plan('$header\nMains,Beef Tehari,300,,,\n', [stored('i1', en: 'Beef Tehari')], update: false);
      expect(p.skipped, equals(1));
      expect(p.updated, equals(0));
    });

    test('SKU match wins over the category and notes the move', () {
      final p = plan(
        '$header\nDesserts,Anything,300,,,S9\n',
        [stored('i1', en: 'Old', sku: 'S9')],
      );
      expect(p.updated, equals(1));
      expect(p.rows.single.notes.first, contains('Moves from "Mains" to "Desserts"'));
    });

    test('a dish in a subcategory is noted when imported at the top level', () {
      final p = plan(
        '$header\nMains,Fried Rice,100,,,\n',
        [stored('i1', category: 'c2', en: 'Fried Rice', sku: 'FR')],
      );
      // No SKU in the file and the subcategory is not a top level match, so it is a new dish.
      expect(p.created, equals(1));
    });

    test('an existing discount is flagged as cleared', () {
      final p = plan('$header\nMains,Beef Tehari,300,,,\n', [stored('i1', en: 'Beef Tehari', discount: 250)]);
      expect(p.rows.single.notes.single, contains('discount'));
    });

    test('the same dish twice in one file is created once then updated', () {
      final p = plan('$header\nMains,Soup,10,,,\nMains,Soup,20,,,\n', []);
      expect(p.created, equals(1));
      expect(p.updated, equals(1));
    });

    test('Bangla names match exactly', () {
      final p = plan('$header\nমেইন,বিরিয়ানি,10,,,\n', [stored('i1', category: 'c1', bn: 'বিরিয়ানি')]);
      // Category "মেইন" does not exist, so a new category is made and the dish is new.
      expect(p.created, equals(1));
      expect(p.newCategories, equals(['মেইন']));
    });
  });

  group('sending and results', () {
    test('chunkList', () {
      expect(chunkList([1, 2, 3, 4, 5], size: 2), equals([[1, 2], [3, 4], [5]]));
      expect(chunkList(<int>[], size: 2), isEmpty);
      expect(chunkList([1], size: 500), equals([[1]]));
    });

    test('server errors are mapped back to file rows', () {
      final p = parseMenuCsv('$header\nA,B,1,,,\nA,C,2,,,\nA,D,3,,,\n');
      final sent = [p.rows[1], p.rows[2]];
      final tally = const ImportTally().addChunk(
        const ImportResult(created: 1, errors: [(row: 2, message: 'boom')]),
        sent,
      );
      expect(tally.created, equals(1));
      expect(tally.issues.single.row, equals(4));
      expect(tally.issues.single.title, equals('D'));
    });

    test('a failed chunk fails every row', () {
      final p = parseMenuCsv('$header\nA,B,1,,,\nA,C,2,,,\n');
      final tally = const ImportTally().addFailedChunk(p.rows, 'offline');
      expect(tally.failed, equals(2));
      expect(tally.saved, equals(0));
    });

    test('payload is a copy of the values', () {
      final p = parseMenuCsv('$header\nA,B,1,,,\n');
      final payload = importPayload(p.validRows);
      payload.single['price'] = 99;
      expect(p.validRows.single.price, equals(1));
    });
  });

  group('writing', () {
    test('template parses back without problems', () {
      final p = parseMenuCsv(buildTemplateCsv());
      expect(p.fileErrors, isEmpty);
      expect(p.rows.length, equals(2));
      expect(p.invalidRows, isEmpty);
      expect(p.rows.every((r) => r.warnings.isEmpty), isTrue);
      expect(buildTemplateCsv().startsWith('﻿'), isTrue);
    });

    test('export round trips through the importer', () {
      final categories = [cat('c1', en: 'Mains', bn: 'মেইন'), cat('c2', en: 'Rice', parent: 'c1')];
      final items = [
        MenuItem(
          id: 'i1',
          businessId: 'b',
          categoryId: 'c2',
          nameEn: 'Tehari, special',
          nameBn: 'তেহারি',
          price: 280,
          discountPrice: 250.5,
          sku: 'T1',
          labels: const ['spicy', 'chefs_special'],
          prepTimeMin: 15,
          isFeatured: true,
        ),
        MenuItem(id: 'i2', businessId: 'b', categoryId: 'c1', nameEn: 'Soup', price: 90, isSoldOut: true, isActive: false),
        MenuItem(id: 'i3', businessId: 'b', categoryId: 'c1', nameEn: 'Gone', deletedAt: DateTime(2026, 1, 1)),
      ];
      final csv = buildMenuCsv(items: items, categories: categories);
      final p = parseMenuCsv(csv);
      expect(p.fileErrors, isEmpty);
      expect(p.rows.length, equals(2));
      final tehari = p.rows.firstWhere((r) => r.nameEn == 'Tehari, special');
      expect(tehari.values['category_en'], equals('Mains'));
      expect(tehari.values['price'], equals(280));
      expect(tehari.values['discount_price'], equals(250.5));
      expect(tehari.values['labels'], equals(['spicy', 'chefs_special']));
      expect(tehari.values['is_featured'], isTrue);
      final soup = p.rows.firstWhere((r) => r.nameEn == 'Soup');
      expect(soup.values['is_sold_out'], isTrue);
      expect(soup.values['is_active'], isFalse);
      expect(csv.contains('Subcategory'), isTrue);
      expect(csv.contains('Rice'), isTrue);
    });

    test('error report keeps original cells and adds the problem', () {
      final p = parseMenuCsv('$header\nA,B,abc,,,\nA,C,5,,,\n');
      final report = buildErrorReportCsv(p, readIssues(p));
      final rows = CsvCodec.parse(report);
      expect(rows.length, equals(2));
      expect(rows.first.last, equals('Problem'));
      expect(rows[1][1], equals('B'));
      expect(rows[1].last, contains('not a number'));
    });
  });
}
