import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import '../shell/branch_switcher.dart';
import 'qr_logic.dart';
import 'qr_models.dart';
import 'qr_repository.dart';
import 'widgets/bulk_tables_sheet.dart';
import 'widgets/qr_list_parts.dart';

/// The QR and tables tab: the branch and takeaway codes, every table with its
/// own code, and the way to print them (plan 5.1, 10.1 and 19.6).
class QrTablesScreen extends ConsumerStatefulWidget {
  const QrTablesScreen({super.key});

  @override
  ConsumerState<QrTablesScreen> createState() => _QrTablesScreenState();
}

class _QrTablesScreenState extends ConsumerState<QrTablesScreen> {
  QrKind? _creating;

  Future<void> _refresh() async {
    ref.invalidate(qrOverviewProvider);
    try {
      await ref.read(qrOverviewProvider.future);
    } catch (_) {
      // The screen shows the error state itself.
    }
  }

  Future<void> _createCode(Branch branch, QrKind kind) async {
    setState(() => _creating = kind);
    final ok = await runWithToast(
      context,
      () async {
        await ref.read(qrRepositoryProvider).createCode(branchId: branch.id, kind: kind);
      },
      onError: friendlyError,
      successMessage: kind == QrKind.takeaway ? 'Takeaway code created' : 'Menu code created',
    );
    if (ok) refreshQr(ref);
    if (mounted) setState(() => _creating = null);
  }

  Future<void> _createTableCode(Branch branch, RestaurantTable table) async {
    final ok = await runWithToast(
      context,
      () async {
        await ref
            .read(qrRepositoryProvider)
            .createCode(branchId: branch.id, kind: QrKind.table, tableId: table.id);
      },
      onError: friendlyError,
      successMessage: 'Code created for ${table.name}',
    );
    if (ok) refreshQr(ref);
  }

  Future<void> _addSeveral(Branch branch, List<RestaurantTable> tables) async {
    final created = await showAppSheet<int>(
      context,
      title: 'Add several tables',
      builder: (_) => BulkTablesSheet(branchId: branch.id, tables: tables),
    );
    if (created == null || !mounted) return;
    refreshQr(ref);
    showToast(context, created == 1 ? '1 table added' : '$created tables added');
  }

  Future<void> _toggleTable(RestaurantTable table) async {
    final ok = await runWithToast(
      context,
      () => ref.read(qrRepositoryProvider).setTableActive(table.id, !table.isActive),
      onError: friendlyError,
      successMessage: table.isActive ? '${table.name} turned off' : '${table.name} turned on',
    );
    if (ok) refreshQr(ref);
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${table.name}?',
      message:
          'The table and its QR code are removed for good. Printed copies of '
          'that code will stop working. To keep the table but stop customers '
          'using it for now, turn it off instead.',
      confirmLabel: 'Delete table',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runWithToast(
      context,
      () => ref.read(qrRepositoryProvider).deleteTable(table.id),
      onError: friendlyError,
      successMessage: '${table.name} deleted',
    );
    if (done) refreshQr(ref);
  }

  void _onTableAction(Branch branch, RestaurantTable table, QrCode? code, TableAction action) {
    switch (action) {
      case TableAction.viewCode:
        if (code != null) context.push(AppRoutes.qrDetail(code.id));
      case TableAction.createCode:
        _createTableCode(branch, table);
      case TableAction.edit:
        context.push(AppRoutes.tableEdit(table.id));
      case TableAction.toggle:
        _toggleTable(table);
      case TableAction.delete:
        _deleteTable(table);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(selectedBranchProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final overviewAsync = ref.watch(qrOverviewProvider);

    final Widget content;
    if (branch == null) {
      content = const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No branch yet',
        message: 'Add a branch first. Every branch gets its own QR code.',
      );
    } else {
      content = overviewAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(Sp.lg),
          child: SkeletonList(rows: 5),
        ),
        error: (error, _) => ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(qrOverviewProvider),
        ),
        data: (overview) => _body(branch, branches, overview ?? const QrOverview()),
      );
    }

    return AppPage(
      title: 'QR and tables',
      subtitle: branch == null
          ? null
          : (branches.length > 1 ? 'Showing ${branch.name}' : branch.name),
      scroll: false,
      body: RefreshIndicator(onRefresh: _refresh, child: content),
      actions: [
        IconButton(
          tooltip: 'Print QR codes',
          icon: const Icon(Icons.print_outlined),
          onPressed: branch == null ? null : () => context.push(AppRoutes.qrPrint),
        ),
        IconButton(
          tooltip: 'Add table',
          icon: const Icon(Icons.add_rounded),
          onPressed: branch == null ? null : () => context.push(AppRoutes.tableNew),
        ),
      ],
    );
  }

  Widget _body(Branch branch, List<Branch> branches, QrOverview overview) {
    final now = DateTime.now();
    final groups = groupTablesByZone(overview.tables);
    final hasZones = groups.any((group) => group.zone != null);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
      children: [
        if (branches.length > 1) ...[
          const Align(alignment: Alignment.centerLeft, child: BranchSwitcher()),
          const SizedBox(height: Sp.lg),
        ],
        if (!PublicLinks.isConfigured) const QrLinkWarning(),
        QrSummaryRow(
          activeCodes: overview.activeCodes,
          totalScans: overview.totalScans,
          tableCount: overview.tables.length,
        ),
        const SizedBox(height: Sp.xl),
        ListGroup(
          title: 'Menu codes',
          children: [
            QrCodeRow(
              icon: Icons.storefront_outlined,
              title: 'Branch menu',
              emptyHint: 'One code for the whole menu, for the door or a poster.',
              code: overview.branchCode,
              now: now,
              creating: _creating == QrKind.branch,
              onOpen: () => context.push(AppRoutes.qrDetail(overview.branchCode!.id)),
              onCreate: () => _createCode(branch, QrKind.branch),
            ),
            QrCodeRow(
              icon: Icons.shopping_bag_outlined,
              title: 'Takeaway counter',
              emptyHint: 'For the pickup counter or a takeaway flyer.',
              code: overview.takeawayCode,
              now: now,
              creating: _creating == QrKind.takeaway,
              onOpen: () => context.push(AppRoutes.qrDetail(overview.takeawayCode!.id)),
              onCreate: () => _createCode(branch, QrKind.takeaway),
            ),
          ],
        ),
        ListGroup(
          children: [
            ListRow(
              leading: const IconBadge(Icons.print_outlined),
              title: 'Print or download all codes',
              subtitle: 'Cards for tables, the counter and the entrance, as a PDF',
              showChevron: true,
              onTap: () => context.push(AppRoutes.qrPrint),
            ),
          ],
        ),
        SectionTitle(
          'Tables',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _addSeveral(branch, overview.tables),
                child: const Text('Add several'),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.tableNew),
                child: const Text('Add table'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.sm),
        if (overview.tables.isEmpty)
          _NoTables(
            onAdd: () => context.push(AppRoutes.tableNew),
            onAddSeveral: () => _addSeveral(branch, overview.tables),
          )
        else
          for (final group in groups)
            ListGroup(
              title: hasZones ? group.title : null,
              children: [
                for (final table in group.tables)
                  TableRowTile(
                    key: ValueKey(table.id),
                    table: table,
                    code: overview.tableCodes[table.id],
                    now: now,
                    onOpen: () {
                      final code = overview.tableCodes[table.id];
                      context.push(
                        code == null
                            ? AppRoutes.tableEdit(table.id)
                            : AppRoutes.qrDetail(code.id),
                      );
                    },
                    onAction: (action) =>
                        _onTableAction(branch, table, overview.tableCodes[table.id], action),
                  ),
              ],
            ),
        if (overview.inactiveCodes > 0)
          Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(
              overview.inactiveCodes == 1
                  ? '1 old code is switched off. Scanning it shows a notice.'
                  : '${overview.inactiveCodes} old codes are switched off. Scanning them shows a notice.',
              style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
            ),
          ),
      ],
    );
  }
}

class _NoTables extends StatelessWidget {
  const _NoTables({required this.onAdd, required this.onAddSeveral});

  final VoidCallback onAdd;
  final VoidCallback onAddSeveral;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.xl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          const IconBadge(Icons.table_restaurant_outlined, size: 56),
          const SizedBox(height: Sp.md),
          Text('No tables yet', style: context.textStyles.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Add your tables and each one gets its own QR code. A customer who '
            'scans it opens the menu for that table. Skip this if you only '
            'serve takeaway.',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Sp.lg),
          AppButton(label: 'Add several tables', icon: Icons.add_rounded, onPressed: onAddSeveral),
          const SizedBox(height: Sp.sm),
          AppButton(label: 'Add one table', kind: AppButtonKind.text, onPressed: onAdd),
        ],
      ),
    );
  }
}
