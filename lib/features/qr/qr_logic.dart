import '../../core/logic/slug.dart';
import 'qr_models.dart';

/// Pure logic for the QR and tables screens: grouping, sorting, bulk table
/// names, validation, file names, print layout and relative times. No Flutter
/// imports, so it is unit tested.

// ---- names and sorting ----------------------------------------------------------

/// Compares "T2" and "T10" the way a person would: digit runs by value.
int naturalCompare(String a, String b) {
  final left = _chunks(a.toLowerCase());
  final right = _chunks(b.toLowerCase());
  final shared = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < shared; i++) {
    final x = left[i];
    final y = right[i];
    final xNum = int.tryParse(x);
    final yNum = int.tryParse(y);
    final int result;
    if (xNum != null && yNum != null) {
      result = xNum.compareTo(yNum);
    } else {
      result = x.compareTo(y);
    }
    if (result != 0) return result;
  }
  return left.length.compareTo(right.length);
}

List<String> _chunks(String text) {
  final parts = <String>[];
  final buffer = StringBuffer();
  bool? digits;
  for (final unit in text.codeUnits) {
    final isDigit = unit >= 0x30 && unit <= 0x39;
    if (digits != null && isDigit != digits) {
      parts.add(buffer.toString());
      buffer.clear();
    }
    digits = isDigit;
    buffer.writeCharCode(unit);
  }
  if (buffer.isNotEmpty) parts.add(buffer.toString());
  return parts;
}

/// Display order of tables: the order set by the owner, then by name.
int compareTables(RestaurantTable a, RestaurantTable b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  return byOrder != 0 ? byOrder : naturalCompare(a.name, b.name);
}

/// Tables of one zone, in display order.
class TableZoneGroup {
  const TableZoneGroup({required this.zone, required this.tables});

  /// Null for tables without a zone.
  final String? zone;
  final List<RestaurantTable> tables;

  String get title => zone ?? 'No zone';
}

String? _cleanZone(String? zone) {
  final trimmed = zone?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Groups tables by zone. Named zones come first (alphabetically, ignoring
/// case), tables without a zone last.
List<TableZoneGroup> groupTablesByZone(List<RestaurantTable> tables) {
  final byZone = <String, List<RestaurantTable>>{};
  final names = <String, String>{};
  final loose = <RestaurantTable>[];
  for (final table in tables) {
    final zone = _cleanZone(table.zone);
    if (zone == null) {
      loose.add(table);
      continue;
    }
    final key = zone.toLowerCase();
    names.putIfAbsent(key, () => zone);
    byZone.putIfAbsent(key, () => []).add(table);
  }
  final keys = byZone.keys.toList()..sort(naturalCompare);
  return [
    for (final key in keys)
      TableZoneGroup(zone: names[key], tables: byZone[key]!..sort(compareTables)),
    if (loose.isNotEmpty) TableZoneGroup(zone: null, tables: loose..sort(compareTables)),
  ];
}

/// Zones already in use, for the suggestions in the table form.
List<String> zoneSuggestions(List<RestaurantTable> tables) {
  final seen = <String, String>{};
  for (final table in tables) {
    final zone = _cleanZone(table.zone);
    if (zone != null) seen.putIfAbsent(zone.toLowerCase(), () => zone);
  }
  final zones = seen.values.toList()..sort(naturalCompare);
  return zones;
}

/// One more than the highest display order, for a new table.
int nextSortOrder(List<RestaurantTable> tables) {
  var highest = -1;
  for (final table in tables) {
    if (table.sortOrder > highest) highest = table.sortOrder;
  }
  return highest + 1;
}

// ---- table form validation ------------------------------------------------------------

const int tableNameMaxLength = 60;
const int tableZoneMaxLength = 60;
const int tableCapacityMax = 100;
const int bulkTablesMax = 100;

String? validateTableName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Enter a table name or number.';
  if (name.length > tableNameMaxLength) {
    return 'Keep the name under $tableNameMaxLength characters.';
  }
  return null;
}

String? validateZone(String? value) {
  if ((value ?? '').trim().length > tableZoneMaxLength) {
    return 'Keep the zone under $tableZoneMaxLength characters.';
  }
  return null;
}

/// Empty is allowed (capacity is optional).
String? validateCapacity(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final number = int.tryParse(text);
  if (number == null) return 'Enter a whole number.';
  if (number < 1 || number > tableCapacityMax) {
    return 'Capacity must be between 1 and $tableCapacityMax.';
  }
  return null;
}

/// Parses a capacity field; null when empty or invalid.
int? parseCapacity(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final number = int.tryParse(text);
  if (number == null || number < 1 || number > tableCapacityMax) return null;
  return number;
}

/// True when [name] is already used by another table of the branch. Names are
/// compared ignoring case and surrounding spaces.
bool tableNameTaken(String name, Iterable<RestaurantTable> tables, {String? exceptId}) {
  final key = name.trim().toLowerCase();
  for (final table in tables) {
    if (table.id == exceptId) continue;
    if (table.name.trim().toLowerCase() == key) return true;
  }
  return false;
}

/// The name to offer for the next table: "T6" after "T5", keeping the zero
/// padding ("T09" gives "T10"). "T1" for the first table. Empty when the
/// existing names do not end in a number, so there is nothing to continue.
String suggestNextTableName(Iterable<String> existingNames) {
  final names = [
    for (final name in existingNames)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (names.isEmpty) return 'T1';
  final pattern = RegExp(r'^(.*?)(\d+)$');
  final numbered = [
    for (final name in names)
      if (pattern.hasMatch(name)) name,
  ]..sort(naturalCompare);
  if (numbered.isEmpty) return '';
  final taken = {for (final name in names) name.toLowerCase()};
  final match = pattern.firstMatch(numbered.last)!;
  final prefix = match.group(1)!;
  final digits = match.group(2)!;
  final width = digits.startsWith('0') ? digits.length : 0;
  var number = int.parse(digits);
  for (var i = 0; i < 10000; i++) {
    number++;
    final candidate = '$prefix${number.toString().padLeft(width, '0')}';
    if (!taken.contains(candidate.toLowerCase())) {
      return candidate.length > tableNameMaxLength ? '' : candidate;
    }
  }
  return '';
}

// ---- adding several tables at once ----------------------------------------------------

class BulkTablePlan {
  const BulkTablePlan({
    this.names = const [],
    this.conflicts = const [],
    this.error,
  });

  /// Names that will be created, in order.
  final List<String> names;

  /// Names that already exist in the branch (these are not created).
  final List<String> conflicts;

  /// Why nothing can be created; null when the input is fine.
  final String? error;

  List<String> get toCreate => [
    for (final name in names)
      if (!conflicts.contains(name)) name,
  ];

  bool get canCreate => error == null && toCreate.isNotEmpty;

  /// "T1 to T10", or the single name.
  String get rangeText {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.first} to ${names.last}';
  }
}

/// Plans names such as T1, T2, T3. [padTo] pads the number with zeros (T01).
BulkTablePlan planBulkTables({
  required String prefix,
  required int start,
  required int count,
  required Iterable<String> existingNames,
  int padTo = 0,
}) {
  final cleanPrefix = prefix.trim();
  if (count < 1) return const BulkTablePlan(error: 'Add at least one table.');
  if (count > bulkTablesMax) {
    return const BulkTablePlan(error: 'Add up to $bulkTablesMax tables at a time.');
  }
  if (start < 0 || start > 9999) {
    return const BulkTablePlan(error: 'Start from a number between 0 and 9999.');
  }
  final names = <String>[];
  for (var i = 0; i < count; i++) {
    final number = (start + i).toString().padLeft(padTo < 0 ? 0 : padTo, '0');
    final name = '$cleanPrefix$number';
    if (name.length > tableNameMaxLength) {
      return const BulkTablePlan(error: 'The names would be too long. Use a shorter prefix.');
    }
    names.add(name);
  }
  final existing = {for (final name in existingNames) name.trim().toLowerCase()};
  return BulkTablePlan(
    names: names,
    conflicts: [
      for (final name in names)
        if (existing.contains(name.toLowerCase())) name,
    ],
  );
}

// ---- labels and file names --------------------------------------------------------------------

String qrKindLabel(QrKind kind) {
  switch (kind) {
    case QrKind.branch:
      return 'Branch menu';
    case QrKind.takeaway:
      return 'Takeaway counter';
    case QrKind.table:
      return 'Table';
  }
}

/// The name shown for a code: the table name, or the label, or the kind.
String qrDisplayName(QrCode code, RestaurantTable? table) {
  if (code.kind == QrKind.table) {
    final name = table?.name.trim();
    if (name != null && name.isNotEmpty) return 'Table $name';
  }
  final label = code.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  return qrKindLabel(code.kind);
}

/// File name without extension: `gulshan-table-5`, `gulshan-takeaway`.
String qrFileName({
  required QrKind kind,
  required String branchName,
  String? tableName,
}) {
  final branch = slugify(branchName, maxLength: 24);
  final base = branch.isEmpty ? 'ez-menu' : branch;
  switch (kind) {
    case QrKind.branch:
      return '$base-menu-qr';
    case QrKind.takeaway:
      return '$base-takeaway-qr';
    case QrKind.table:
      final table = slugify(tableName ?? '', maxLength: 24);
      return table.isEmpty ? '$base-table-qr' : '$base-table-$table-qr';
  }
}

/// File name (no extension) for a PDF with many cards: `gulshan-qr-codes`.
String qrPrintFileName(String branchName) {
  final branch = slugify(branchName, maxLength: 24);
  return '${branch.isEmpty ? 'ez-menu' : branch}-qr-codes';
}

/// Printed on every card, English first.
const String qrInstructionEnglish = 'Scan to view the menu';
const String qrInstructionBangla = 'মেনু দেখতে স্ক্যান করুন';

// ---- scans -------------------------------------------------------------------------------------

String _plural(int n, String one, String many) => n == 1 ? one : many;

/// "just now", "5 minutes ago", "2 days ago", "3 months ago".
String relativeTime(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.isNegative || diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return '$m ${_plural(m, 'minute', 'minutes')} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} ${_plural(diff.inHours, 'hour', 'hours')} ago';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays} ${_plural(diff.inDays, 'day', 'days')} ago';
  }
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    return '$months ${_plural(months, 'month', 'months')} ago';
  }
  final years = diff.inDays ~/ 365;
  return '$years ${_plural(years, 'year', 'years')} ago';
}

/// "No scans yet", "1 scan, last just now", "42 scans, last 3 days ago".
String scanSummary(int count, DateTime? last, DateTime now) {
  if (count <= 0) return 'No scans yet';
  final base = '$count ${_plural(count, 'scan', 'scans')}';
  return last == null ? base : '$base, last ${relativeTime(last, now)}';
}

// ---- printing ------------------------------------------------------------------------------------

/// Cards per A4 page that the print screen offers.
const List<int> printCardsPerPage = [1, 2, 4, 6];

/// A4 in PDF points.
const double a4Width = 595.28;
const double a4Height = 841.89;
const double printMargin = 28;

class PrintGrid {
  const PrintGrid({
    required this.perPage,
    required this.columns,
    required this.rows,
    required this.cardWidth,
    required this.cardHeight,
  });

  final int perPage;
  final int columns;
  final int rows;
  final double cardWidth;
  final double cardHeight;

  double get aspectRatio => cardWidth / cardHeight;
}

/// Grid for a number of cards per page. Unknown numbers fall back to 4.
PrintGrid printGridFor(int perPage) {
  final (int columns, int rows) = switch (perPage) {
    1 => (1, 1),
    2 => (1, 2),
    6 => (2, 3),
    _ => (2, 2),
  };
  final usedPerPage = columns * rows;
  return PrintGrid(
    perPage: usedPerPage,
    columns: columns,
    rows: rows,
    cardWidth: (a4Width - printMargin * 2) / columns,
    cardHeight: (a4Height - printMargin * 2) / rows,
  );
}

/// Space kept between the dashed cut line and the card inside each cell.
const double printCardInset = 6;

/// Width over height of the card picture that fills one cell of [grid].
double printCardAspect(PrintGrid grid) {
  final width = grid.cardWidth - printCardInset * 2;
  final height = grid.cardHeight - printCardInset * 2;
  return height <= 0 ? 0.7 : width / height;
}

/// Pixel width of a card picture: about 250 dpi, never more than 1600 pixels.
int printCardPixelWidth(PrintGrid grid) {
  final pixels = ((grid.cardWidth - printCardInset * 2) * 3.5).round();
  return pixels > 1600 ? 1600 : (pixels < 400 ? 400 : pixels);
}

/// Splits [items] into pages of [perPage].
List<List<T>> paginate<T>(List<T> items, int perPage) {
  final size = perPage < 1 ? 1 : perPage;
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

int pageCount(int itemCount, int perPage) =>
    itemCount == 0 ? 0 : ((itemCount + perPage - 1) ~/ perPage);

/// One card to print.
class PrintTarget {
  const PrintTarget({
    required this.code,
    required this.title,
    this.subtitle,
  });

  final QrCode code;

  /// Big text on the card: "Table 5", "Takeaway counter" or the branch.
  final String title;

  /// Small text on the card: the zone or the branch name.
  final String? subtitle;
}

/// The card text for one code: the branch name for the branch code, "Takeaway
/// counter" with the branch under it, and "Table 5" with its zone (or the
/// branch) under it.
PrintTarget printTargetFor(QrCode code, RestaurantTable? table, String branchName) {
  switch (code.kind) {
    case QrKind.branch:
      return PrintTarget(code: code, title: branchName);
    case QrKind.takeaway:
      return PrintTarget(code: code, title: 'Takeaway counter', subtitle: branchName);
    case QrKind.table:
      final name = table?.name.trim();
      final label = code.label?.trim();
      final title = (name != null && name.isNotEmpty)
          ? 'Table $name'
          : ((label != null && label.isNotEmpty) ? label : 'Table');
      return PrintTarget(
        code: code,
        title: title,
        subtitle: _cleanZone(table?.zone) ?? branchName,
      );
  }
}

/// What to print: the branch code, the takeaway code, all tables or a pick.
class PrintSelection {
  const PrintSelection({
    this.includeBranch = false,
    this.includeTakeaway = false,
    this.allTables = false,
    this.pickedTableIds = const {},
  });

  final bool includeBranch;
  final bool includeTakeaway;
  final bool allTables;
  final Set<String> pickedTableIds;

  PrintSelection copyWith({
    bool? includeBranch,
    bool? includeTakeaway,
    bool? allTables,
    Set<String>? pickedTableIds,
  }) => PrintSelection(
    includeBranch: includeBranch ?? this.includeBranch,
    includeTakeaway: includeTakeaway ?? this.includeTakeaway,
    allTables: allTables ?? this.allTables,
    pickedTableIds: pickedTableIds ?? this.pickedTableIds,
  );
}

/// Cards to print for [selection], in a stable order: branch, takeaway, then
/// tables in display order. Tables without an active code are left out.
List<PrintTarget> resolvePrintTargets({
  required PrintSelection selection,
  required QrOverview overview,
  required String branchName,
}) {
  final targets = <PrintTarget>[];
  final branch = overview.branchCode;
  if (selection.includeBranch && branch != null) {
    targets.add(printTargetFor(branch, null, branchName));
  }
  final takeaway = overview.takeawayCode;
  if (selection.includeTakeaway && takeaway != null) {
    targets.add(printTargetFor(takeaway, null, branchName));
  }
  final tables = [...overview.tables]..sort(compareTables);
  for (final table in tables) {
    final code = overview.tableCodes[table.id];
    if (code == null) continue;
    final wanted = selection.allTables || selection.pickedTableIds.contains(table.id);
    if (!wanted) continue;
    targets.add(printTargetFor(code, table, branchName));
  }
  return targets;
}
