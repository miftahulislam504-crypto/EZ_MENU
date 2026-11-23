import '../../features/menu/menu_models.dart';
import 'csv_codec.dart';
import 'menu_catalog.dart';
import 'menu_search.dart';
import 'money.dart';

/// Menu spreadsheet (CSV) import and export. Pure Dart, no Flutter or
/// Supabase imports.
///
/// The import side turns the text of a file into rows that use exactly the keys
/// of the `import_menu_items` SQL function, checks every row before anything is
/// sent, and predicts what the function will do (create, update or skip) so
/// the preview can say so. The export side writes the same columns back out.

/// Rows per request to `import_menu_items` (the function accepts 1000).
const int importChunkSize = 500;

/// Largest file the importer reads.
const int importMaxRows = 5000;

/// One column of the menu spreadsheet.
class MenuCsvField {
  const MenuCsvField(
    this.key,
    this.header,
    this.note, {
    this.aliases = const [],
    this.required = false,
  });

  /// Key used by `import_menu_items`.
  final String key;

  /// Header written to exported files and the template.
  final String header;

  /// One line of help for the columns guide.
  final String note;

  /// Other header spellings accepted on import (see [normalizeHeader]).
  final List<String> aliases;

  /// A value is needed in every row (one of the language pair for names).
  final bool required;
}

/// Columns in the order they are written.
const List<MenuCsvField> menuCsvFields = [
  MenuCsvField(
    'category_en',
    'Category (English)',
    'Category name. Created when it does not exist yet.',
    required: true,
    aliases: [
      'category', 'categoryname', 'categoryen', 'categoryenglish',
      'categoryinenglish', 'section', 'menucategory',
    ],
  ),
  MenuCsvField(
    'category_bn',
    'Category (Bangla)',
    'Bangla category name. Either language is enough.',
    aliases: ['categorybn', 'categorybangla', 'categorybengali', 'categoryinbangla'],
  ),
  MenuCsvField(
    'name_en',
    'Name (English)',
    'Dish name. Either language is enough.',
    required: true,
    aliases: [
      'name', 'nameen', 'nameenglish', 'item', 'itemname', 'itemen', 'dish',
      'dishname', 'dishen', 'title', 'product', 'productname', 'nameinenglish',
    ],
  ),
  MenuCsvField(
    'name_bn',
    'Name (Bangla)',
    'Bangla dish name.',
    aliases: [
      'namebn', 'namebangla', 'namebengali', 'itembn', 'itemnamebn', 'dishbn',
      'nameinbangla',
    ],
  ),
  MenuCsvField(
    'short_description_en',
    'Short description (English)',
    'One line shown under the name, up to 200 characters.',
    aliases: [
      'shortdescription', 'shortdescriptionen', 'shortdescriptionenglish',
      'summary', 'tagline',
    ],
  ),
  MenuCsvField(
    'short_description_bn',
    'Short description (Bangla)',
    'Bangla one-line description.',
    aliases: ['shortdescriptionbn', 'shortdescriptionbangla'],
  ),
  MenuCsvField(
    'description_en',
    'Description (English)',
    'Longer description, up to 2000 characters.',
    aliases: [
      'description', 'descriptionen', 'descriptionenglish', 'details', 'desc',
    ],
  ),
  MenuCsvField(
    'description_bn',
    'Description (Bangla)',
    'Bangla long description.',
    aliases: ['descriptionbn', 'descriptionbangla'],
  ),
  MenuCsvField(
    'price',
    'Price',
    'Regular price as a number, 0 for a free dish. Required.',
    required: true,
    aliases: [
      'pricetk', 'pricebdt', 'tk', 'taka', 'rate', 'amount', 'regularprice',
      'mrp', 'unitprice', 'sellingprice',
    ],
  ),
  MenuCsvField(
    'discount_price',
    'Discount price',
    'Price after discount, lower than Price. Leave blank for none.',
    aliases: [
      'discount', 'saleprice', 'offerprice', 'discountedprice', 'specialprice',
      'discountpricetk',
    ],
  ),
  MenuCsvField(
    'prep_time_min',
    'Prep time (min)',
    'Whole minutes, 0 to 600.',
    aliases: [
      'preptime', 'preptimemin', 'preptimeminutes', 'preparationtime',
      'cookingtime', 'cooktime',
    ],
  ),
  MenuCsvField(
    'sku',
    'SKU',
    'Your own code. Used to find the dish again on a later import.',
    aliases: ['code', 'itemcode', 'productcode', 'skucode', 'itemsku'],
  ),
  MenuCsvField(
    'labels',
    'Labels',
    'Separated by commas or semicolons, for example Spicy; Halal.',
    aliases: ['label', 'tags', 'tag'],
  ),
  MenuCsvField(
    'is_sold_out',
    'Sold out',
    'yes or no. Blank keeps the current state.',
    aliases: ['issoldout', 'outofstock', 'soldout'],
  ),
  MenuCsvField(
    'is_active',
    'Visible',
    'yes or no. no hides the dish from customers.',
    aliases: ['isactive', 'active', 'show', 'shown', 'visibility', 'enabled'],
  ),
  MenuCsvField(
    'is_featured',
    'Featured',
    'yes or no.',
    aliases: ['isfeatured', 'featureditem'],
  ),
];

/// Headers that are understood but not imported (they appear in exports or
/// error reports), so they are not reported as unknown.
const Set<String> _ignoredHeaders = {
  'subcategory', 'problem', 'problems', 'error', 'errors', 'row', 'no', 'sl',
  'serial', 'serialno', 'id', 'status', 'note', 'notes', 'image', 'photo',
};

const String _subcategoryHeader = 'Subcategory';
const String _problemHeader = 'Problem';

/// Lower case letters and digits (including Bangla letters) only, so that
/// "Price (Tk)", "price_tk" and "PRICE TK" compare equal.
String normalizeHeader(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final isAscii = (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);
    final isBangla = rune >= 0x0980 && rune <= 0x09ff;
    if (isAscii || isBangla) out.writeCharCode(rune);
  }
  return out.toString();
}

final Map<String, String> _fieldByHeader = () {
  final map = <String, String>{};
  for (final field in menuCsvFields) {
    map[normalizeHeader(field.header)] = field.key;
    map[normalizeHeader(field.key)] = field.key;
    for (final alias in field.aliases) {
      map.putIfAbsent(alias, () => field.key);
    }
  }
  return map;
}();

/// The field a header refers to, or null when it is not a menu column.
String? fieldForHeader(String header) => _fieldByHeader[normalizeHeader(header)];

// ---- reading ----------------------------------------------------------------

/// What a column of the file was read as.
class CsvColumn {
  const CsvColumn({
    required this.index,
    required this.header,
    this.field,
    this.duplicate = false,
  });

  final int index;
  final String header;

  /// `import_menu_items` key, or null when the column is not imported.
  final String? field;

  /// Another column already supplies [field]; this one is ignored.
  final bool duplicate;
}

/// One data row of the file, read and checked.
class ImportRow {
  const ImportRow({
    required this.number,
    required this.cells,
    required this.values,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Row number as a spreadsheet shows it (the header is row 1).
  final int number;

  /// The cells exactly as read, for the error report.
  final List<String> cells;

  /// Payload for `import_menu_items`. Empty when the row has errors.
  final Map<String, dynamic> values;
  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;

  String? get nameEn => values['name_en'] as String?;
  String? get nameBn => values['name_bn'] as String?;
  String? get categoryEn => values['category_en'] as String?;
  String? get categoryBn => values['category_bn'] as String?;
  String? get sku => values['sku'] as String?;
  double? get price => (values['price'] as num?)?.toDouble();
  double? get discountPrice => (values['discount_price'] as num?)?.toDouble();

  /// Name for lists: English first, then Bangla.
  String get title => nameEn ?? nameBn ?? '';

  String get categoryTitle => categoryEn ?? categoryBn ?? '';
}

/// The whole file after reading.
class MenuCsvParse {
  const MenuCsvParse({
    this.delimiter = ',',
    this.headers = const [],
    this.columns = const [],
    this.ignoredHeaders = const [],
    this.rows = const [],
    this.fileErrors = const [],
    this.fileWarnings = const [],
  });

  final String delimiter;
  final List<String> headers;
  final List<CsvColumn> columns;

  /// Headers that are not imported (unknown or repeated).
  final List<String> ignoredHeaders;
  final List<ImportRow> rows;

  /// Problems that stop the import.
  final List<String> fileErrors;
  final List<String> fileWarnings;

  List<ImportRow> get validRows => [for (final r in rows) if (r.isValid) r];
  List<ImportRow> get invalidRows => [for (final r in rows) if (!r.isValid) r];
  int get warningRowCount => rows.where((r) => r.isValid && r.warnings.isNotEmpty).length;

  /// Something can be sent.
  bool get canImport => fileErrors.isEmpty && validRows.isNotEmpty;

  /// Fields the file supplies, in menu field order.
  List<String> get recognisedFields => [
    for (final c in columns)
      if (c.field != null && !c.duplicate) c.field!,
  ];
}

const List<String> _enFields = ['category_en', 'name_en', 'short_description_en', 'description_en'];

bool _hasBangla(String text) => text.runes.any((r) => r >= 0x0980 && r <= 0x09ff);

bool _hasLatin(String text) => text.runes.any(
  (r) => (r >= 0x41 && r <= 0x5a) || (r >= 0x61 && r <= 0x7a),
);

String _cleanCell(String raw) {
  var text = raw.trim();
  // Formula protection written by exports: '=SUM or '-dish.
  if (text.length > 1 && text[0] == "'" && '=+-@'.contains(text[1])) {
    text = text.substring(1);
  }
  return text;
}

String _oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String _multiLine(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

final RegExp _labelSplit = RegExp(r'[,;|\n]+');

const Map<String, String> _labelAliases = {
  'veg': 'vegetarian',
  'veggie': 'vegetarian',
  'chef': 'chefs_special',
  'chefs': 'chefs_special',
  'chefspick': 'chefs_special',
  'bestseller': 'popular',
  'bestselling': 'popular',
  'gf': 'gluten_free',
  'df': 'dairy_free',
};

final Map<String, String> _labelByName = () {
  final map = <String, String>{};
  for (final tag in menuLabels) {
    map[normalizeHeader(tag.id)] = tag.id;
    map[normalizeHeader(tag.en)] = tag.id;
    map[normalizeHeader(tag.bn)] = tag.id;
  }
  map.addAll(_labelAliases);
  return map;
}();

/// Label ids for a cell such as "Spicy; Chef's special; Halal", plus the
/// words that were not recognised. Repeats are dropped.
({List<String> ids, List<String> unknown}) parseLabels(String text) {
  final ids = <String>[];
  final unknown = <String>[];
  for (final part in text.split(_labelSplit)) {
    final word = part.trim();
    if (word.isEmpty) continue;
    final id = _labelByName[normalizeHeader(word)];
    if (id == null) {
      unknown.add(word);
    } else if (!ids.contains(id)) {
      ids.add(id);
    }
  }
  return (ids: ids, unknown: unknown);
}

const Set<String> _yes = {'yes', 'y', 'true', 't', '1', 'on', 'x', 'হ্যাঁ', 'হ্যা', 'হাঁ'};
const Set<String> _no = {'no', 'n', 'false', 'f', '0', 'off', 'না'};

/// yes/no in English or Bangla. Null when the text is neither.
bool? parseYesNo(String text) {
  final key = text.trim().toLowerCase();
  if (_yes.contains(key)) return true;
  if (_no.contains(key)) return false;
  return null;
}

/// A whole number of minutes, accepting Bangla digits.
int? _parseMinutes(String text) {
  final value = parseMoneyText(text);
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}

String _num(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  var text = value.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

const double _maxPrice = 9999999999.99;

/// Reads the text of a spreadsheet file. Never throws: problems are returned
/// in [MenuCsvParse.fileErrors] and in each row.
MenuCsvParse parseMenuCsv(String text) {
  final List<List<String>> table;
  final String delimiter;
  if (text.trim().isEmpty) {
    return const MenuCsvParse(fileErrors: ['The file is empty.']);
  }
  delimiter = CsvCodec.detectDelimiter(text.startsWith('﻿') ? text.substring(1) : text);
  table = CsvCodec.parse(text, delimiter: delimiter);
  if (table.isEmpty) {
    return const MenuCsvParse(fileErrors: ['The file is empty.']);
  }

  final headerCells = [for (final c in table.first) _cleanCell(c)];
  final columns = <CsvColumn>[];
  final seen = <String, String>{};
  final ignored = <String>[];
  final fileWarnings = <String>[];
  for (var i = 0; i < headerCells.length; i++) {
    final header = headerCells[i];
    if (header.isEmpty) {
      columns.add(CsvColumn(index: i, header: header));
      continue;
    }
    final field = fieldForHeader(header);
    if (field == null) {
      columns.add(CsvColumn(index: i, header: header));
      if (!_ignoredHeaders.contains(normalizeHeader(header))) ignored.add(header);
    } else if (seen.containsKey(field)) {
      columns.add(CsvColumn(index: i, header: header, field: field, duplicate: true));
      ignored.add(header);
      fileWarnings.add('Column "$header" repeats "${seen[field]}", so it is ignored.');
    } else {
      seen[field] = header;
      columns.add(CsvColumn(index: i, header: header, field: field));
    }
  }

  final errors = <String>[];
  final hasName = seen.containsKey('name_en') || seen.containsKey('name_bn');
  final hasCategory = seen.containsKey('category_en') || seen.containsKey('category_bn');
  if (!seen.containsKey('name_en') && !seen.containsKey('name_bn')) {
    errors.add('No dish name column found. Add a column called "Name (English)" or "Name (Bangla)".');
  }
  if (!hasCategory) {
    errors.add('No category column found. Add a column called "Category (English)" or "Category (Bangla)".');
  }
  if (!seen.containsKey('price')) {
    errors.add('No price column found. Add a column called "Price".');
  }
  if (errors.isNotEmpty) {
    return MenuCsvParse(
      delimiter: delimiter,
      headers: headerCells,
      columns: columns,
      ignoredHeaders: ignored,
      fileErrors: errors,
      fileWarnings: fileWarnings,
    );
  }

  final dataRows = table.skip(1).toList();
  if (dataRows.isEmpty) {
    return MenuCsvParse(
      delimiter: delimiter,
      headers: headerCells,
      columns: columns,
      ignoredHeaders: ignored,
      fileErrors: const ['The file has a header row but no dishes.'],
      fileWarnings: fileWarnings,
    );
  }
  if (dataRows.length > importMaxRows) {
    return MenuCsvParse(
      delimiter: delimiter,
      headers: headerCells,
      columns: columns,
      ignoredHeaders: ignored,
      fileErrors: [
        'The file has ${dataRows.length} rows. Import up to $importMaxRows dishes at a time and split larger files.',
      ],
      fileWarnings: fileWarnings,
    );
  }
  assert(hasName);

  final usable = [for (final c in columns) if (c.field != null && !c.duplicate) c];
  final rows = <ImportRow>[];
  for (var r = 0; r < dataRows.length; r++) {
    final cells = dataRows[r];
    final byField = <String, String>{
      for (final c in usable)
        c.field!: c.index < cells.length ? _cleanCell(cells[c.index]) : '',
    };
    rows.add(_readRow(r + 2, cells, byField));
  }

  return MenuCsvParse(
    delimiter: delimiter,
    headers: headerCells,
    columns: columns,
    ignoredHeaders: ignored,
    rows: _flagRepeats(rows),
    fileWarnings: fileWarnings,
  );
}

ImportRow _readRow(int number, List<String> cells, Map<String, String> byField) {
  final errors = <String>[];
  final warnings = <String>[];
  final values = <String, dynamic>{};

  String field(String key) => byField[key] ?? '';

  // Text columns. A Bangla text in an English column moves to the Bangla one.
  final text = <String, String>{};
  for (final key in const [
    'category_en', 'category_bn', 'name_en', 'name_bn', 'short_description_en',
    'short_description_bn', 'description_en', 'description_bn', 'sku',
  ]) {
    final raw = field(key);
    final isDescription = key.startsWith('description') || key.startsWith('short_description');
    text[key] = isDescription ? _multiLine(raw) : _oneLine(raw);
  }
  for (final enKey in _enFields) {
    final bnKey = enKey.replaceFirst('_en', '_bn');
    final en = text[enKey]!;
    if (en.isNotEmpty && _hasBangla(en) && !_hasLatin(en) && (text[bnKey] ?? '').isEmpty) {
      text[bnKey] = en;
      text[enKey] = '';
      warnings.add('Bangla text in the English ${_label(enKey)} column was saved as the Bangla ${_label(enKey)}.');
    }
  }

  const limits = <String, int>{
    'category_en': 120, 'category_bn': 120, 'name_en': 160, 'name_bn': 160,
    'short_description_en': 200, 'short_description_bn': 200,
    'description_en': 2000, 'description_bn': 2000, 'sku': 60,
  };
  for (final entry in text.entries) {
    final limit = limits[entry.key]!;
    if (entry.value.runes.length > limit) {
      errors.add('${_title(entry.key)} is longer than $limit characters.');
    }
  }

  if (text['name_en']!.isEmpty && text['name_bn']!.isEmpty) {
    errors.add('Dish name is required.');
  }
  if (text['category_en']!.isEmpty && text['category_bn']!.isEmpty) {
    errors.add('Category is required.');
  }

  // Price.
  final priceText = field('price');
  double? price;
  if (priceText.isEmpty) {
    errors.add('Price is required (use 0 for a free dish).');
  } else if (priceText.startsWith('-')) {
    errors.add('Price cannot be negative.');
  } else {
    price = parseMoneyText(priceText);
    if (price == null) {
      errors.add('Price "$priceText" is not a number.');
    } else if (price > _maxPrice) {
      errors.add('Price is too large.');
      price = null;
    }
  }

  // Discount.
  final discountText = field('discount_price');
  double? discount;
  if (discountText.isNotEmpty) {
    if (discountText.startsWith('-')) {
      errors.add('Discount price cannot be negative.');
    } else {
      discount = parseMoneyText(discountText);
      if (discount == null) {
        errors.add('Discount price "$discountText" is not a number.');
      } else if (discount > _maxPrice) {
        errors.add('Discount price is too large.');
        discount = null;
      } else if (price != null) {
        if (discount > price) {
          errors.add('Discount price must be lower than the price.');
        } else if (discount == price) {
          warnings.add('Discount price equals the price, so customers see no saving.');
        }
      }
    }
  }

  // Prep time.
  final prepText = field('prep_time_min');
  int? prep;
  if (prepText.isNotEmpty) {
    prep = _parseMinutes(prepText);
    if (prep == null || prep < 0 || prep > 600) {
      errors.add('Prep time "$prepText" must be a whole number of minutes from 0 to 600.');
      prep = null;
    }
  }

  // Labels.
  List<String>? labels;
  if (byField.containsKey('labels')) {
    final parsed = parseLabels(field('labels'));
    labels = parsed.ids;
    if (parsed.unknown.isNotEmpty) {
      warnings.add('Unknown label ignored: ${parsed.unknown.join(', ')}.');
    }
  }

  // Yes / no columns.
  final flags = <String, bool>{};
  for (final entry in const {
    'is_sold_out': 'Sold out',
    'is_active': 'Visible',
    'is_featured': 'Featured',
  }.entries) {
    final raw = field(entry.key);
    if (raw.isEmpty) continue;
    final flag = parseYesNo(raw);
    if (flag == null) {
      warnings.add('${entry.value} "$raw" is not yes or no, so it was ignored.');
    } else {
      flags[entry.key] = flag;
    }
  }

  if (errors.isNotEmpty) {
    return ImportRow(
      number: number,
      cells: cells,
      values: const {},
      errors: errors,
      warnings: warnings,
    );
  }

  for (final entry in text.entries) {
    if (entry.value.isNotEmpty) values[entry.key] = entry.value;
  }
  values['price'] = double.parse(price!.toStringAsFixed(2));
  if (discount != null) values['discount_price'] = double.parse(discount.toStringAsFixed(2));
  if (prep != null) values['prep_time_min'] = prep;
  if (labels != null) values['labels'] = labels;
  values.addAll(flags);

  return ImportRow(
    number: number,
    cells: cells,
    values: values,
    warnings: warnings,
  );
}

String _label(String key) {
  if (key.startsWith('category')) return 'category';
  if (key.startsWith('name')) return 'name';
  if (key.startsWith('short_description')) return 'short description';
  return 'description';
}

String _title(String key) {
  switch (key) {
    case 'category_en':
      return 'Category (English)';
    case 'category_bn':
      return 'Category (Bangla)';
    case 'name_en':
      return 'Name (English)';
    case 'name_bn':
      return 'Name (Bangla)';
    case 'short_description_en':
      return 'Short description (English)';
    case 'short_description_bn':
      return 'Short description (Bangla)';
    case 'description_en':
      return 'Description (English)';
    case 'description_bn':
      return 'Description (Bangla)';
    default:
      return 'SKU';
  }
}

String _dishKey(ImportRow row) {
  final category = (row.categoryEn ?? row.categoryBn ?? '').toLowerCase();
  final name = (row.nameEn ?? row.nameBn ?? '').toLowerCase();
  return '$category\u0000$name';
}

/// Adds a warning to rows that repeat an earlier SKU or dish in the same file:
/// the second one would overwrite the first.
List<ImportRow> _flagRepeats(List<ImportRow> rows) {
  final skuAt = <String, int>{};
  final dishAt = <String, int>{};
  final result = <ImportRow>[];
  for (final row in rows) {
    if (!row.isValid) {
      result.add(row);
      continue;
    }
    final extra = <String>[];
    final sku = row.sku;
    if (sku != null) {
      final first = skuAt[sku];
      if (first == null) {
        skuAt[sku] = row.number;
      } else {
        extra.add('SKU "$sku" is already used in row $first.');
      }
    }
    final key = _dishKey(row);
    final firstDish = dishAt[key];
    if (firstDish == null) {
      dishAt[key] = row.number;
    } else if (sku == null || skuAt[sku] != row.number) {
      extra.add('Same dish and category as row $firstDish.');
    }
    result.add(
      extra.isEmpty
          ? row
          : ImportRow(
              number: row.number,
              cells: row.cells,
              values: row.values,
              errors: row.errors,
              warnings: [...row.warnings, ...extra],
            ),
    );
  }
  return result;
}

// ---- predicting what the import will do ------------------------------------------

enum ImportAction { create, update, skip }

/// A valid row and what `import_menu_items` will do with it.
class PlannedRow {
  const PlannedRow(
    this.row,
    this.action, {
    this.notes = const [],
    this.newCategory = false,
  });

  final ImportRow row;
  final ImportAction action;

  /// Things worth knowing before an update, such as a dish moving category.
  final List<String> notes;

  /// The row's category does not exist yet and will be created.
  final bool newCategory;
}

class ImportPlan {
  const ImportPlan({
    this.rows = const [],
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.newCategories = const [],
  });

  final List<PlannedRow> rows;
  final int created;
  final int updated;
  final int skipped;

  /// Names of categories that will be created, in file order.
  final List<String> newCategories;

  int get total => created + updated + skipped;
  int get noteCount => rows.where((r) => r.notes.isNotEmpty).length;
}

class _Cat {
  const _Cat(this.id, this.en, this.bn, this.title);
  final String id;
  final String? en;
  final String? bn;
  final String title;
}

class _Dish {
  const _Dish(this.categoryId, this.en, this.bn, this.sku);
  final String categoryId;
  final String? en;
  final String? bn;
  final String? sku;
}

String? _lower(String? text) {
  final t = text?.trim();
  return t == null || t.isEmpty ? null : t.toLowerCase();
}

/// Mirrors how `import_menu_items` matches categories (top level only, by
/// English name ignoring case or by exact Bangla name) and dishes (by SKU,
/// else by name inside the category), including dishes created earlier in the
/// same file. [rows] should be the valid rows in file order.
ImportPlan planImport(
  List<ImportRow> rows, {
  required List<MenuItem> existingItems,
  required List<MenuCategory> existingCategories,
  required bool updateExisting,
}) {
  final categoryById = {for (final c in existingCategories) c.id: c};
  final cats = <_Cat>[
    for (final c in existingCategories)
      if (c.parentId == null && !c.isDeleted)
        _Cat(c.id, _lower(c.nameEn), _norm(c.nameBn), c.displayName),
  ];
  final dishes = <_Dish>[
    for (final i in existingItems)
      if (!i.isDeleted) _Dish(i.categoryId, _lower(i.nameEn), _norm(i.nameBn), _norm(i.sku)),
  ];
  final existingBySku = <String, MenuItem>{};
  for (final item in existingItems) {
    final sku = _norm(item.sku);
    if (!item.isDeleted && sku != null) existingBySku.putIfAbsent(sku, () => item);
  }
  final existingCount = dishes.length;

  var created = 0;
  var updated = 0;
  var skipped = 0;
  var virtualId = 0;
  final newCategories = <String>[];
  final planned = <PlannedRow>[];

  for (final row in rows) {
    final rowCatEn = _lower(row.categoryEn);
    final rowCatBn = _norm(row.categoryBn);
    _Cat? cat;
    var isNewCategory = false;
    for (final c in cats) {
      if ((rowCatEn != null && c.en == rowCatEn) || (rowCatBn != null && c.bn == rowCatBn)) {
        cat = c;
        break;
      }
    }
    if (cat == null) {
      cat = _Cat('new:${virtualId++}', rowCatEn, rowCatBn, row.categoryTitle);
      cats.add(cat);
      newCategories.add(row.categoryTitle);
      isNewCategory = true;
    }

    final sku = _norm(row.sku);
    final nameEn = _lower(row.nameEn);
    final nameBn = _norm(row.nameBn);

    var matchIndex = -1;
    if (sku != null) {
      matchIndex = dishes.indexWhere((d) => d.sku == sku);
    }
    if (matchIndex < 0) {
      matchIndex = dishes.indexWhere(
        (d) =>
            d.categoryId == cat!.id &&
            ((nameEn != null && d.en == nameEn) || (nameBn != null && d.bn == nameBn)),
      );
    }

    if (matchIndex < 0) {
      dishes.add(_Dish(cat.id, nameEn, nameBn, sku));
      created++;
      planned.add(PlannedRow(row, ImportAction.create, newCategory: isNewCategory));
      continue;
    }

    if (!updateExisting) {
      skipped++;
      planned.add(PlannedRow(row, ImportAction.skip));
      continue;
    }

    updated++;
    final notes = <String>[];
    if (matchIndex < existingCount) {
      final existing = _existingAt(existingItems, matchIndex, existingBySku, sku, cat.id, nameEn, nameBn);
      if (existing != null) {
        if (existing.categoryId != cat.id) {
          final from = categoryById[existing.categoryId]?.displayName ?? 'its category';
          notes.add('Moves from "$from" to "${cat.title}".');
        }
        if (existing.discountPrice != null && row.discountPrice == null) {
          notes.add('Clears the current discount price.');
        }
      }
    }
    planned.add(PlannedRow(row, ImportAction.update, notes: notes));
  }

  return ImportPlan(
    rows: planned,
    created: created,
    updated: updated,
    skipped: skipped,
    newCategories: newCategories,
  );
}

String? _norm(String? text) {
  final t = text?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// The stored dish behind a match, found the same way the SQL function finds it.
MenuItem? _existingAt(
  List<MenuItem> items,
  int matchIndex,
  Map<String, MenuItem> bySku,
  String? sku,
  String categoryId,
  String? nameEn,
  String? nameBn,
) {
  if (sku != null && bySku.containsKey(sku)) return bySku[sku];
  for (final item in items) {
    if (item.isDeleted || item.categoryId != categoryId) continue;
    if ((nameEn != null && _lower(item.nameEn) == nameEn) ||
        (nameBn != null && _norm(item.nameBn) == nameBn)) {
      return item;
    }
  }
  return null;
}

// ---- sending and results ----------------------------------------------------------

/// Splits [list] into pieces of at most [size].
List<List<T>> chunkList<T>(List<T> list, {int size = importChunkSize}) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
  }
  return chunks;
}

/// A problem tied to one row of the file.
class ImportIssue {
  const ImportIssue(this.row, this.message, {this.title = ''});

  /// Spreadsheet row number (the header is row 1); 0 when unknown.
  final int row;
  final String message;
  final String title;
}

/// Totals across all chunks of one import.
class ImportTally {
  const ImportTally({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.issues = const [],
  });

  final int created;
  final int updated;
  final int skipped;
  final List<ImportIssue> issues;

  int get failed => issues.length;
  int get saved => created + updated;

  /// Adds the answer for one chunk. The function numbers its errors from 1 in
  /// the order the rows were sent, so [sent] maps them back to file rows.
  ImportTally addChunk(ImportResult result, List<ImportRow> sent) {
    return ImportTally(
      created: created + result.created,
      updated: updated + result.updated,
      skipped: skipped + result.skipped,
      issues: [
        ...issues,
        for (final e in result.errors)
          ImportIssue(
            e.row >= 1 && e.row <= sent.length ? sent[e.row - 1].number : 0,
            e.message,
            title: e.row >= 1 && e.row <= sent.length ? sent[e.row - 1].title : '',
          ),
      ],
    );
  }

  /// A chunk that could not be sent at all: every row in it failed.
  ImportTally addFailedChunk(List<ImportRow> sent, String message) {
    return ImportTally(
      created: created,
      updated: updated,
      skipped: skipped,
      issues: [
        ...issues,
        for (final row in sent) ImportIssue(row.number, message, title: row.title),
      ],
    );
  }
}

/// Payload for `ImportRow`s, ready for `importItems`.
List<Map<String, dynamic>> importPayload(List<ImportRow> rows) => [
  for (final row in rows) Map<String, dynamic>.from(row.values),
];

/// Problems found while reading the file, one entry per bad row.
List<ImportIssue> readIssues(MenuCsvParse parse) => [
  for (final row in parse.rows)
    if (!row.isValid) ImportIssue(row.number, row.errors.join(' '), title: _rawTitle(row)),
];

String _rawTitle(ImportRow row) {
  for (final c in row.cells) {
    if (c.trim().isNotEmpty) return c.trim();
  }
  return '';
}

// ---- writing ---------------------------------------------------------------------

String _bool(bool value) => value ? 'yes' : 'no';

/// The whole menu as a spreadsheet, with a byte order mark so Excel shows
/// Bangla correctly. With [settings] the prices, sold-out state and visibility
/// are the ones customers of that branch see.
String buildMenuCsv({
  required List<MenuItem> items,
  required List<MenuCategory> categories,
  Map<String, BranchItemSetting>? settings,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final byId = {for (final c in categories) c.id: c};
  final rank = categoryRankOf(categories);

  final live = [for (final i in items) if (!i.isDeleted) i]
    ..sort((a, b) {
      final byRank = (rank[a.categoryId] ?? 1 << 30).compareTo(rank[b.categoryId] ?? 1 << 30);
      if (byRank != 0) return byRank;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  final rows = <List<String>>[
    [for (final f in menuCsvFields) f.header, _subcategoryHeader],
  ];
  for (final item in live) {
    final category = byId[item.categoryId];
    final parent = category?.parentId == null ? null : byId[category!.parentId];
    final top = parent ?? category;
    final setting = settings == null ? null : settings[item.id];
    final price = settings == null ? null : effectivePriceAt(item, setting);
    final shownPrice = price?.price ?? item.price;
    final shownDiscount = price == null ? item.discountPrice : price.discountPrice;
    final soldOut = settings == null ? item.isSoldOut : isSoldOutNow(item, setting, clock);
    final visible = settings == null ? item.isActive : isVisibleToCustomers(item, setting);

    final cells = <String, String>{
      'category_en': top?.nameEn ?? '',
      'category_bn': top?.nameBn ?? '',
      'name_en': item.nameEn ?? '',
      'name_bn': item.nameBn ?? '',
      'short_description_en': item.shortDescriptionEn ?? '',
      'short_description_bn': item.shortDescriptionBn ?? '',
      'description_en': item.descriptionEn ?? '',
      'description_bn': item.descriptionBn ?? '',
      'price': _num(shownPrice),
      'discount_price': shownDiscount == null ? '' : _num(shownDiscount),
      'prep_time_min': item.prepTimeMin == null ? '' : '${item.prepTimeMin}',
      'sku': item.sku ?? '',
      'labels': [for (final id in item.labels) menuTagName(menuLabels, id)].join('; '),
      'is_sold_out': _bool(soldOut),
      'is_active': _bool(visible),
      'is_featured': _bool(item.isFeatured),
    };
    rows.add([
      for (final f in menuCsvFields) cells[f.key] ?? '',
      parent == null ? '' : (category?.displayName ?? ''),
    ]);
  }
  return CsvCodec.encode(rows, bom: true);
}

/// A blank file with the right headers and two example dishes.
String buildTemplateCsv() {
  final rows = <List<String>>[
    [for (final f in menuCsvFields) f.header],
    [
      'Starters', 'স্টার্টার', 'Chicken Soup', 'চিকেন স্যুপ',
      'Hot and creamy', 'গরম ও ক্রিমি', '', '',
      '180', '160', '10', 'SOUP-01', 'Popular; Halal', 'no', 'yes', 'yes',
    ],
    [
      'Main Course', 'মেইন কোর্স', 'Beef Tehari', 'বিফ তেহারি',
      'Spiced rice with tender beef', 'কোমল গরুর মাংসের তেহারি', '', '',
      '280', '', '15', 'TEH-01', 'Spicy', 'no', 'yes', 'no',
    ],
  ];
  return CsvCodec.encode(rows, bom: true);
}

/// The rows that failed, with their original cells and a Problem column, so
/// the file can be fixed and uploaded again.
String buildErrorReportCsv(MenuCsvParse parse, List<ImportIssue> issues) {
  final byRow = <int, List<String>>{};
  for (final issue in issues) {
    byRow.putIfAbsent(issue.row, () => []).add(issue.message);
  }
  final rowByNumber = {for (final r in parse.rows) r.number: r};
  final width = parse.headers.length;
  final rows = <List<String>>[
    [...parse.headers, _problemHeader],
  ];
  final numbers = byRow.keys.toList()..sort();
  for (final number in numbers) {
    final source = rowByNumber[number];
    final cells = source == null
        ? List<String>.filled(width, '')
        : [
            for (var i = 0; i < width; i++) i < source.cells.length ? source.cells[i] : '',
          ];
    rows.add([...cells, byRow[number]!.join(' ')]);
  }
  return CsvCodec.encode(rows, bom: true, escapeFormulas: false);
}
