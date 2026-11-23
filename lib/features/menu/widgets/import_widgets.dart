import 'package:flutter/material.dart';

import '../../../core/logic/menu_csv.dart';
import '../../../core/widgets/widgets.dart';
import '../import_export_state.dart';

/// Presentational pieces of the menu import and export screen. They hold no
/// business logic; the screen owns the state and passes callbacks in.

// ---- small shared pieces ------------------------------------------------------

class ImportCountChip extends StatelessWidget {
  const ImportCountChip({
    super.key,
    required this.value,
    required this.label,
    this.tone = PillTone.neutral,
  });

  final int value;
  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final (Color background, Color foreground) = switch (tone) {
      PillTone.success => (palette.successSoft, palette.success),
      PillTone.warning => (palette.warningSoft, palette.warning),
      PillTone.danger => (palette.dangerSoft, palette.danger),
      PillTone.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PillTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Rad.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: withTabularFigures(
                context.textStyles.titleMedium!.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: Sp.sm),
            Text(
              label,
              style: context.textStyles.bodySmall!.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short message with an icon, used for problems and hints.
class ImportMessage extends StatelessWidget {
  const ImportMessage({
    super.key,
    required this.text,
    this.tone = PillTone.info,
    this.icon,
  });

  final String text;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final (Color background, Color foreground, IconData defaultIcon) = switch (tone) {
      PillTone.danger => (palette.dangerSoft, palette.danger, Icons.error_outline_rounded),
      PillTone.warning => (palette.warningSoft, palette.warning, Icons.warning_amber_rounded),
      PillTone.success => (palette.successSoft, palette.success, Icons.check_circle_outline_rounded),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.info_outline_rounded),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Rad.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: foreground),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.bodyMedium!.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.number, required this.title, this.subtitle});

  final int number;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: context.textStyles.labelLarge!.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textStyles.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: context.textStyles.bodySmall!.copyWith(color: context.palette.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---- step 1 and 2: template and file ---------------------------------------------

class ImportStartPanel extends StatefulWidget {
  const ImportStartPanel({
    super.key,
    required this.session,
    required this.onDownloadTemplate,
    required this.onChooseFile,
  });

  final ImportSession session;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onChooseFile;

  @override
  State<ImportStartPanel> createState() => _ImportStartPanelState();
}

class _ImportStartPanelState extends State<ImportStartPanel> {
  bool _showGuide = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final reading = session.stage == ImportStage.reading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'Add many dishes at once',
          subtitle:
              'Fill in a spreadsheet, save it as CSV and upload it. You see exactly '
              'what will change before anything is saved.',
          children: [
            const _StepHeading(
              number: 1,
              title: 'Get the template',
              subtitle: 'A CSV file with the right columns and two example dishes.',
            ),
            Wrap(
              spacing: Sp.md,
              runSpacing: Sp.md,
              children: [
                AppButton(
                  label: 'Download template',
                  icon: Icons.download_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: widget.onDownloadTemplate,
                ),
                AppButton(
                  label: _showGuide ? 'Hide column guide' : 'Show column guide',
                  icon: _showGuide
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  kind: AppButtonKind.text,
                  onPressed: () => setState(() => _showGuide = !_showGuide),
                ),
              ],
            ),
            if (_showGuide) const ImportColumnGuide(),
            const Divider(height: 1),
            const _StepHeading(
              number: 2,
              title: 'Choose your file',
              subtitle:
                  'CSV, TSV or TXT up to ${importMaxFileMegabytes} MB. In a spreadsheet app use '
                  'Save as and pick CSV UTF-8 so Bangla text stays correct.',
            ),
            if (session.problem != null)
              ImportMessage(
                text: '${session.fileName}: ${session.problem}',
                tone: PillTone.danger,
              ),
            AppButton(
              label: reading ? 'Reading file' : 'Choose CSV file',
              icon: Icons.upload_file_rounded,
              loading: reading,
              onPressed: reading ? null : widget.onChooseFile,
            ),
          ],
        ),
      ],
    );
  }
}

/// Megabytes shown in the file step.
const int importMaxFileMegabytes = importMaxFileBytes ~/ (1024 * 1024);

class ImportColumnGuide extends StatelessWidget {
  const ImportColumnGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return ListGroup(
      children: [
        for (final field in menuCsvFields)
          ListRow(
            dense: true,
            title: field.header,
            subtitle: _guideLine(field),
            trailing: StatusPill(
              switch (columnNeed(field)) {
                ColumnNeed.required => 'Required',
                ColumnNeed.eitherLanguage => 'One language',
                ColumnNeed.optional => 'Optional',
              },
              tone: switch (columnNeed(field)) {
                ColumnNeed.required => PillTone.danger,
                ColumnNeed.eitherLanguage => PillTone.warning,
                ColumnNeed.optional => PillTone.neutral,
              },
            ),
          ),
      ],
    );
  }

  String _guideLine(MenuCsvField field) {
    final example = columnExample(field);
    return example.isEmpty ? field.note : '${field.note} Example: $example';
  }
}

// ---- step 3: preview -----------------------------------------------------------------

class ImportPreviewPanel extends StatelessWidget {
  const ImportPreviewPanel({
    super.key,
    required this.session,
    required this.counts,
    required this.rows,
    required this.visibleRows,
    required this.onFilter,
    required this.onUpdateExisting,
    required this.onChooseAnother,
  });

  final ImportSession session;
  final PreviewCounts counts;

  /// Every row of the file, in file order.
  final List<PreviewRow> rows;

  /// The rows after the filter was applied.
  final List<PreviewRow> visibleRows;
  final ValueChanged<PreviewFilter> onFilter;
  final ValueChanged<bool> onUpdateExisting;
  final VoidCallback onChooseAnother;

  static const int _maxShown = 200;

  @override
  Widget build(BuildContext context) {
    final parse = session.parse!;
    final columns = readColumns(parse);
    final shown = visibleRows.length > _maxShown
        ? visibleRows.sublist(0, _maxShown)
        : visibleRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'Review before importing',
          subtitle: '${session.fileName}  ·  ${formatFileSize(session.fileSize)}',
          children: [
            if (session.notice != null)
              ImportMessage(text: session.notice!, tone: PillTone.warning),
            for (final error in parse.fileErrors)
              ImportMessage(text: error, tone: PillTone.danger),
            for (final warning in parse.fileWarnings)
              ImportMessage(text: warning, tone: PillTone.warning),
            if (parse.fileErrors.isEmpty) ...[
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  ImportCountChip(value: counts.found, label: 'rows found'),
                  ImportCountChip(
                    value: counts.create,
                    label: 'to create',
                    tone: PillTone.success,
                  ),
                  ImportCountChip(
                    value: counts.update,
                    label: 'to update',
                    tone: PillTone.info,
                  ),
                  ImportCountChip(value: counts.skip, label: 'to skip'),
                  ImportCountChip(
                    value: counts.errors,
                    label: 'with errors',
                    tone: counts.errors > 0 ? PillTone.danger : PillTone.neutral,
                  ),
                  ImportCountChip(
                    value: counts.warnings,
                    label: 'with warnings',
                    tone: counts.warnings > 0 ? PillTone.warning : PillTone.neutral,
                  ),
                ],
              ),
              Text(
                describeImportPlan(counts),
                style: context.textStyles.bodyMedium,
              ),
              SwitchRow(
                title: 'Update dishes that already exist',
                subtitle:
                    'Dishes are matched by item code, or by name inside the same '
                    'category. Turn this off to only add new dishes.',
                value: session.updateExisting,
                onChanged: onUpdateExisting,
              ),
            ],
            AppButton(
              label: 'Choose another file',
              icon: Icons.swap_horiz_rounded,
              kind: AppButtonKind.text,
              onPressed: onChooseAnother,
            ),
          ],
        ),
        if (columns.isNotEmpty) ...[
          const SizedBox(height: Sp.lg),
          _ColumnsCard(columns: columns),
        ],
        if (parse.fileErrors.isEmpty && rows.isNotEmpty) ...[
          const SizedBox(height: Sp.lg),
          SegmentedChoice<PreviewFilter>(
            label: 'Show rows',
            value: session.filter,
            onChanged: onFilter,
            options: [
              ChoiceOption(value: PreviewFilter.all, label: 'All (${rows.length})'),
              ChoiceOption(
                value: PreviewFilter.valid,
                label: 'Valid (${counts.valid})',
              ),
              ChoiceOption(
                value: PreviewFilter.errors,
                label: 'Errors (${counts.errors})',
              ),
              ChoiceOption(
                value: PreviewFilter.warnings,
                label: 'Warnings (${counts.warnings})',
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          if (shown.isEmpty)
            const EmptyState(
              icon: Icons.filter_list_off_rounded,
              title: 'No rows match this filter',
              message: 'Choose another filter above to see the rest of the file.',
            )
          else
            ListGroup(
              title: 'Rows',
              children: [for (final row in shown) ImportPreviewRowTile(row: row)],
            ),
          if (visibleRows.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: Sp.md),
              child: Text(
                'Showing the first ${shown.length} of ${visibleRows.length} rows. '
                'Use the filters to look at the rest. All rows are imported.',
                style: context.textStyles.bodySmall!.copyWith(color: context.palette.muted),
              ),
            ),
        ],
      ],
    );
  }
}

class _ColumnsCard extends StatelessWidget {
  const _ColumnsCard({required this.columns});

  final List<ColumnReading> columns;

  @override
  Widget build(BuildContext context) {
    final used = [for (final c in columns) if (c.kind == ColumnKind.recognised) c];
    final repeated = [for (final c in columns) if (c.kind == ColumnKind.duplicate) c];
    final ignored = [for (final c in columns) if (c.kind == ColumnKind.ignored) c];
    return FormSection(
      title: 'Columns in your file',
      subtitle:
          '${used.length} ${pluralize(used.length, 'column is', 'columns are')} used'
          '${ignored.isEmpty && repeated.isEmpty ? '' : ', ${ignored.length + repeated.length} will be ignored'}.',
      gap: Sp.md,
      children: [
        if (used.isNotEmpty)
          _ChipGroup(label: 'Used', columns: used, tone: PillTone.success),
        if (repeated.isNotEmpty)
          _ChipGroup(label: 'Repeated, ignored', columns: repeated, tone: PillTone.warning),
        if (ignored.isNotEmpty)
          _ChipGroup(label: 'Not imported', columns: ignored, tone: PillTone.neutral),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.label, required this.columns, required this.tone});

  final String label;
  final List<ColumnReading> columns;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.labelMedium!.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: Sp.sm),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [for (final c in columns) StatusPill(c.label, tone: tone)],
        ),
      ],
    );
  }
}

class ImportPreviewRowTile extends StatelessWidget {
  const ImportPreviewRowTile({super.key, required this.row});

  final PreviewRow row;

  @override
  Widget build(BuildContext context) {
    final source = row.row;
    final title = source.title.isEmpty ? '(no name)' : source.title;
    final price = source.price;
    final details = row.allText;
    final meta = [
      if (source.categoryTitle.isNotEmpty) source.categoryTitle,
      if (price != null) _price(price),
    ].join('  ·  ');
    final subtitle = [
      if (meta.isNotEmpty) meta,
      ...details,
    ].join('\n');
    return ListRow(
      title: 'Row ${source.number}: $title',
      subtitle: subtitle.isEmpty ? null : subtitle,
      trailing: _statusPill(row),
    );
  }

  static String _price(double value) {
    final whole = value == value.roundToDouble();
    return 'BDT ${whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}';
  }

  static Widget _statusPill(PreviewRow row) {
    switch (row.status) {
      case RowStatus.error:
        return const StatusPill('Error', tone: PillTone.danger);
      case RowStatus.skip:
        return const StatusPill('Skip');
      case RowStatus.update:
        return StatusPill(
          row.hasWarning ? 'Update, check' : 'Update',
          tone: row.hasWarning ? PillTone.warning : PillTone.info,
        );
      case RowStatus.create:
        return StatusPill(
          row.hasWarning ? 'Create, check' : 'Create',
          tone: row.hasWarning ? PillTone.warning : PillTone.success,
        );
    }
  }
}

// ---- step 4: progress ------------------------------------------------------------------

class ImportProgressPanel extends StatelessWidget {
  const ImportProgressPanel({super.key, required this.session, required this.onCancel});

  final ImportSession session;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = session.percent;
    return FormSection(
      title: 'Importing your dishes',
      subtitle: 'Keep this screen open until it finishes.',
      children: [
        Semantics(
          label: 'Import progress $percent percent',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: 10,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${session.rowsDone} of ${session.rowsTotal} rows',
              style: withTabularFigures(context.textStyles.bodyMedium!),
            ),
            Text(
              '$percent%',
              style: withTabularFigures(context.textStyles.titleSmall!),
            ),
          ],
        ),
        if (session.batchLabel.isNotEmpty)
          Text(
            session.batchLabel,
            style: context.textStyles.bodySmall!.copyWith(color: context.palette.muted),
          ),
        if (session.tally.issues.isNotEmpty)
          ImportMessage(
            text:
                '${session.tally.issues.length} ${pluralize(session.tally.issues.length, 'row needs', 'rows need')} attention so far. '
                'You can download the report when the import ends.',
            tone: PillTone.warning,
          ),
        if (session.cancelRequested)
          const ImportMessage(
            text: 'Stopping after the batch that is being saved. Dishes already saved stay on your menu.',
          )
        else
          AppButton(
            label: 'Cancel import',
            kind: AppButtonKind.secondary,
            onPressed: onCancel,
          ),
      ],
    );
  }
}

// ---- step 5: result ----------------------------------------------------------------------

class ImportResultPanel extends StatelessWidget {
  const ImportResultPanel({
    super.key,
    required this.session,
    required this.onDownloadReport,
    required this.onImportAnother,
    required this.onDone,
  });

  final ImportSession session;
  final VoidCallback onDownloadReport;
  final VoidCallback onImportAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final outcome = session.outcome;
    final tone = outcome.stoppedEarly || outcome.hasProblems
        ? (outcome.saved == 0 ? PillTone.danger : PillTone.warning)
        : PillTone.success;
    final hasReport = session.issues.isNotEmpty;
    return FormSection(
      title: outcome.headline,
      children: [
        ImportMessage(text: outcome.detail, tone: tone),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [
            ImportCountChip(value: outcome.created, label: 'created', tone: PillTone.success),
            ImportCountChip(value: outcome.updated, label: 'updated', tone: PillTone.info),
            ImportCountChip(value: outcome.skipped, label: 'skipped'),
            ImportCountChip(
              value: outcome.failed,
              label: 'need attention',
              tone: outcome.failed > 0 ? PillTone.danger : PillTone.neutral,
            ),
            if (outcome.notSent > 0)
              ImportCountChip(value: outcome.notSent, label: 'not sent', tone: PillTone.warning),
          ],
        ),
        if (hasReport)
          ImportMessage(
            text:
                'The error report is a CSV with your original columns and a Problem column. '
                'Fix those rows, then import the report file again.',
          ),
        Wrap(
          spacing: Sp.md,
          runSpacing: Sp.md,
          children: [
            AppButton(label: 'Done', icon: Icons.check_rounded, onPressed: onDone),
            if (hasReport)
              AppButton(
                label: 'Download error report',
                icon: Icons.download_rounded,
                kind: AppButtonKind.secondary,
                onPressed: onDownloadReport,
              ),
            AppButton(
              label: 'Import another file',
              kind: AppButtonKind.text,
              onPressed: onImportAnother,
            ),
          ],
        ),
      ],
    );
  }
}

// ---- export ------------------------------------------------------------------------------------

class ExportPanel extends StatelessWidget {
  const ExportPanel({
    super.key,
    required this.scope,
    required this.branchName,
    required this.itemCount,
    required this.busy,
    required this.onScope,
    required this.onDownload,
    required this.onShare,
  });

  final ExportScope scope;

  /// The selected branch, or null when there is none.
  final String? branchName;
  final int itemCount;
  final bool busy;
  final ValueChanged<ExportScope> onScope;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scopeText = scope == ExportScope.all
        ? 'Every dish with its own regular values: prices, availability and visibility '
            'as set on the dish.'
        : 'Every dish as customers of ${branchName ?? 'this branch'} see it: that branch\'s '
            'prices, sold out state and hidden dishes.';
    return FormSection(
      title: 'Export your menu',
      subtitle: 'Opens in Excel, Google Sheets and Numbers. Bangla text is kept.',
      children: [
        if (branchName != null)
          SegmentedChoice<ExportScope>(
            label: 'What to export',
            value: scope,
            onChanged: onScope,
            options: [
              const ChoiceOption(value: ExportScope.all, label: 'All dishes'),
              ChoiceOption(value: ExportScope.branch, label: branchName!),
            ],
          ),
        Text(scopeText, style: context.textStyles.bodyMedium),
        ImportCountChip(
          value: itemCount,
          label: pluralize(itemCount, 'dish', 'dishes'),
          tone: PillTone.info,
        ),
        if (itemCount == 0)
          const ImportMessage(
            text: 'Your menu has no dishes yet, so the file would only contain the headers.',
            tone: PillTone.warning,
          ),
        Wrap(
          spacing: Sp.md,
          runSpacing: Sp.md,
          children: [
            AppButton(
              label: 'Download CSV',
              icon: Icons.download_rounded,
              loading: busy,
              onPressed: busy ? null : onDownload,
            ),
            AppButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              kind: AppButtonKind.secondary,
              onPressed: busy ? null : onShare,
            ),
          ],
        ),
      ],
    );
  }
}
