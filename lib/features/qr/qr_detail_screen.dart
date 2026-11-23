import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import 'qr_assets.dart';
import 'qr_export.dart';
import 'qr_logic.dart';
import 'qr_models.dart';
import 'qr_pdf.dart';
import 'qr_render.dart';
import 'qr_repository.dart';
import 'widgets/qr_card_preview.dart';
import 'widgets/qr_detail_parts.dart';
import 'widgets/qr_list_parts.dart';

/// One QR code: how the card looks, its link, downloads, print, scan numbers,
/// and the controls to replace or switch it off (plan 5.1 and 19.6).
class QrDetailScreen extends ConsumerStatefulWidget {
  const QrDetailScreen({super.key, required this.qrId});

  final String qrId;

  @override
  ConsumerState<QrDetailScreen> createState() => _QrDetailScreenState();
}

class _QrDetailScreenState extends ConsumerState<QrDetailScreen> {
  bool _showLogo = true;
  QrBusy? _busy;

  Future<void> _run(QrBusy key, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await action();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ---- downloads and print ----

  Future<void> _saveCardPng(QrCardSpec spec, String name) => _run(QrBusy.png, () async {
    final bytes = await renderQrCard(spec, aspect: 0.7, pixelWidth: 1080);
    if (!mounted) return;
    await saveQrFile(
      context,
      name: name,
      bytes: bytes,
      kind: QrFileKind.png,
      successMessage: 'Card image saved',
    );
  });

  Future<void> _saveCodeOnly(QrCardSpec spec, String name) => _run(QrBusy.plain, () async {
    final bytes = await renderQrPng(spec.link, size: 1024, logo: spec.logo);
    if (!mounted) return;
    await saveQrFile(
      context,
      name: '$name-code',
      bytes: bytes,
      kind: QrFileKind.png,
      successMessage: 'QR image saved',
    );
  });

  Future<Uint8List> _pdfFor(QrCardSpec spec) => buildPrintPdf(cards: [spec], perPage: 1);

  Future<void> _savePdf(QrCardSpec spec, String name) => _run(QrBusy.pdf, () async {
    final bytes = await _pdfFor(spec);
    if (!mounted) return;
    await saveQrFile(
      context,
      name: name,
      bytes: bytes,
      kind: QrFileKind.pdf,
      successMessage: 'Print file saved',
    );
  });

  Future<void> _print(QrCardSpec spec, String name) => _run(QrBusy.print, () async {
    final bytes = await _pdfFor(spec);
    await printQrPdf(bytes, name: name);
  });

  Future<void> _shareImage(QrCardSpec spec, String name) => _run(QrBusy.share, () async {
    final bytes = await renderQrCard(spec, aspect: 0.7, pixelWidth: 1080);
    if (!mounted) return;
    await shareQrFile(context, name: name, bytes: bytes, kind: QrFileKind.png, subject: spec.title);
  });

  // ---- link ----

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showToast(context, 'Link copied');
  }

  // ---- manage ----

  Future<void> _regenerate(QrCode code) async {
    final ok = await confirmAction(
      context,
      title: 'Replace this code?',
      message:
          'A new code is made and the current one stops working at once. '
          'Printed copies of the old code will show a notice instead of the '
          'menu, so print the new one and swap them.',
      confirmLabel: 'Replace code',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(QrBusy.manage, () async {
      final fresh = await ref.read(qrRepositoryProvider).regenerate(code.id);
      refreshQr(ref);
      if (!mounted) return;
      showToast(context, 'New code ready. Print it and replace the old one.');
      context.pushReplacement(AppRoutes.qrDetail(fresh.id));
    });
  }

  Future<void> _setActive(QrCode code, bool active) async {
    if (!active) {
      final ok = await confirmAction(
        context,
        title: 'Switch off this code?',
        message:
            'Customers who scan it will see a notice instead of the menu. You '
            'can switch it on again later.',
        confirmLabel: 'Switch off',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    await _run(QrBusy.manage, () async {
      final repository = ref.read(qrRepositoryProvider);
      if (active) {
        await repository.reactivate(code.id);
      } else {
        await repository.deactivate(code.id);
      }
      ref.invalidate(qrDetailProvider(code.id));
      refreshQr(ref);
      if (mounted) showToast(context, active ? 'Code switched on' : 'Code switched off');
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(qrDetailProvider(widget.qrId));
    return detailAsync.when(
      skipLoadingOnReload: true,
      loading: () => const AppPage(title: 'QR code', scroll: false, body: LoadingView()),
      error: (error, _) => AppPage(
        title: 'QR code',
        scroll: false,
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(qrDetailProvider(widget.qrId)),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return const AppPage(
            title: 'QR code',
            scroll: false,
            body: EmptyState(
              icon: Icons.qr_code_2_rounded,
              title: 'Code not found',
              message: 'It may have been deleted along with its table.',
            ),
          );
        }
        return _content(detail);
      },
    );
  }

  Widget _content(QrDetail detail) {
    final code = detail.code;
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    var branchName = 'Branch';
    for (final branch in branches) {
      if (branch.id == code.branchId) branchName = branch.name;
    }
    final target = printTargetFor(code, detail.table, branchName);
    final logoUrl = business?.logoUrl;
    final hasLogo = logoUrl != null && logoUrl.trim().isNotEmpty;
    final logo = (_showLogo && hasLogo) ? ref.watch(qrLogoProvider(logoUrl)).valueOrNull : null;
    final link = PublicLinks.qr(code.token);
    final spec = QrCardSpec(
      link: link,
      title: target.title,
      subtitle: target.subtitle,
      businessName: business?.name ?? 'EZ Menu',
      accent: hexToColor(business?.brandColor),
      logo: logo,
    );
    final fileName = qrFileName(
      kind: code.kind,
      branchName: branchName,
      tableName: detail.table?.name,
    );
    final active = code.isActive;
    final palette = context.palette;

    return AppPage(
      title: qrDisplayName(code, detail.table),
      subtitle: qrKindLabel(code.kind),
      onRefresh: () async => ref.invalidate(qrDetailProvider(widget.qrId)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!PublicLinks.isConfigured) const QrLinkWarning(),
          QrCardPreview(spec: spec),
          const SizedBox(height: Sp.md),
          Center(
            child: active
                ? const StatusPill('Active', tone: PillTone.success)
                : const StatusPill('Switched off', tone: PillTone.warning),
          ),
          if (!active) ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Customers who scan this code see a notice instead of the menu.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(color: palette.warning),
            ),
          ],
          const SizedBox(height: Sp.xl),
          FormSection(
            title: 'Link',
            subtitle: 'This is the address the code opens.',
            children: [
              SelectableText(link, style: context.textStyles.bodyMedium),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Copy',
                      icon: Icons.copy_rounded,
                      kind: AppButtonKind.secondary,
                      onPressed: () => _copyLink(link),
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Open',
                      icon: Icons.open_in_new_rounded,
                      kind: AppButtonKind.secondary,
                      onPressed: active ? () => openUrl(link) : null,
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Share',
                      icon: Icons.ios_share_rounded,
                      kind: AppButtonKind.secondary,
                      onPressed: () => Share.share(link, subject: '${spec.businessName} menu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          if (hasLogo) ...[
            FormSection(
              children: [
                SwitchRow(
                  title: 'Show my logo',
                  subtitle: 'On the card and in the middle of the code.',
                  value: _showLogo,
                  onChanged: (value) => setState(() => _showLogo = value),
                ),
              ],
            ),
            const SizedBox(height: Sp.xl),
          ],
          ListGroup(
            title: 'Download and print',
            children: [
              QrActionRow(
                icon: Icons.print_outlined,
                title: 'Print',
                subtitle: 'Opens the print dialog on A4 paper',
                busy: _busy == QrBusy.print,
                enabled: active,
                onTap: () => _print(spec, fileName),
              ),
              QrActionRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Download print file',
                subtitle: 'PDF, one card on an A4 page',
                busy: _busy == QrBusy.pdf,
                enabled: active,
                onTap: () => _savePdf(spec, fileName),
              ),
              QrActionRow(
                icon: Icons.image_outlined,
                title: 'Download card image',
                subtitle: 'PNG with the name and instructions',
                busy: _busy == QrBusy.png,
                enabled: active,
                onTap: () => _saveCardPng(spec, fileName),
              ),
              QrActionRow(
                icon: Icons.qr_code_2_rounded,
                title: 'Download code only',
                subtitle: 'Plain PNG for a designer or print shop',
                busy: _busy == QrBusy.plain,
                enabled: active,
                onTap: () => _saveCodeOnly(spec, fileName),
              ),
              QrActionRow(
                icon: Icons.ios_share_rounded,
                title: 'Share card image',
                subtitle: 'Send it in a chat or email',
                busy: _busy == QrBusy.share,
                enabled: active,
                onTap: () => _shareImage(spec, fileName),
              ),
            ],
          ),
          QrFacts(detail: detail, branchName: branchName, now: DateTime.now()),
          ListGroup(
            title: 'Manage',
            children: [
              if (detail.table != null)
                ListRow(
                  leading: const IconBadge(Icons.edit_outlined),
                  title: 'Edit table',
                  subtitle: 'Name, seats, zone and whether it is in use',
                  showChevron: true,
                  onTap: () => context.push(AppRoutes.tableEdit(detail.table!.id)),
                ),
              if (active)
                ListRow(
                  leading: const IconBadge(Icons.autorenew_rounded),
                  title: 'Replace with a new code',
                  subtitle:
                      'Use this if a printed code was copied or misused. The old one stops working.',
                  showChevron: true,
                  onTap: _busy == null ? () => _regenerate(code) : null,
                ),
              ListRow(
                leading: IconBadge(
                  active ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                  color: active ? palette.danger : null,
                  background: active ? palette.dangerSoft : null,
                ),
                title: active ? 'Switch off' : 'Switch on',
                titleColor: active ? palette.danger : null,
                subtitle: active
                    ? 'Scanning shows a notice. You can switch it on again.'
                    : 'Works only while no other code is active in the same place.',
                showChevron: true,
                onTap: _busy == null ? () => _setActive(code, !active) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
