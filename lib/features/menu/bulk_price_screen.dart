import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/price_adjust.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'bulk_price_undo.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/bulk_price_change.dart';
import 'widgets/bulk_price_review.dart';
import 'widgets/bulk_price_select.dart';
import 'widgets/menu_ui.dart';

/// Change the price of many dishes at once: choose the dishes, choose the
/// change, review and apply. The change can be undone while the app is open.
class BulkPriceScreen extends ConsumerStatefulWidget {
  const BulkPriceScreen({super.key});

  @override
  ConsumerState<BulkPriceScreen> createState() => _BulkPriceScreenState();
}

class _BulkPriceScreenState extends ConsumerState<BulkPriceScreen> {
  final TextEditingController _value = TextEditingController();

  Set<String> _selected = <String>{};
  bool _seeded = false;
  PriceChangeMode _mode = PriceChangeMode.percentIncrease;
  PriceTarget _target = PriceTarget.price;
  bool _roundWhole = false;
  String? _branchId;
  bool _applying = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  /// Takes over the dishes picked on the dish list, once.
  void _seed(List<MenuItem> items) {
    if (_seeded) return;
    _seeded = true;
    final preset = ref.read(bulkPriceSelectionProvider);
    if (preset.isEmpty) return;
    final known = {for (final item in items) item.id};
    _selected = preset.where(known.contains).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bulkPriceSelectionProvider.notifier).clear();
    });
  }

  String _scopeText(PriceChange change, String? branchName) {
    final what = switch (change.target) {
      PriceTarget.price => 'regular prices',
      PriceTarget.discount => 'discount prices',
      PriceTarget.both => 'regular and discount prices',
    };
    final how = switch (change.mode) {
      PriceChangeMode.percentIncrease => 'increase by ${_n(change.value)}%',
      PriceChangeMode.percentDecrease => 'decrease by ${_n(change.value)}%',
      PriceChangeMode.fixedIncrease => 'increase by ${_n(change.value)}',
      PriceChangeMode.fixedDecrease => 'decrease by ${_n(change.value)}',
      PriceChangeMode.setExact => 'become ${_n(change.value)}',
    };
    final where = branchName == null ? '' : ' at $branchName only';
    return 'The $what $how$where.';
  }

  String _n(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _apply(
    List<PriceRow> rows,
    PriceChange change,
    Branch? branch,
  ) async {
    final ids = idsToApply(rows);
    if (ids.isEmpty) return;
    final confirmed = await confirmAction(
      context,
      title: 'Change the price of ${ids.length} dish${ids.length == 1 ? '' : 'es'}?',
      message: '${_scopeText(change, branch?.name)} You can undo this until you close the app.',
      confirmLabel: 'Apply',
    );
    if (!confirmed || !mounted) return;

    setState(() => _applying = true);
    final repo = ref.read(menuRepositoryProvider);
    try {
      var before = <String, BranchItemSetting?>{};
      final branchId = change.branchId;
      if (branchId != null) {
        final fresh = await repo.branchSettingsForBranch(branchId);
        before = {for (final id in ids) id: fresh[id]};
      }
      await repo.bulkAdjustPrices(
        itemIds: ids,
        mode: change.mode.sql,
        value: change.value,
        target: change.target.sql,
        roundWhole: change.roundWhole,
        branchId: branchId,
      );
      final snapshot = PriceSnapshot(
        rows: [for (final row in rows) if (row.changed) row],
        appliedAt: DateTime.now(),
        branchId: branchId,
        branchName: branch?.name,
        branchBefore: before,
      );
      ref.read(priceUndoProvider.notifier).remember(snapshot);
      ref.refreshMenu();
      ref.read(bulkPriceSelectionProvider.notifier).clear();
      if (!mounted) return;
      setState(() {
        _selected = <String>{};
        _value.clear();
      });
      showUndoToast(
        context,
        'Prices updated for ${ids.length} dish${ids.length == 1 ? '' : 'es'}',
        onUndo: () => _undo(snapshot),
        onError: friendlyError,
      );
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    }
    if (mounted) setState(() => _applying = false);
  }

  Future<void> _undo(PriceSnapshot snapshot) async {
    await undoPriceChange(ref.read(menuRepositoryProvider), snapshot);
    ref.read(priceUndoProvider.notifier).forget();
    ref.refreshMenu();
    if (mounted) showToast(context, 'Previous prices restored');
  }

  Widget _lastChangeCard(BuildContext context, PriceSnapshot snapshot) {
    final palette = context.palette;
    final time = TimeOfDay.fromDateTime(snapshot.appliedAt).format(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.lg),
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: palette.successSoft,
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: palette.success),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prices updated for ${snapshot.count} dish${snapshot.count == 1 ? '' : 'es'}',
                  style: context.textStyles.titleSmall,
                ),
                Text(
                  'At $time${snapshot.branchName == null ? '' : ' for ${snapshot.branchName}'}. '
                  'Undo works until you close the app.',
                  style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _undo(snapshot);
              } catch (error) {
                if (mounted) showToast(context, friendlyError(error), isError: true);
              }
            },
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final currency = ref.watch(currentBusinessProvider).valueOrNull?.currency ?? 'BDT';
    final lastChange = ref.watch(priceUndoProvider);

    final items = itemsAsync.valueOrNull;
    final categories = categoriesAsync.valueOrNull;
    if (items == null || categories == null) {
      final error = itemsAsync.hasError ? itemsAsync.error : categoriesAsync.error;
      return AppPage(
        title: 'Bulk price update',
        scroll: false,
        body: error != null
            ? ErrorState(
                message: friendlyError(error),
                onRetry: () => ref.refreshMenu(),
              )
            : const SkeletonList(rows: 4),
      );
    }
    _seed(items);

    final branch = _branchId == null
        ? null
        : branches.where((b) => b.id == _branchId).firstOrNull;
    final branchSettings = _branchId == null
        ? null
        : ref.watch(branchItemSettingsProvider(_branchId!));
    final branchReady = _branchId == null || branchSettings?.hasValue == true;

    final valueText = _value.text.trim();
    final value = parseChangeValue(valueText);
    final change = value == null
        ? null
        : PriceChange(
            mode: _mode,
            value: value,
            target: _target,
            roundWhole: _roundWhole,
            branchId: _branchId,
          );
    final problem = valueText.isNotEmpty && value == null
        ? 'Enter a number, for example 10.'
        : change?.problem;

    final selectedItems = [
      for (final item in items)
        if (_selected.contains(item.id)) item,
    ];
    final ready = change != null &&
        problem == null &&
        selectedItems.isNotEmpty &&
        branchReady;
    final rows = ready
        ? previewPriceChange(
            items: selectedItems,
            change: change,
            branchSettings: branchSettings?.valueOrNull ?? const {},
          )
        : const <PriceRow>[];
    final summary = summarizePriceChange(rows);
    final hint = selectedItems.isEmpty
        ? 'Choose at least one dish in step 1.'
        : (!branchReady
              ? 'Loading the branch prices...'
              : 'Enter a value in step 2 to see the review.');

    return AppPage(
      title: 'Bulk price update',
      subtitle: 'Change many prices at once, then undo if needed.',
      maxWidth: 820,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lastChange != null) _lastChangeCard(context, lastChange),
          BulkPriceSelectCard(
            items: items,
            categories: categories,
            selected: _selected,
            onChanged: (next) => setState(() => _selected = next),
          ),
          const SizedBox(height: Sp.lg),
          BulkPriceChangeCard(
            mode: _mode,
            onMode: (mode) => setState(() => _mode = mode),
            valueController: _value,
            onValueChanged: () => setState(() {}),
            target: _target,
            onTarget: (target) => setState(() => _target = target),
            roundWhole: _roundWhole,
            onRoundWhole: (on) => setState(() => _roundWhole = on),
            currency: currency,
            branches: branches,
            branchId: _branchId,
            onBranch: (id) => setState(() => _branchId = id),
            problem: problem,
            notice: change?.notice,
          ),
          const SizedBox(height: Sp.lg),
          BulkPriceReviewCard(
            rows: rows,
            summary: summary,
            currency: currency,
            ready: ready,
            applying: _applying,
            hint: hint,
            onApply: () => _apply(rows, change!, branch),
          ),
        ],
      ),
    );
  }
}
