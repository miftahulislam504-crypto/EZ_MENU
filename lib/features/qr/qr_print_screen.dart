import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import 'qr_assets.dart';
import 'qr_export.dart';
import 'qr_logic.dart';
import 'qr_models.dart';
import 'qr_pdf.dart';
import 'qr_render.dart';
import 'qr_repository.dart';
import 'widgets/print_options.dart';
import 'widgets/qr_card_preview.dart';
import 'widgets/qr_list_parts.dart';

enum _Output { print, download, share }

/// Choose which codes to print and how many fit on a page, then print, save a
/// PDF or share it (plan 5.1: print-ready format).
class QrPrintScreen extends ConsumerStatefulWidget {
  const QrPrintScreen({super.key});

  @override
  ConsumerState<QrPrintScreen> createState() => _QrPrintScreenState();
}

class _QrPrintScreenState extends ConsumerState<QrPrintScreen> {
  PrintSelection _selection = const PrintSelection();
  PrintTableMode _mode = PrintTableMode.all;
  int _perPage = 4;
  bool _showLogo = true;
  bool _seeded = false;

  _Output? _working;
  int _done = 0;
  int _total = 0;

  // The last PDF, reused when the same choices are printed and then saved.
  String? _cachedKey;
  Uint8List? _cachedPdf;

  /// Starts with everything that exists selected, once the codes are known.
  void _seed(QrOverview overview) {
    if (_seeded) return;
    _seeded = true;
    _selection = PrintSelection(
      includeBranch: overview.branchCode != null,
      includeTakeaway: false,
      allTables: overview.tableCodes.isNotEmpty,
    );
    _mode = overview.tableCodes.isNotEmpty ? PrintTableMode.all : PrintTableMode.none;
  }

  PrintSelection _effective(PrintSelection selection) {
    switch (_mode) {
      case PrintTableMode.none:
        return selection.copyWith(allTables: false, pickedTableIds: const {});
      case PrintTableMode.all:
        return selection.copyWith(allTables: true);
      case PrintTableMode.pick:
        return selection.copyWith(allTables: false);
    }
  }

  Future<Uint8List> _pdf(List<QrCardSpec> specs, String key) async {
    if (_cachedKey == key && _cachedPdf != null) return _cachedPdf!;
    final bytes = await buildPrintPdf(
      cards: specs,
      perPage: _perPage,
      onProgress: (done, total) {
        if (mounted) setState(() {
          _done = done;
          _total = total;
        });
      },
    );
    _cachedKey = key;
    _cachedPdf = bytes;
    return bytes;
  }

  Future<void> _output(_Output output, List<QrCardSpec> specs, String key, String fileName) async {
    if (_working != null || specs.isEmpty) return;
    setState(() {
      _working = output;
      _done = 0;
      _total = specs.length;
    });
    try {
      final bytes = await _pdf(specs, key);
      if (!mounted) return;
      switch (output) {
        case _Output.print:
          await printQrPdf(bytes, name: fileName);
        case _Output.download:
          await saveQrFile(
            context,
            name: fileName,
            bytes: bytes,
            kind: QrFileKind.pdf,
            successMessage: 'Print file saved',
          );
        case _Output.share:
          await shareQrFile(context, name: fileName, bytes: bytes, kind: QrFileKind.pdf);
      }
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(selectedBranchProvider);
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final overviewAsync = ref.watch(qrOverviewProvider);

    if (branch == null) {
      return const AppPage(
        title: 'Print QR codes',
        scroll: false,
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'No branch yet',
          message: 'Add a branch first. Every branch gets its own QR code.',
        ),
      );
    }
    final overview = overviewAsync.valueOrNull;
    if (overview == null) {
      return AppPage(
        title: 'Print QR codes',
        subtitle: branch.name,
        scroll: false,
        body: overviewAsync.hasError
            ? ErrorState(
                message: friendlyError(overviewAsync.error),
                onRetry: () => ref.invalidate(qrOverviewProvider),
              )
            : const LoadingView(),
      );
    }
    _seed(overview);
    return _content(branch, business, overview);
  }

  Widget _content(Branch branch, Business? business, QrOverview overview) {
    final selection = _effective(_selection);
    final targets = resolvePrintTargets(
      selection: selection,
      overview: overview,
      branchName: branch.name,
    );
    final grid = printGridFor(_perPage);
    final pages = pageCount(targets.length, grid.perPage);

    final logoUrl = business?.logoUrl;
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    final logo = (_showLogo && hasLogo) ? ref.watch(qrLogoProvider(logoUrl)).valueOrNull : null;
    final specs = [
      for (final target in targets)
        QrCardSpec(
          link: PublicLinks.qr(target.code.token),
          title: target.title,
          subtitle: target.subtitle,
          businessName: business?.name ?? 'EZ Menu',
          accent: hexToColor(business?.brandColor),
          logo: logo,
        ),
    ];
    final key = [
      _perPage,
      logo == null ? 'plain' : 'logo',
      business?.name,
      business?.brandColor,
      for (final target in targets) '${target.code.token}:${target.title}:${target.subtitle}',
    ].join('|');
    final fileName = qrPrintFileName(branch.name);
    final working = _working;
    final canOutput = specs.isNotEmpty && working == null;
    final tablesWithCode = [
      for (final table in overview.tables)
        if (overview.tableCodes.containsKey(table.id)) table,
    ];
    final missing = overview.tables.length - tablesWithCode.length;

    return AppPage(
      title: 'Print QR codes',
      subtitle: branch.name,
      bottomBar: StickyActionBar(
        child: working != null
            ? _Progress(done: _done, total: _total)
            : Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Share',
                      icon: Icons.ios_share_rounded,
                      kind: AppButtonKind.secondary,
                      onPressed: canOutput
                          ? () => _output(_Output.share, specs, key, fileName)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Save PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      kind: AppButtonKind.secondary,
                      onPressed: canOutput
                          ? () => _output(_Output.download, specs, key, fileName)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Print',
                      icon: Icons.print_outlined,
                      onPressed: canOutput
                          ? () => _output(_Output.print, specs, key, fileName)
                          : null,
                    ),
                  ),
                ],
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!PublicLinks.isConfigured) const QrLinkWarning(),
          PrintWhatSection(
            overview: overview,
            selection: _selection,
            mode: _mode,
            missingCodes: missing,
            onSelection: (value) => setState(() => _selection = value),
            onMode: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: Sp.xl),
          FormSection(
            title: 'Layout',
            subtitle: 'Cards are printed on A4 paper with a dashed line to cut along.',
            children: [
              PrintPerPageChoice(
                value: _perPage,
                onChanged: (value) => setState(() => _perPage = value),
              ),
              if (hasLogo)
                SwitchRow(
                  title: 'Show my logo',
                  subtitle: 'On every card and in the middle of each code.',
                  value: _showLogo,
                  onChanged: (value) => setState(() => _showLogo = value),
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          if (specs.isEmpty)
            const EmptyState(
              icon: Icons.print_disabled_outlined,
              title: 'Nothing selected',
              message: 'Choose at least one code above to see how the cards will look.',
            )
          else ...[
            SectionTitle(
              'Preview',
              trailing: Text(
                '${targets.length} ${targets.length == 1 ? 'card' : 'cards'} on '
                '$pages ${pages == 1 ? 'page' : 'pages'}',
                style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
              ),
            ),
            const SizedBox(height: Sp.md),
            QrCardPreview(
              spec: specs.first,
              aspect: printCardAspect(grid),
              maxWidth: grid.aspectRatio > 1 ? 420 : 280,
            ),
            const SizedBox(height: Sp.sm),
            Text(
              targets.length == 1
                  ? 'This is how the card will look.'
                  : 'First card shown. The others look the same with their own name and code.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? null : done / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0 ? 'Preparing cards' : 'Preparing card $done of $total',
          style: context.textStyles.titleSmall,
        ),
        const SizedBox(height: Sp.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: fraction, minHeight: 6),
        ),
      ],
    );
  }
}
