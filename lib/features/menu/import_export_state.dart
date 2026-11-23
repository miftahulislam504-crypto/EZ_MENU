import 'dart:convert';

import '../../core/logic/menu_csv.dart';
import '../../core/logic/slug.dart';
import 'menu_models.dart';

/// Pure logic behind the menu import and export screen: file checks, decoding,
/// the preview model, the import session state machine (progress, cancel,
/// partial results) and file names. No Flutter imports, so it is unit tested.

// ---- limits ----------------------------------------------------------------------

/// Largest file the importer reads. 5000 dishes with long Bangla descriptions
/// fit well inside this.
const int importMaxFileBytes = 5 * 1024 * 1024;

/// Extensions the file picker offers.
const List<String> importFileExtensions = ['csv', 'tsv', 'txt'];

/// Rows per request. Smaller than [importChunkSize] so the progress bar moves
/// and a failed request loses little; well under the 1000 the function accepts.
const int importBatchSize = 100;

/// The import stops after this many batches in a row fail (usually the
/// connection is gone), keeping everything saved so far.
const int importMaxConsecutiveFailures = 2;

const Set<String> _spreadsheetExtensions = {
  'xlsx', 'xls', 'xlsm', 'xlsb', 'ods', 'numbers',
};

String pluralize(int count, String one, String many) => count == 1 ? one : many;

/// 512 B, 38 KB, 2.4 MB.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Why the chosen file cannot be used, or null when it is fine to read.
String? checkImportFile({required String name, required int size}) {
  final ext = _extensionOf(name);
  if (_spreadsheetExtensions.contains(ext)) {
    return 'Spreadsheet files such as .$ext cannot be read directly. In your '
        'spreadsheet app choose Save as, pick CSV UTF-8, then choose the saved file.';
  }
  if (ext.isNotEmpty && !importFileExtensions.contains(ext)) {
    return 'This is a .$ext file. Choose a CSV, TSV or TXT file.';
  }
  if (size <= 0) return 'The file is empty.';
  if (size > importMaxFileBytes) {
    return 'The file is ${formatFileSize(size)}. Import files up to '
        '${formatFileSize(importMaxFileBytes)} and split bigger menus into several files.';
  }
  return null;
}

// ---- decoding --------------------------------------------------------------------

/// Text of a file plus what was needed to read it.
class DecodedImportText {
  const DecodedImportText(
    this.text, {
    this.encoding = 'UTF-8',
    this.hadBadCharacters = false,
  });

  final String text;
  final String encoding;

  /// Some bytes were not valid text and were replaced.
  final bool hadBadCharacters;
}

/// Reads file bytes as text. UTF-8 (with or without a byte order mark) and the
/// UTF-16 that Excel writes for "Unicode Text" are understood; anything else is
/// read as UTF-8 and flagged when characters were lost.
DecodedImportText decodeImportBytes(List<int> bytes) {
  if (bytes.isEmpty) return const DecodedImportText('');
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes, littleEndian: false);
  }
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return DecodedImportText(text, hadBadCharacters: text.contains('�'));
}

DecodedImportText _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return DecodedImportText(
    String.fromCharCodes(units),
    encoding: 'UTF-16',
    hadBadCharacters: units.contains(0xFFFD),
  );
}

// ---- column guide ----------------------------------------------------------------

enum ColumnNeed { required, eitherLanguage, optional }

/// Whether a column must be filled. Names and categories need one of their
/// two languages; the price is always needed.
ColumnNeed columnNeed(MenuCsvField field) {
  switch (field.key) {
    case 'category_en':
    case 'category_bn':
    case 'name_en':
    case 'name_bn':
      return ColumnNeed.eitherLanguage;
    case 'price':
      return ColumnNeed.required;
    default:
      return ColumnNeed.optional;
  }
}

const Map<String, String> _examples = {
  'category_en': 'Main Course',
  'category_bn': 'মেইন কোর্স',
  'name_en': 'Beef Tehari',
  'name_bn': 'বিফ তেহারি',
  'short_description_en': 'Spiced rice with tender beef',
  'short_description_bn': 'কোমল গরুর মাংসের তেহারি',
  'description_en': 'Slow cooked beef with fragrant rice, served with borhani.',
  'description_bn': 'সুগন্ধি চালে ধীরে রান্না করা গরুর মাংস, সঙ্গে বোরহানি।',
  'price': '280',
  'discount_price': '250',
  'prep_time_min': '15',
  'sku': 'TEH-01',
  'labels': 'Spicy; Halal',
  'is_sold_out': 'no',
  'is_active': 'yes',
  'is_featured': 'no',
};

/// An example value for the column guide.
String columnExample(MenuCsvField field) => _examples[field.key] ?? '';

/// How a header of the chosen file was read.
enum ColumnKind { recognised, duplicate, ignored }

class ColumnReading {
  const ColumnReading({
    required this.header,
    required this.kind,
    this.fieldHeader,
  });

  /// The header as written in the file.
  final String header;
  final ColumnKind kind;

  /// The menu column it was matched to (or repeats).
  final String? fieldHeader;

  bool get isRenamed =>
      fieldHeader != null && normalizeHeader(header) != normalizeHeader(fieldHeader!);

  /// Text for a chip.
  String get label {
    switch (kind) {
      case ColumnKind.recognised:
        return isRenamed ? '"$header" read as $fieldHeader' : header;
      case ColumnKind.duplicate:
        return '"$header" repeats $fieldHeader';
      case ColumnKind.ignored:
        return header;
    }
  }
}

String _headerOfField(String key) {
  for (final field in menuCsvFields) {
    if (field.key == key) return field.header;
  }
  return key;
}

/// Every named column of the file, as recognised, repeated or not imported.
List<ColumnReading> readColumns(MenuCsvParse parse) {
  final result = <ColumnReading>[];
  for (final column in parse.columns) {
    if (column.header.isEmpty) continue;
    final field = column.field;
    if (field == null) {
      result.add(ColumnReading(header: column.header, kind: ColumnKind.ignored));
    } else {
      result.add(
        ColumnReading(
          header: column.header,
          kind: column.duplicate ? ColumnKind.duplicate : ColumnKind.recognised,
          fieldHeader: _headerOfField(field),
        ),
      );
    }
  }
  return result;
}

// ---- preview ---------------------------------------------------------------------

enum PreviewFilter { all, valid, errors, warnings }

/// What the preview says about one row of the file.
enum RowStatus { create, update, skip, error }

class PreviewRow {
  const PreviewRow({required this.row, required this.status, this.planned});

  final ImportRow row;
  final RowStatus status;

  /// The prediction for valid rows.
  final PlannedRow? planned;

  bool get hasError => status == RowStatus.error;

  /// A valid row with something worth a second look.
  bool get hasWarning => !hasError && row.warnings.isNotEmpty;

  List<String> get errors => row.errors;
  List<String> get warnings => row.warnings;

  /// Extra facts about a valid row: moves, cleared discounts, new category.
  List<String> get notes {
    final p = planned;
    if (p == null) return const [];
    return [
      if (p.newCategory) 'New category "${p.row.categoryTitle}" will be created.',
      ...p.notes,
      if (p.action == ImportAction.skip)
        'Already on your menu, so it is skipped. Turn on updating to change it.',
    ];
  }

  /// Everything to show in the details column, most important first.
  List<String> get allText => [...errors, ...warnings, ...notes];
}

/// One entry per row of the file, in file order, joined with the prediction.
List<PreviewRow> buildPreviewRows(MenuCsvParse parse, ImportPlan plan) {
  final byNumber = {for (final p in plan.rows) p.row.number: p};
  return [
    for (final row in parse.rows)
      if (!row.isValid)
        PreviewRow(row: row, status: RowStatus.error)
      else
        () {
          final planned = byNumber[row.number];
          final status = switch (planned?.action) {
            ImportAction.update => RowStatus.update,
            ImportAction.skip => RowStatus.skip,
            _ => RowStatus.create,
          };
          return PreviewRow(row: row, status: status, planned: planned);
        }(),
  ];
}

List<PreviewRow> filterPreview(List<PreviewRow> rows, PreviewFilter filter) {
  switch (filter) {
    case PreviewFilter.all:
      return rows;
    case PreviewFilter.valid:
      return [for (final r in rows) if (!r.hasError) r];
    case PreviewFilter.errors:
      return [for (final r in rows) if (r.hasError) r];
    case PreviewFilter.warnings:
      return [for (final r in rows) if (r.hasWarning) r];
  }
}

/// Numbers for the summary chips.
class PreviewCounts {
  const PreviewCounts({
    this.found = 0,
    this.create = 0,
    this.update = 0,
    this.skip = 0,
    this.errors = 0,
    this.warnings = 0,
    this.newCategories = 0,
  });

  final int found;
  final int create;
  final int update;
  final int skip;
  final int errors;
  final int warnings;
  final int newCategories;

  /// Rows that will change the menu.
  int get toSave => create + update;

  /// Rows that will be sent.
  int get valid => create + update + skip;

  bool get canImport => toSave > 0;
}

PreviewCounts countPreview(MenuCsvParse parse, ImportPlan plan) => PreviewCounts(
  found: parse.rows.length,
  create: plan.created,
  update: plan.updated,
  skip: plan.skipped,
  errors: parse.invalidRows.length,
  warnings: parse.warningRowCount,
  newCategories: plan.newCategories.length,
);

String _sentenceList(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// "12 new dishes will be created, 3 existing dishes will be updated."
String describeImportPlan(PreviewCounts c) {
  final parts = <String>[
    if (c.create > 0)
      '${c.create} new ${pluralize(c.create, 'dish', 'dishes')} will be created',
    if (c.update > 0)
      '${c.update} existing ${pluralize(c.update, 'dish', 'dishes')} will be updated',
    if (c.skip > 0)
      '${c.skip} ${pluralize(c.skip, 'dish', 'dishes')} will be skipped because ${pluralize(c.skip, 'it already exists', 'they already exist')}',
  ];
  final buffer = StringBuffer();
  if (parts.isEmpty) {
    buffer.write('Nothing in this file will change your menu.');
  } else {
    buffer.write('${_sentenceList(parts)}.');
  }
  if (c.newCategories > 0) {
    buffer.write(
      ' ${c.newCategories} new ${pluralize(c.newCategories, 'category', 'categories')} will be added.',
    );
  }
  if (c.errors > 0) {
    buffer.write(
      ' ${c.errors} ${pluralize(c.errors, 'row', 'rows')} with errors will not be imported.',
    );
  }
  return buffer.toString();
}

// ---- import session --------------------------------------------------------------

enum ImportStage { idle, reading, parsed, importing, cancelled, done }

enum StopReason { none, userCancelled, repeatedFailures }

/// What the person sees when the import is over.
class ImportOutcome {
  const ImportOutcome({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.notSent,
    required this.stopReason,
  });

  final int created;
  final int updated;
  final int skipped;

  /// Rows that were read as invalid, rejected by the server, or in a request
  /// that failed.
  final int failed;

  /// Rows never sent because the import was cancelled or stopped.
  final int notSent;
  final StopReason stopReason;

  int get saved => created + updated;
  bool get stoppedEarly => stopReason != StopReason.none;
  bool get hasProblems => failed > 0 || notSent > 0;

  String get headline {
    switch (stopReason) {
      case StopReason.userCancelled:
        return 'Import cancelled';
      case StopReason.repeatedFailures:
        return 'Import stopped';
      case StopReason.none:
        if (saved == 0 && failed > 0) return 'Nothing was imported';
        return failed > 0 ? 'Import finished with problems' : 'Import complete';
    }
  }

  String get detail {
    final saves = saved == 0
        ? 'Nothing was saved.'
        : '$saved ${pluralize(saved, 'dish was', 'dishes were')} saved.';
    switch (stopReason) {
      case StopReason.userCancelled:
        return '$saves $notSent ${pluralize(notSent, 'row was', 'rows were')} not sent. '
            'What was already saved stays on your menu.';
      case StopReason.repeatedFailures:
        return '$saves The connection failed several times in a row, so $notSent '
            '${pluralize(notSent, 'row was', 'rows were')} not sent. Download the report, '
            'then import it again when you are back online.';
      case StopReason.none:
        if (failed > 0) {
          return '$saves $failed ${pluralize(failed, 'row needs', 'rows need')} attention. '
              'Download the report, fix the rows and import that file again.';
        }
        return saves;
    }
  }
}

/// The whole state of one import, from picking a file to the result. Every
/// method returns a new session; nothing is mutated.
class ImportSession {
  const ImportSession({
    this.stage = ImportStage.idle,
    this.fileName = '',
    this.fileSize = 0,
    this.problem,
    this.notice,
    this.parse,
    this.updateExisting = true,
    this.filter = PreviewFilter.all,
    this.chunks = const [],
    this.chunkIndex = 0,
    this.tally = const ImportTally(),
    this.cancelRequested = false,
    this.consecutiveFailures = 0,
    this.failedChunks = const [],
    this.stopReason = StopReason.none,
  });

  final ImportStage stage;
  final String fileName;
  final int fileSize;

  /// The chosen file cannot be used (shown on the file step).
  final String? problem;

  /// A soft note about a usable file, such as lost characters.
  final String? notice;
  final MenuCsvParse? parse;
  final bool updateExisting;
  final PreviewFilter filter;

  /// The valid rows, split into requests.
  final List<List<ImportRow>> chunks;

  /// Requests finished so far; while importing, also the index of the request
  /// in flight.
  final int chunkIndex;
  final ImportTally tally;
  final bool cancelRequested;
  final int consecutiveFailures;

  /// Indexes of requests that failed completely.
  final List<int> failedChunks;
  final StopReason stopReason;

  bool get isBusy => stage == ImportStage.importing || stage == ImportStage.reading;
  bool get isFinished => stage == ImportStage.done || stage == ImportStage.cancelled;

  // ---- progress ----

  int get totalChunks => chunks.length;
  int get completedChunks => chunkIndex < chunks.length ? chunkIndex : chunks.length;

  int get rowsTotal => chunks.fold(0, (sum, c) => sum + c.length);

  int get rowsDone {
    var sum = 0;
    for (var i = 0; i < completedChunks; i++) {
      sum += chunks[i].length;
    }
    return sum;
  }

  /// 0 to 1.
  double get progress {
    if (stage == ImportStage.done) return 1;
    final total = rowsTotal;
    return total == 0 ? 0 : rowsDone / total;
  }

  int get percent => (progress * 100).floor();

  /// "Batch 2 of 5", or empty when nothing is being sent.
  String get batchLabel =>
      stage == ImportStage.importing && totalChunks > 0
          ? 'Batch ${chunkIndex + 1} of $totalChunks'
          : '';

  /// The request to send now.
  List<ImportRow> get currentChunk =>
      stage == ImportStage.importing && chunkIndex < chunks.length
          ? chunks[chunkIndex]
          : const [];

  /// Rows that were never sent.
  List<ImportRow> get unsentRows => [
    for (var i = completedChunks; i < chunks.length; i++) ...chunks[i],
  ];

  /// Rows the server could not use, plus rows of failed requests.
  int get sendFailures => tally.failed;

  // ---- result ----

  ImportOutcome get outcome {
    final readErrors = parse?.invalidRows.length ?? 0;
    return ImportOutcome(
      created: tally.created,
      updated: tally.updated,
      skipped: tally.skipped,
      failed: readErrors + tally.failed,
      notSent: isFinished ? unsentRows.length : 0,
      stopReason: stopReason,
    );
  }

  /// Every row that did not make it, in file order, for the error report: rows
  /// that could not be read, rows the server refused, rows of failed requests
  /// and rows never sent.
  List<ImportIssue> get issues {
    final p = parse;
    final unsentMessage = stopReason == StopReason.repeatedFailures
        ? 'Not sent because the import stopped after repeated connection problems.'
        : 'Not sent because the import was cancelled.';
    final all = <ImportIssue>[
      if (p != null) ...readIssues(p),
      ...tally.issues,
      if (isFinished)
        for (final row in unsentRows)
          ImportIssue(row.number, unsentMessage, title: row.title),
    ];
    final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])];
    indexed.sort((a, b) {
      final byRow = a.$2.row.compareTo(b.$2.row);
      return byRow != 0 ? byRow : a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  // ---- transitions ----

  ImportSession _copy({
    ImportStage? stage,
    bool? updateExisting,
    PreviewFilter? filter,
    int? chunkIndex,
    ImportTally? tally,
    bool? cancelRequested,
    int? consecutiveFailures,
    List<int>? failedChunks,
    StopReason? stopReason,
  }) {
    return ImportSession(
      stage: stage ?? this.stage,
      fileName: fileName,
      fileSize: fileSize,
      problem: problem,
      notice: notice,
      parse: parse,
      updateExisting: updateExisting ?? this.updateExisting,
      filter: filter ?? this.filter,
      chunks: chunks,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      tally: tally ?? this.tally,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      failedChunks: failedChunks ?? this.failedChunks,
      stopReason: stopReason ?? this.stopReason,
    );
  }

  /// Back to the start. The "update existing" choice is kept.
  ImportSession reset() => ImportSession(updateExisting: updateExisting);

  /// The file was refused before reading.
  ImportSession rejected(String name, int size, String message) => ImportSession(
    fileName: name,
    fileSize: size,
    problem: message,
    updateExisting: updateExisting,
  );

  /// A file was accepted and is being read.
  ImportSession startReading(String name, int size) => ImportSession(
    stage: ImportStage.reading,
    fileName: name,
    fileSize: size,
    updateExisting: updateExisting,
  );

  /// The file was read.
  ImportSession parsed(MenuCsvParse result, {String? notice}) => ImportSession(
    stage: ImportStage.parsed,
    fileName: fileName,
    fileSize: fileSize,
    notice: notice,
    parse: result,
    updateExisting: updateExisting,
  );

  ImportSession withUpdateExisting(bool value) =>
      stage == ImportStage.parsed ? _copy(updateExisting: value) : this;

  ImportSession withFilter(PreviewFilter value) => _copy(filter: value);

  /// Sends [rows] (the valid rows, in file order) in batches.
  ImportSession start(List<ImportRow> rows) {
    if (stage != ImportStage.parsed || rows.isEmpty) return this;
    return ImportSession(
      stage: ImportStage.importing,
      fileName: fileName,
      fileSize: fileSize,
      notice: notice,
      parse: parse,
      updateExisting: updateExisting,
      filter: filter,
      chunks: chunkList(rows, size: importBatchSize),
    );
  }

  /// Stop after the batch that is being sent.
  ImportSession requestCancel() =>
      stage == ImportStage.importing ? _copy(cancelRequested: true) : this;

  /// The answer for the batch in flight.
  ImportSession chunkSucceeded(ImportResult result) {
    if (stage != ImportStage.importing) return this;
    return _advance(tally.addChunk(result, currentChunk), 0, failedChunks);
  }

  /// The batch in flight could not be sent at all.
  ImportSession chunkFailed(String message) {
    if (stage != ImportStage.importing) return this;
    return _advance(
      tally.addFailedChunk(currentChunk, message),
      consecutiveFailures + 1,
      [...failedChunks, chunkIndex],
    );
  }

  ImportSession _advance(ImportTally nextTally, int failures, List<int> failed) {
    final next = chunkIndex + 1;
    var nextStage = ImportStage.importing;
    var reason = StopReason.none;
    if (next >= chunks.length) {
      nextStage = ImportStage.done;
    } else if (failures >= importMaxConsecutiveFailures) {
      nextStage = ImportStage.cancelled;
      reason = StopReason.repeatedFailures;
    } else if (cancelRequested) {
      nextStage = ImportStage.cancelled;
      reason = StopReason.userCancelled;
    }
    return _copy(
      stage: nextStage,
      chunkIndex: next,
      tally: nextTally,
      consecutiveFailures: failures,
      failedChunks: failed,
      stopReason: reason,
    );
  }
}

// ---- export ----------------------------------------------------------------------

/// What the exported file contains: every dish with its own values, or every
/// dish as one branch shows it (that branch's prices, sold out and hidden).
enum ExportScope { all, branch }

int countLiveItems(List<MenuItem> items) => items.where((i) => !i.isDeleted).length;

/// 2026-11-22
String dateStamp(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

const String templateFileName = 'ez-menu-template';

String exportFileName(ExportScope scope, String? branchName, DateTime now) {
  final stamp = dateStamp(now);
  if (scope == ExportScope.all) return 'ez-menu-dishes-$stamp';
  final slug = slugify(branchName ?? '', maxLength: 24);
  return slug.isEmpty ? 'ez-menu-branch-$stamp' : 'ez-menu-$slug-$stamp';
}

String errorReportFileName(DateTime now) => 'ez-menu-import-errors-${dateStamp(now)}';
