import 'package:flutter_test/flutter_test.dart';

import 'package:ez_menu/core/logic/menu_csv.dart';
import 'package:ez_menu/features/menu/import_export_state.dart';
import 'package:ez_menu/features/menu/menu_models.dart';

const String _header =
    'Category (English),Name (English),Price,Discount price,Item code\n';

MenuCsvParse _parse(String body) => parseMenuCsv('$_header$body');

ImportPlan _plan(MenuCsvParse parse, {bool update = true}) => planImport(
  parse.validRows,
  existingItems: const <MenuItem>[],
  existingCategories: const <MenuCategory>[],
  updateExisting: update,
);

String _rows(int count) => [
  for (var i = 1; i <= count; i++) 'Main,Dish $i,${100 + i},,C$i',
].join('\n');

void main() {
  group('checkImportFile', () {
    test('accepts csv, tsv and txt in any case', () {
      expect(checkImportFile(name: 'menu.csv', size: 100), isNull);
      expect(checkImportFile(name: 'MENU.TSV', size: 100), isNull);
      expect(checkImportFile(name: 'menu.txt', size: 100), isNull);
    });

    test('explains spreadsheet files', () {
      final message = checkImportFile(name: 'menu.xlsx', size: 100);
      expect(message, isNotNull);
      expect(message, contains('CSV UTF-8'));
    });

    test('rejects other types, empty and oversized files', () {
      expect(checkImportFile(name: 'menu.pdf', size: 100), contains('.pdf'));
      expect(checkImportFile(name: 'menu.csv', size: 0), 'The file is empty.');
      expect(
        checkImportFile(name: 'menu.csv', size: importMaxFileBytes + 1),
        contains('split bigger menus'),
      );
    });

    test('a name without extension is let through', () {
      expect(checkImportFile(name: 'menu', size: 10), isNull);
    });
  });

  group('formatFileSize', () {
    test('uses B, KB and MB', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2 KB');
      expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('decodeImportBytes', () {
    test('reads plain UTF-8 and strips the byte order mark', () {
      final plain = decodeImportBytes([0x61, 0x62]);
      expect(plain.text, 'ab');
      expect(plain.encoding, 'UTF-8');
      final withBom = decodeImportBytes([0xEF, 0xBB, 0xBF, 0x61]);
      expect(withBom.text, 'a');
      expect(withBom.hadBadCharacters, isFalse);
    });

    test('reads UTF-16 little and big endian', () {
      final le = decodeImportBytes([0xFF, 0xFE, 0x61, 0x00, 0x62, 0x00]);
      expect(le.text, 'ab');
      expect(le.encoding, 'UTF-16');
      final be = decodeImportBytes([0xFE, 0xFF, 0x00, 0x61, 0x00, 0x62]);
      expect(be.text, 'ab');
    });

    test('flags bytes that are not valid text', () {
      final result = decodeImportBytes([0x61, 0xFF, 0x62]);
      expect(result.hadBadCharacters, isTrue);
    });

    test('empty input gives empty text', () {
      expect(decodeImportBytes(const []).text, '');
    });
  });

  group('column guide', () {
    test('price is required and names accept either language', () {
      final price = menuCsvFields.firstWhere((f) => f.key == 'price');
      final name = menuCsvFields.firstWhere((f) => f.key == 'name_en');
      final sku = menuCsvFields.firstWhere((f) => f.key == 'sku');
      expect(columnNeed(price), ColumnNeed.required);
      expect(columnNeed(name), ColumnNeed.eitherLanguage);
      expect(columnNeed(sku), ColumnNeed.optional);
    });

    test('every column has an example except none missing for required ones', () {
      for (final field in menuCsvFields) {
        if (columnNeed(field) != ColumnNeed.optional) {
          expect(columnExample(field), isNotEmpty, reason: field.key);
        }
      }
    });
  });

  group('readColumns', () {
    test('marks recognised, renamed and ignored headers', () {
      final parse = parseMenuCsv(
        'Category,Dish name,Price,Colour\nMain,Tehari,280,red\n',
      );
      final columns = readColumns(parse);
      expect(
        columns.where((c) => c.kind == ColumnKind.ignored).map((c) => c.header).toList(),
        ['Colour'],
      );
      final recognised = columns.where((c) => c.kind == ColumnKind.recognised).toList();
      expect(recognised.length, greaterThanOrEqualTo(2));
      expect(columns.firstWhere((c) => c.header == 'Colour').label, 'Colour');
    });

    test('repeated columns are reported as duplicates', () {
      final parse = parseMenuCsv('Category,Name,Price,Price\nMain,Tehari,280,300\n');
      final duplicates = readColumns(parse).where((c) => c.kind == ColumnKind.duplicate);
      expect(duplicates.length, 1);
      expect(duplicates.first.label, contains('repeats'));
    });
  });

  group('preview', () {
    final parse = _parse('Main,Tehari,280,,T1\nMain,,100,,T2\nMain,Soup,90,,T3');
    final plan = _plan(parse);
    final rows = buildPreviewRows(parse, plan);

    test('one entry per row in file order', () {
      expect(rows.length, 3);
      expect(rows.map((r) => r.row.number).toList(), [2, 3, 4]);
    });

    test('invalid rows are errors, valid rows are creates', () {
      expect(rows[1].status, RowStatus.error);
      expect(rows[1].hasError, isTrue);
      expect(rows[0].status, RowStatus.create);
      expect(rows[0].notes.any((n) => n.contains('New category')), isTrue);
    });

    test('filters', () {
      expect(filterPreview(rows, PreviewFilter.all).length, 3);
      expect(filterPreview(rows, PreviewFilter.valid).length, 2);
      expect(filterPreview(rows, PreviewFilter.errors).length, 1);
    });

    test('counts add up', () {
      final counts = countPreview(parse, plan);
      expect(counts.found, 3);
      expect(counts.create, 2);
      expect(counts.errors, 1);
      expect(counts.toSave, 2);
      expect(counts.canImport, isTrue);
      expect(counts.newCategories, 1);
    });

    test('describeImportPlan is plain sentences', () {
      final text = describeImportPlan(countPreview(parse, plan));
      expect(text, contains('2 new dishes will be created'));
      expect(text, contains('1 new category will be added'));
      expect(text, contains('1 row with errors will not be imported'));
    });

    test('nothing to change reads clearly', () {
      expect(
        describeImportPlan(const PreviewCounts()),
        'Nothing in this file will change your menu.',
      );
    });

    test('pluralize', () {
      expect(pluralize(1, 'dish', 'dishes'), 'dish');
      expect(pluralize(2, 'dish', 'dishes'), 'dishes');
      expect(pluralize(0, 'dish', 'dishes'), 'dishes');
    });
  });

  group('ImportSession flow', () {
    test('starts idle and keeps the update choice through a reset', () {
      var session = const ImportSession();
      expect(session.stage, ImportStage.idle);
      parse() => _parse(_rows(2));
      session = session.startReading('a.csv', 10).parsed(parse());
      session = session.withUpdateExisting(false);
      expect(session.updateExisting, isFalse);
      expect(session.reset().updateExisting, isFalse);
      expect(session.reset().stage, ImportStage.idle);
    });

    test('rejected keeps the message for the file step', () {
      final session = const ImportSession().rejected('a.pdf', 5, 'No.');
      expect(session.problem, 'No.');
      expect(session.stage, ImportStage.idle);
    });

    test('update choice can only change while previewing', () {
      final idle = const ImportSession().withUpdateExisting(false);
      expect(idle.updateExisting, isTrue);
    });

    test('start needs parsed rows and splits them into batches', () {
      final parse = _parse(_rows(250));
      final parsed = const ImportSession().startReading('a.csv', 10).parsed(parse);
      final started = parsed.start(parse.validRows);
      expect(started.stage, ImportStage.importing);
      expect(started.totalChunks, 3);
      expect(started.rowsTotal, 250);
      expect(started.currentChunk.length, importBatchSize);
      expect(started.batchLabel, 'Batch 1 of 3');
      expect(const ImportSession().start(parse.validRows).stage, ImportStage.idle);
      expect(parsed.start(const []).stage, ImportStage.parsed);
    });

    test('a clean run reports progress and ends done', () {
      final parse = _parse(_rows(250));
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      expect(session.progress, 0);
      session = session.chunkSucceeded(const ImportResult(created: 100));
      expect(session.rowsDone, 100);
      expect(session.percent, 40);
      session = session.chunkSucceeded(const ImportResult(created: 100));
      session = session.chunkSucceeded(const ImportResult(created: 50));
      expect(session.stage, ImportStage.done);
      expect(session.progress, 1);
      final outcome = session.outcome;
      expect(outcome.created, 250);
      expect(outcome.failed, 0);
      expect(outcome.headline, 'Import complete');
      expect(outcome.hasProblems, isFalse);
      expect(session.issues, isEmpty);
    });

    test('server row errors map back to file rows', () {
      final parse = _parse(_rows(3));
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      session = session.chunkSucceeded(
        const ImportResult(created: 2, errors: [(row: 2, message: 'Bad price')]),
      );
      expect(session.stage, ImportStage.done);
      expect(session.outcome.failed, 1);
      expect(session.outcome.headline, 'Import finished with problems');
      expect(session.issues.length, 1);
      expect(session.issues.first.row, 3);
      expect(session.issues.first.message, 'Bad price');
    });

    test('cancel stops after the batch in flight and counts unsent rows', () {
      final parse = _parse(_rows(250));
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      session = session.requestCancel();
      expect(session.cancelRequested, isTrue);
      session = session.chunkSucceeded(const ImportResult(created: 100));
      expect(session.stage, ImportStage.cancelled);
      expect(session.stopReason, StopReason.userCancelled);
      final outcome = session.outcome;
      expect(outcome.notSent, 150);
      expect(outcome.headline, 'Import cancelled');
      expect(outcome.detail, contains('150 rows were not sent'));
      expect(session.issues.length, 150);
    });

    test('a failed batch is recorded and the run continues once', () {
      final parse = _parse(_rows(250));
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      session = session.chunkFailed('offline');
      expect(session.stage, ImportStage.importing);
      expect(session.failedChunks, [0]);
      expect(session.consecutiveFailures, 1);
      session = session.chunkSucceeded(const ImportResult(created: 100));
      expect(session.consecutiveFailures, 0);
      session = session.chunkSucceeded(const ImportResult(created: 50));
      expect(session.stage, ImportStage.done);
      expect(session.outcome.failed, 100);
      expect(session.outcome.created, 150);
    });

    test('two failures in a row stop the import', () {
      final parse = _parse(_rows(350));
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      session = session.chunkFailed('offline');
      session = session.chunkFailed('offline');
      expect(session.stage, ImportStage.cancelled);
      expect(session.stopReason, StopReason.repeatedFailures);
      expect(session.outcome.headline, 'Import stopped');
      expect(session.outcome.notSent, 150);
      expect(session.issues.first.message, 'offline');
      expect(session.issues.length, 350);
    });

    test('rows that could not be read are part of the issues and failures', () {
      final parse = _parse('Main,Tehari,280,,T1\nMain,,100,,T2');
      var session = const ImportSession()
          .startReading('a.csv', 10)
          .parsed(parse)
          .start(parse.validRows);
      session = session.chunkSucceeded(const ImportResult(created: 1));
      expect(session.outcome.failed, 1);
      expect(session.issues.length, 1);
      expect(session.issues.first.row, 3);
    });

    test('events in the wrong stage are ignored', () {
      const idle = ImportSession();
      expect(idle.chunkSucceeded(const ImportResult(created: 1)).tally.created, 0);
      expect(idle.chunkFailed('x').stage, ImportStage.idle);
      expect(idle.requestCancel().cancelRequested, isFalse);
    });
  });

  group('file names and counts', () {
    test('dateStamp pads', () {
      expect(dateStamp(DateTime(2026, 3, 4)), '2026-03-04');
    });

    test('export names', () {
      final now = DateTime(2026, 11, 22);
      expect(exportFileName(ExportScope.all, null, now), 'ez-menu-dishes-2026-11-22');
      expect(
        exportFileName(ExportScope.branch, 'Gulshan Branch', now),
        'ez-menu-gulshan-branch-2026-11-22',
      );
      expect(exportFileName(ExportScope.branch, '', now), 'ez-menu-branch-2026-11-22');
      expect(errorReportFileName(now), 'ez-menu-import-errors-2026-11-22');
    });
  });
}
