import 'package:flutter_test/flutter_test.dart';

import 'package:ez_menu/features/qr/qr_logic.dart';
import 'package:ez_menu/features/qr/qr_models.dart';

RestaurantTable _table(String id, String name, {String? zone, int order = 0, int? cap}) =>
    RestaurantTable(
      id: id,
      branchId: 'b1',
      name: name,
      zone: zone,
      sortOrder: order,
      capacity: cap,
    );

QrCode _code(
  String id,
  QrKind kind, {
  String? tableId,
  bool active = true,
  int scans = 0,
  String? label,
}) => QrCode(
  id: id,
  businessId: 'biz',
  branchId: 'b1',
  tableId: tableId,
  kind: kind,
  token: 'tok-$id',
  isActive: active,
  scanCount: scans,
  label: label,
);

void main() {
  group('naturalCompare', () {
    test('digit runs compare by value', () {
      expect(naturalCompare('T2', 'T10') < 0, isTrue);
      expect(naturalCompare('T10', 'T2') > 0, isTrue);
      expect(naturalCompare('T2', 't2'), 0);
    });

    test('shorter prefix sorts first', () {
      expect(naturalCompare('T', 'T1') < 0, isTrue);
      expect(naturalCompare('A1', 'B1') < 0, isTrue);
    });

    test('sorts a typical table list', () {
      final names = ['T10', 'T2', 'T1', 'T11', 'T3']..sort(naturalCompare);
      expect(names, ['T1', 'T2', 'T3', 'T10', 'T11']);
    });
  });

  group('groupTablesByZone', () {
    test('named zones first alphabetically, no zone last', () {
      final groups = groupTablesByZone([
        _table('1', 'T1'),
        _table('2', 'R1', zone: 'Rooftop'),
        _table('3', 'G1', zone: 'ground floor'),
        _table('4', 'G2', zone: 'Ground Floor'),
      ]);
      expect(groups.map((g) => g.title).toList(), ['ground floor', 'Rooftop', 'No zone']);
      expect(groups.first.tables.length, 2);
    });

    test('tables inside a zone follow display order then name', () {
      final groups = groupTablesByZone([
        _table('1', 'T10', zone: 'A', order: 1),
        _table('2', 'T2', zone: 'A', order: 1),
        _table('3', 'T5', zone: 'A', order: 0),
      ]);
      expect(groups.single.tables.map((t) => t.name).toList(), ['T5', 'T2', 'T10']);
    });

    test('blank zones count as no zone', () {
      final groups = groupTablesByZone([_table('1', 'T1', zone: '   ')]);
      expect(groups.single.zone, isNull);
      expect(groups.single.title, 'No zone');
    });

    test('empty list gives no groups', () {
      expect(groupTablesByZone(const []), isEmpty);
    });
  });

  group('zones and order', () {
    test('suggestions are unique, ignoring case', () {
      expect(
        zoneSuggestions([
          _table('1', 'a', zone: 'Rooftop'),
          _table('2', 'b', zone: 'rooftop'),
          _table('3', 'c', zone: 'AC Zone'),
          _table('4', 'd'),
        ]),
        ['AC Zone', 'Rooftop'],
      );
    });

    test('nextSortOrder', () {
      expect(nextSortOrder(const []), 0);
      expect(nextSortOrder([_table('1', 'a', order: 4), _table('2', 'b', order: 2)]), 5);
    });
  });

  group('validation', () {
    test('table name', () {
      expect(validateTableName(''), isNotNull);
      expect(validateTableName('   '), isNotNull);
      expect(validateTableName('T1'), isNull);
      expect(validateTableName('x' * 61), isNotNull);
      expect(validateTableName('x' * 60), isNull);
    });

    test('capacity is optional but must be 1 to 100', () {
      expect(validateCapacity(''), isNull);
      expect(validateCapacity(null), isNull);
      expect(validateCapacity('4'), isNull);
      expect(validateCapacity('0'), isNotNull);
      expect(validateCapacity('101'), isNotNull);
      expect(validateCapacity('two'), isNotNull);
      expect(parseCapacity('6'), 6);
      expect(parseCapacity(''), isNull);
      expect(parseCapacity('abc'), isNull);
    });

    test('zone length', () {
      expect(validateZone(null), isNull);
      expect(validateZone('x' * 61), isNotNull);
    });

    test('tableNameTaken ignores case, spaces and the table being edited', () {
      final tables = [_table('1', 'T1'), _table('2', 'Window')];
      expect(tableNameTaken(' t1 ', tables), isTrue);
      expect(tableNameTaken('T3', tables), isFalse);
      expect(tableNameTaken('T1', tables, exceptId: '1'), isFalse);
    });
  });

  group('planBulkTables', () {
    test('creates a numbered run', () {
      final plan = planBulkTables(prefix: 'T', start: 1, count: 5, existingNames: const []);
      expect(plan.names, ['T1', 'T2', 'T3', 'T4', 'T5']);
      expect(plan.toCreate.length, 5);
      expect(plan.canCreate, isTrue);
      expect(plan.rangeText, 'T1 to T5');
    });

    test('pads numbers', () {
      final plan = planBulkTables(
        prefix: 'T',
        start: 8,
        count: 3,
        existingNames: const [],
        padTo: 2,
      );
      expect(plan.names, ['T08', 'T09', 'T10']);
    });

    test('flags names that already exist and skips them', () {
      final plan = planBulkTables(
        prefix: 'T',
        start: 1,
        count: 4,
        existingNames: const ['t2', ' T3 '],
      );
      expect(plan.conflicts, ['T2', 'T3']);
      expect(plan.toCreate, ['T1', 'T4']);
      expect(plan.canCreate, isTrue);
    });

    test('nothing left to create when all exist', () {
      final plan = planBulkTables(
        prefix: 'T',
        start: 1,
        count: 2,
        existingNames: const ['T1', 'T2'],
      );
      expect(plan.canCreate, isFalse);
      expect(plan.error, isNull);
    });

    test('rejects bad input', () {
      expect(planBulkTables(prefix: 'T', start: 1, count: 0, existingNames: const []).error, isNotNull);
      expect(planBulkTables(prefix: 'T', start: 1, count: 101, existingNames: const []).error, isNotNull);
      expect(planBulkTables(prefix: 'T', start: -1, count: 2, existingNames: const []).error, isNotNull);
      expect(planBulkTables(prefix: 'T', start: 10000, count: 2, existingNames: const []).error, isNotNull);
      expect(
        planBulkTables(prefix: 'x' * 59, start: 100, count: 2, existingNames: const []).error,
        isNotNull,
      );
    });

    test('works without a prefix and for a single table', () {
      final plan = planBulkTables(prefix: '', start: 7, count: 1, existingNames: const []);
      expect(plan.names, ['7']);
      expect(plan.rangeText, '7');
    });
  });

  group('labels and file names', () {
    test('display names', () {
      expect(qrDisplayName(_code('1', QrKind.branch), null), 'Branch menu');
      expect(qrDisplayName(_code('1', QrKind.takeaway), null), 'Takeaway counter');
      expect(qrDisplayName(_code('1', QrKind.branch, label: 'Main entrance'), null), 'Main entrance');
      expect(
        qrDisplayName(_code('1', QrKind.table, tableId: 't'), _table('t', '5')),
        'Table 5',
      );
      expect(qrDisplayName(_code('1', QrKind.table, tableId: 't'), null), 'Table');
    });

    test('file names are url safe', () {
      expect(
        qrFileName(kind: QrKind.table, branchName: 'Gulshan Branch', tableName: 'T 5'),
        'gulshan-branch-table-t-5-qr',
      );
      expect(qrFileName(kind: QrKind.branch, branchName: 'Gulshan'), 'gulshan-menu-qr');
      expect(qrFileName(kind: QrKind.takeaway, branchName: 'Gulshan'), 'gulshan-takeaway-qr');
    });

    test('print file name', () {
      expect(qrPrintFileName('Gulshan Branch'), 'gulshan-branch-qr-codes');
      expect(qrPrintFileName('গুলশান'), 'ez-menu-qr-codes');
    });

    test('Bangla names fall back to a plain word', () {
      expect(qrFileName(kind: QrKind.branch, branchName: 'গুলশান'), 'ez-menu-menu-qr');
      expect(
        qrFileName(kind: QrKind.table, branchName: 'Gulshan', tableName: 'টেবিল'),
        'gulshan-table-qr',
      );
    });
  });

  group('scans', () {
    final now = DateTime(2026, 11, 22, 12);

    test('relativeTime', () {
      expect(relativeTime(now, now), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 1)), now), '1 minute ago');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now), '5 minutes ago');
      expect(relativeTime(now.subtract(const Duration(hours: 1)), now), '1 hour ago');
      expect(relativeTime(now.subtract(const Duration(hours: 5)), now), '5 hours ago');
      expect(relativeTime(now.subtract(const Duration(days: 2)), now), '2 days ago');
      expect(relativeTime(now.subtract(const Duration(days: 65)), now), '2 months ago');
      expect(relativeTime(now.subtract(const Duration(days: 800)), now), '2 years ago');
      expect(relativeTime(now.add(const Duration(hours: 1)), now), 'just now');
    });

    test('scanSummary', () {
      expect(scanSummary(0, null, now), 'No scans yet');
      expect(scanSummary(1, null, now), '1 scan');
      expect(scanSummary(42, now.subtract(const Duration(days: 3)), now), '42 scans, last 3 days ago');
    });
  });

  group('print layout', () {
    test('grids for the four choices', () {
      expect(printGridFor(1).columns, 1);
      expect(printGridFor(1).rows, 1);
      expect(printGridFor(2).rows, 2);
      expect(printGridFor(4).columns, 2);
      expect(printGridFor(4).rows, 2);
      expect(printGridFor(6).columns, 2);
      expect(printGridFor(6).rows, 3);
      expect(printGridFor(99).perPage, 4);
    });

    test('cards fill the page inside the margins', () {
      for (final n in printCardsPerPage) {
        final grid = printGridFor(n);
        expect(grid.cardWidth * grid.columns, closeTo(a4Width - printMargin * 2, 0.001));
        expect(grid.cardHeight * grid.rows, closeTo(a4Height - printMargin * 2, 0.001));
        expect(grid.perPage, n);
      }
    });

    test('card pictures match their cell and stay sharp but small', () {
      for (final n in printCardsPerPage) {
        final grid = printGridFor(n);
        final aspect = printCardAspect(grid);
        final width = grid.cardWidth - printCardInset * 2;
        final height = grid.cardHeight - printCardInset * 2;
        expect(aspect, closeTo(width / height, 0.0001));
        final pixels = printCardPixelWidth(grid);
        expect(pixels, inInclusiveRange(400, 1600));
      }
      expect(printCardAspect(printGridFor(1)), lessThan(1));
      expect(printCardAspect(printGridFor(2)), greaterThan(1.25));
      expect(printCardPixelWidth(printGridFor(1)), 1600);
    });

    test('paginate and pageCount agree', () {
      final items = List.generate(7, (i) => i);
      final pages = paginate(items, 4);
      expect(pages.length, 2);
      expect(pages.first, [0, 1, 2, 3]);
      expect(pages.last, [4, 5, 6]);
      expect(pageCount(7, 4), 2);
      expect(pageCount(8, 4), 2);
      expect(pageCount(0, 4), 0);
      expect(paginate(const <int>[], 4), isEmpty);
    });
  });

  group('resolvePrintTargets', () {
    final tables = [
      _table('t1', '10', zone: 'Rooftop', order: 1),
      _table('t2', '2', order: 1),
      _table('t3', '3', order: 0),
    ];
    final overview = QrOverview.fromRows(
      tables: tables,
      codes: [
        _code('b', QrKind.branch),
        _code('tk', QrKind.takeaway),
        _code('c1', QrKind.table, tableId: 't1'),
        _code('c2', QrKind.table, tableId: 't2'),
      ],
    );

    test('branch, takeaway, then tables in display order', () {
      final targets = resolvePrintTargets(
        selection: const PrintSelection(includeBranch: true, includeTakeaway: true, allTables: true),
        overview: overview,
        branchName: 'Gulshan',
      );
      expect(targets.map((t) => t.title).toList(), [
        'Gulshan',
        'Takeaway counter',
        'Table 2',
        'Table 10',
      ]);
      expect(targets[3].subtitle, 'Rooftop');
      expect(targets[2].subtitle, 'Gulshan');
    });

    test('tables without an active code are left out', () {
      final targets = resolvePrintTargets(
        selection: const PrintSelection(allTables: true),
        overview: overview,
        branchName: 'Gulshan',
      );
      expect(targets.length, 2);
    });

    test('picked tables only', () {
      final targets = resolvePrintTargets(
        selection: const PrintSelection(pickedTableIds: {'t1'}),
        overview: overview,
        branchName: 'Gulshan',
      );
      expect(targets.single.title, 'Table 10');
    });

    test('nothing selected prints nothing', () {
      expect(
        resolvePrintTargets(selection: const PrintSelection(), overview: overview, branchName: 'G'),
        isEmpty,
      );
    });
  });

  group('printTargetFor', () {
    test('branch, takeaway and table cards', () {
      final branch = printTargetFor(_code('b', QrKind.branch), null, 'Gulshan');
      expect(branch.title, 'Gulshan');
      expect(branch.subtitle, isNull);

      final takeaway = printTargetFor(_code('tk', QrKind.takeaway), null, 'Gulshan');
      expect(takeaway.title, 'Takeaway counter');
      expect(takeaway.subtitle, 'Gulshan');

      final table = printTargetFor(
        _code('c1', QrKind.table, tableId: 't1'),
        _table('t1', ' 5 ', zone: 'Rooftop'),
        'Gulshan',
      );
      expect(table.title, 'Table 5');
      expect(table.subtitle, 'Rooftop');
    });

    test('a table card without its table still has a title', () {
      final target = printTargetFor(_code('c1', QrKind.table, tableId: 't1'), null, 'Gulshan');
      expect(target.title, 'Table');
      expect(target.subtitle, 'Gulshan');
    });
  });

  group('suggestNextTableName', () {
    test('first table is T1', () {
      expect(suggestNextTableName(const <String>[]), 'T1');
    });

    test('continues the highest number, ignoring order of input', () {
      expect(suggestNextTableName(['T2', 'T10', 'T1']), 'T11');
    });

    test('keeps zero padding', () {
      expect(suggestNextTableName(['T08', 'T09']), 'T10');
      expect(suggestNextTableName(['T01']), 'T02');
    });

    test('plain numbers work', () {
      expect(suggestNextTableName(['1', '2', '3']), '4');
    });

    test('skips a name that is already taken', () {
      expect(suggestNextTableName(['T1', 'T2', 'T3', 'T3']), 'T4');
    });

    test('names without a trailing number give no suggestion', () {
      expect(suggestNextTableName(['Window', 'Bar']), '');
    });

    test('mixed names continue the last numbered one', () {
      expect(suggestNextTableName(['Bar', 'T4']), 'T5');
    });

    test('a suggestion never exceeds the name limit', () {
      final long = '${'x' * 59}9';
      expect(suggestNextTableName([long]), '');
    });
  });

  group('QrOverview.fromRows', () {
    test('keeps active codes and counts the rest', () {
      final overview = QrOverview.fromRows(
        tables: [_table('t1', '1')],
        codes: [
          _code('b1', QrKind.branch, scans: 5),
          _code('b0', QrKind.branch, active: false, scans: 100),
          _code('tk', QrKind.takeaway, scans: 2),
          _code('c1', QrKind.table, tableId: 't1', scans: 3),
        ],
      );
      expect(overview.branchCode?.id, 'b1');
      expect(overview.takeawayCode?.id, 'tk');
      expect(overview.tableCodes['t1']?.id, 'c1');
      expect(overview.inactiveCodes, 1);
      expect(overview.totalScans, 10);
      expect(overview.activeCodes, 3);
    });

    test('empty overview', () {
      final overview = QrOverview.fromRows(tables: const [], codes: const []);
      expect(overview.branchCode, isNull);
      expect(overview.activeCodes, 0);
      expect(overview.totalScans, 0);
    });
  });

  group('models', () {
    test('QrCode.fromJson', () {
      final code = QrCode.fromJson({
        'id': 'q1',
        'business_id': 'biz',
        'branch_id': 'b1',
        'table_id': 't1',
        'kind': 'table',
        'token': 'abc',
        'label': 'Window',
        'is_active': true,
        'scan_count': 7,
        'last_scanned_at': '2026-11-20T10:00:00Z',
      });
      expect(code.kind, QrKind.table);
      expect(code.tableId, 't1');
      expect(code.scanCount, 7);
      expect(code.lastScannedAt, isNotNull);
      expect(code.deactivatedAt, isNull);
    });

    test('unknown kind falls back to branch', () {
      expect(QrKind.parse('weird'), QrKind.branch);
      expect(QrKind.parse(null), QrKind.branch);
      expect(QrKind.parse('takeaway'), QrKind.takeaway);
    });

    test('RestaurantTable round trip', () {
      final table = RestaurantTable.fromJson({
        'id': 't1',
        'branch_id': 'b1',
        'name': 'T1',
        'capacity': 4,
        'zone': 'Rooftop',
        'is_active': false,
        'sort_order': 3,
      });
      expect(table.capacity, 4);
      expect(table.isActive, isFalse);
      final json = table.toWriteJson();
      expect(json['name'], 'T1');
      expect(json['sort_order'], 3);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('branch_id'), isFalse);
    });
  });
}
