import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logic/menu_csv.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import '../home/menu_stats.dart';
import 'import_export_state.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/import_widgets.dart';

enum _Mode { import, export }

/// Import dishes from a spreadsheet and export the menu (plan 4.5). Pure logic
/// lives in `core/logic/menu_csv.dart` and `import_export_state.dart`; this file
/// only wires files, the repository and the widgets together.
class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  _Mode _mode = _Mode.import;
  ImportSession _session = const ImportSession();
  ExportScope _scope = ExportScope.all;
  bool _exporting = false;

  // The prediction is recomputed only when its inputs change.
  ImportPlan? _plan;
  List<PreviewRow> _previewRows = const [];
  MenuCsvParse? _planParse;
  bool? _planUpdate;
  List<MenuItem>? _planItems;
  List<MenuCategory>? _planCategories;

  bool get _busy => _session.isBusy;

  // ---- import ----

  Future<void> _downloadTemplate() async {
    await _saveText(templateFileName, buildTemplateCsv(), 'Template saved.');
  }

  Future<void> _chooseFile() async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: importFileExtensions,
        withData: true,
      );
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
      return;
    }
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final problem = checkImportFile(name: file.name, size: file.size);
    if (problem != null) {
      setState(() => _session = _session.rejected(file.name, file.size, problem));
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(
        () => _session = _session.rejected(
          file.name,
          file.size,
          'The file could not be read. Try choosing it again.',
        ),
      );
      return;
    }
    setState(() => _session = _session.startReading(file.name, file.size));
    // Let the "Reading file" state paint before the parser runs.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    final decoded = decodeImportBytes(bytes);
    final parse = parseMenuCsv(decoded.text);
    final notice = decoded.hadBadCharacters
        ? 'Some characters in this file could not be read and were replaced. Save the file '
            'as CSV UTF-8 and choose it again if names look wrong.'
        : (decoded.encoding == 'UTF-8' ? null : 'This file was read as ${decoded.encoding}.');
    setState(() => _session = _session.parsed(parse, notice: notice));
  }

  ImportPlan _planFor(
    MenuCsvParse parse,
    List<MenuItem> items,
    List<MenuCategory> categories,
    bool updateExisting,
  ) {
    if (_plan != null &&
        identical(_planParse, parse) &&
        _planUpdate == updateExisting &&
        identical(_planItems, items) &&
        identical(_planCategories, categories)) {
      return _plan!;
    }
    final plan = planImport(
      parse.validRows,
      existingItems: items,
      existingCategories: categories,
      updateExisting: updateExisting,
    );
    _plan = plan;
    _previewRows = buildPreviewRows(parse, plan);
    _planParse = parse;
    _planUpdate = updateExisting;
    _planItems = items;
    _planCategories = categories;
    return plan;
  }

  Future<void> _startImport(ImportPlan plan) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final rows = [for (final planned in plan.rows) planned.row];
    if (rows.isEmpty) return;
    setState(() => _session = _session.start(rows));
    final repository = ref.read(menuRepositoryProvider);
    while (mounted && _session.stage == ImportStage.importing) {
      final chunk = _session.currentChunk;
      try {
        final result = await repository.importItems(
          businessId,
          importPayload(chunk),
          updateExisting: _session.updateExisting,
        );
        if (!mounted) break;
        setState(() => _session = _session.chunkSucceeded(result));
      } catch (error) {
        if (!mounted) break;
        setState(() => _session = _session.chunkFailed(friendlyError(error)));
      }
    }
    // Whatever was saved, the lists and the home counts must show it.
    ref.invalidate(menuItemsProvider);
    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(menuStatsProvider);
  }

  Future<void> _downloadReport() async {
    final parse = _session.parse;
    if (parse == null) return;
    final csv = buildErrorReportCsv(parse, _session.issues);
    await _saveText(errorReportFileName(DateTime.now()), csv, 'Error report saved.');
  }

  // ---- export ----

  Future<String?> _buildExport(List<MenuItem> items, List<MenuCategory> categories) async {
    final branch = ref.read(selectedBranchProvider);
    Map<String, BranchItemSetting>? settings;
    if (_scope == ExportScope.branch && branch != null) {
      settings = await ref.read(branchItemSettingsProvider(branch.id).future);
    }
    return buildMenuCsv(items: items, categories: categories, settings: settings);
  }

  String get _exportName {
    final branch = ref.read(selectedBranchProvider);
    return exportFileName(_scope, branch?.name, DateTime.now());
  }

  Future<void> _download(List<MenuItem> items, List<MenuCategory> categories) async {
    setState(() => _exporting = true);
    try {
      final csv = await _buildExport(items, categories);
      if (csv == null) return;
      await _saveText(_exportName, csv, 'Menu exported.');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share(List<MenuItem> items, List<MenuCategory> categories) async {
    setState(() => _exporting = true);
    try {
      final csv = await _buildExport(items, categories);
      if (csv == null) return;
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: '$_exportName.csv')],
        subject: 'EZ Menu dishes',
      );
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          'Sharing is not available here. Use Download CSV instead.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---- files ----

  Future<void> _saveText(String name, String text, String successMessage) async {
    await runWithToast(
      context,
      () async {
        await FileSaver.instance.saveFile(
          name: name,
          bytes: Uint8List.fromList(utf8.encode(text)),
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      },
      onError: friendlyError,
      successMessage: successMessage,
    );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/menu');
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final branch = ref.watch(selectedBranchProvider);

    return PopScope(
      canPop: !_busy,
      child: AppPage(
        title: 'Import and export',
        subtitle: 'Move your menu in and out of a spreadsheet',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_busy && !_session.isFinished) ...[
              SegmentedChoice<_Mode>(
                value: _mode,
                onChanged: (value) => setState(() => _mode = value),
                options: const [
                  ChoiceOption(value: _Mode.import, label: 'Import', icon: Icons.upload_file_rounded),
                  ChoiceOption(value: _Mode.export, label: 'Export', icon: Icons.download_rounded),
                ],
              ),
              const SizedBox(height: Sp.lg),
            ],
            AsyncValueView<List<MenuCategory>>(
              value: categoriesAsync,
              onRetry: () => ref.invalidate(menuCategoriesProvider),
              data: (categories) => AsyncValueView<List<MenuItem>>(
                value: itemsAsync,
                onRetry: () => ref.invalidate(menuItemsProvider),
                data: (items) => _mode == _Mode.import
                    ? _buildImport(items, categories)
                    : _buildExport_(items, categories, branch?.name),
              ),
            ),
          ],
        ),
        bottomBar: _bottomBar(),
      ),
    );
  }

  Widget? _bottomBar() {
    final session = _session;
    if (_mode != _Mode.import || session.stage != ImportStage.parsed) return null;
    final parse = session.parse;
    final plan = _plan;
    if (parse == null || plan == null || !parse.canImport) return null;
    final counts = countPreview(parse, plan);
    final label = counts.canImport
        ? 'Import ${counts.toSave} ${pluralize(counts.toSave, 'dish', 'dishes')}'
        : 'Nothing to import';
    return StickyActionBar(
      child: AppButton(
        label: label,
        icon: Icons.cloud_upload_outlined,
        expand: true,
        onPressed: counts.canImport ? () => _confirmImport(plan, counts) : null,
      ),
    );
  }

  Future<void> _confirmImport(ImportPlan plan, PreviewCounts counts) async {
    final ok = await confirmAction(
      context,
      title: 'Import into your menu?',
      message: '${describeImportPlan(counts)} Dishes that are saved can be changed or '
          'moved to the trash later.',
      confirmLabel: 'Import',
    );
    if (ok == true && mounted) await _startImport(plan);
  }

  Widget _buildImport(List<MenuItem> items, List<MenuCategory> categories) {
    final session = _session;
    switch (session.stage) {
      case ImportStage.idle:
      case ImportStage.reading:
        return ImportStartPanel(
          session: session,
          onDownloadTemplate: _downloadTemplate,
          onChooseFile: _chooseFile,
        );
      case ImportStage.parsed:
        final parse = session.parse!;
        final plan = _planFor(parse, items, categories, session.updateExisting);
        final counts = countPreview(parse, plan);
        return ImportPreviewPanel(
          session: session,
          counts: counts,
          rows: _previewRows,
          visibleRows: filterPreview(_previewRows, session.filter),
          onFilter: (filter) => setState(() => _session = _session.withFilter(filter)),
          onUpdateExisting: (value) =>
              setState(() => _session = _session.withUpdateExisting(value)),
          onChooseAnother: () => setState(() => _session = _session.reset()),
        );
      case ImportStage.importing:
        return ImportProgressPanel(
          session: session,
          onCancel: () => setState(() => _session = _session.requestCancel()),
        );
      case ImportStage.cancelled:
      case ImportStage.done:
        return ImportResultPanel(
          session: session,
          onDownloadReport: _downloadReport,
          onImportAnother: () => setState(() => _session = _session.reset()),
          onDone: _leave,
        );
    }
  }

  Widget _buildExport_(List<MenuItem> items, List<MenuCategory> categories, String? branchName) {
    return ExportPanel(
      scope: _scope,
      branchName: branchName,
      itemCount: countLiveItems(items),
      busy: _exporting,
      onScope: (value) => setState(() => _scope = value),
      onDownload: () => _download(items, categories),
      onShare: () => _share(items, categories),
    );
  }
}
