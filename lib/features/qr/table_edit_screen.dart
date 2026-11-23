import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/widgets.dart';
import 'qr_logic.dart';
import 'qr_models.dart';
import 'qr_repository.dart';

/// Add or edit one table: name, seats, zone and whether it is in use. A new
/// table gets its own QR code automatically (plan 10.1).
class TableEditScreen extends ConsumerStatefulWidget {
  const TableEditScreen({super.key, this.tableId});

  final String? tableId;

  @override
  ConsumerState<TableEditScreen> createState() => _TableEditScreenState();
}

class _TableEditScreenState extends ConsumerState<TableEditScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final ControllerBag _c = ControllerBag();
  final FocusNode _nameFocus = FocusNode();

  bool _initialized = false;
  bool _isActive = true;
  bool _saving = false;
  bool _allowPop = false;
  String _initialSnapshot = '';

  bool get _editing => widget.tableId != null;

  @override
  void dispose() {
    _c.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String _snapshot() => [_c.text('name'), _c.text('zone'), _c.text('capacity'), '$_isActive'].join('|');

  bool get _dirty => _initialized && _snapshot() != _initialSnapshot;

  void _initialize(RestaurantTable? existing, List<RestaurantTable> tables) {
    if (_initialized) return;
    if (existing != null) {
      _c.fill({
        'name': existing.name,
        'zone': existing.zone,
        'capacity': existing.capacity?.toString(),
      });
      _isActive = existing.isActive;
    } else {
      _c.fill({'name': suggestNextTableName([for (final t in tables) t.name])});
    }
    _initialized = true;
    _initialSnapshot = _snapshot();
  }

  Future<void> _save({
    required String branchId,
    required List<RestaurantTable> tables,
    RestaurantTable? existing,
    bool addAnother = false,
  }) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final zone = _c.nullable('zone');
    final values = RestaurantTable(
      id: existing?.id ?? '',
      branchId: branchId,
      name: _c.text('name'),
      capacity: parseCapacity(_c.text('capacity')),
      zone: zone,
      isActive: _isActive,
      sortOrder: existing?.sortOrder ?? nextSortOrder(tables),
    );
    setState(() => _saving = true);
    final repository = ref.read(qrRepositoryProvider);
    final ok = await runWithToast(
      context,
      () async {
        if (existing == null) {
          await repository.createTable(branchId, values);
        } else {
          await repository.updateTable(values);
        }
      },
      onError: friendlyError,
      successMessage: existing == null ? '${values.name} added with its QR code' : 'Table saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    refreshQr(ref);
    if (existing != null) ref.invalidate(restaurantTableProvider(existing.id));

    if (addAnother) {
      // Keep zone and seats (tables next to each other are usually alike) and
      // offer the next name.
      final names = [for (final t in tables) t.name, values.name];
      setState(() {
        _c['name'].text = suggestNextTableName(names);
        _initialSnapshot = _snapshot();
      });
      _nameFocus.requestFocus();
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrGo(context, AppRoutes.qr);
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You have changes that are not saved yet.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!leave || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrGo(context, AppRoutes.qr);
    });
  }

  Future<void> _delete(RestaurantTable table) async {
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
    if (!done || !mounted) return;
    refreshQr(ref);
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrGo(context, AppRoutes.qr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Edit table' : 'New table';
    final overviewAsync = ref.watch(qrOverviewProvider);
    final branch = ref.watch(selectedBranchProvider);
    final tableAsync = _editing ? ref.watch(restaurantTableProvider(widget.tableId!)) : null;

    if (overviewAsync.isLoading && !overviewAsync.hasValue ||
        (tableAsync != null && tableAsync.isLoading && !tableAsync.hasValue)) {
      return AppPage(title: title, scroll: false, body: const SkeletonList(rows: 4));
    }
    final error = overviewAsync.error ?? tableAsync?.error;
    if (error != null && !overviewAsync.hasValue) {
      return AppPage(
        title: title,
        scroll: false,
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () {
            ref.invalidate(qrOverviewProvider);
            if (_editing) ref.invalidate(restaurantTableProvider(widget.tableId!));
          },
        ),
      );
    }

    final overview = overviewAsync.valueOrNull ?? const QrOverview();
    final existing = tableAsync?.valueOrNull;
    if (_editing && existing == null) {
      return AppPage(
        title: title,
        scroll: false,
        body: const EmptyState(
          icon: Icons.table_restaurant_outlined,
          title: 'Table not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final branchId = existing?.branchId ?? branch?.id;
    if (branchId == null) {
      return AppPage(
        title: title,
        scroll: false,
        body: const EmptyState(
          icon: Icons.storefront_outlined,
          title: 'No branch yet',
          message: 'Add a branch first. Tables belong to a branch.',
        ),
      );
    }
    final tables = overview.tables;
    _initialize(existing, tables);
    final zones = zoneSuggestions(tables);
    final code = existing == null ? null : overview.tableCodes[existing.id];

    return PopScope(
      canPop: !_dirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: AppPage(
        title: title,
        subtitle: existing?.name,
        bottomBar: StickyActionBar(
          child: Row(
            children: [
              if (!_editing) ...[
                Expanded(
                  child: AppButton(
                    label: 'Save and add another',
                    kind: AppButtonKind.secondary,
                    onPressed: _saving
                        ? null
                        : () => _save(branchId: branchId, tables: tables, addAnother: true),
                  ),
                ),
                const SizedBox(width: Sp.md),
              ],
              Expanded(
                child: AppButton(
                  label: _editing ? 'Save changes' : 'Add table',
                  loading: _saving,
                  onPressed: () => _save(branchId: branchId, tables: tables, existing: existing),
                ),
              ),
            ],
          ),
        ),
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'Table',
                subtitle: _editing
                    ? null
                    : 'A QR code for this table is made when you save.',
                children: [
                  AppTextField(
                    label: 'Name or number',
                    controller: _c['name'],
                    focusNode: _nameFocus,
                    hint: 'T1, 12 or Window 3',
                    maxLength: tableNameMaxLength,
                    autofocus: !_editing,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final problem = validateTableName(value);
                      if (problem != null) return problem;
                      if (tableNameTaken(value ?? '', tables, exceptId: existing?.id)) {
                        return 'Another table in this branch already uses this name.';
                      }
                      return null;
                    },
                  ),
                  AppTextField(
                    label: 'Seats',
                    controller: _c['capacity'],
                    hint: '4',
                    optional: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: validateCapacity,
                  ),
                  AppTextField(
                    label: 'Zone',
                    controller: _c['zone'],
                    hint: 'Ground floor, Rooftop, AC zone',
                    helper: 'Tables in the same zone are listed together.',
                    optional: true,
                    maxLength: tableZoneMaxLength,
                    validator: validateZone,
                  ),
                  if (zones.isNotEmpty)
                    Wrap(
                      spacing: Sp.sm,
                      runSpacing: Sp.xs,
                      children: [
                        for (final zone in zones)
                          ActionChip(
                            label: Text(zone),
                            onPressed: () => setState(() => _c['zone'].text = zone),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: Sp.xl),
              FormSection(
                children: [
                  SwitchRow(
                    title: 'Table is in use',
                    subtitle:
                        'Turn off for a table that is out of service. Scanning its '
                        'QR code then shows a notice.',
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: Sp.xl),
                ListGroup(
                  children: [
                    if (code != null)
                      ListRow(
                        leading: const IconBadge(Icons.qr_code_2_rounded),
                        title: 'View QR code',
                        subtitle: 'Download, print or share this table\'s code',
                        showChevron: true,
                        onTap: () => context.push(AppRoutes.qrDetail(code.id)),
                      ),
                    ListRow(
                      leading: IconBadge(
                        Icons.delete_outline_rounded,
                        color: context.palette.danger,
                        background: context.palette.dangerSoft,
                      ),
                      title: 'Delete table',
                      titleColor: context.palette.danger,
                      subtitle: 'Removes the table and its QR code for good',
                      showChevron: true,
                      onTap: _saving ? null : () => _delete(existing),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
