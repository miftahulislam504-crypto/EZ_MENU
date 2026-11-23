import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/menu_search.dart';
import '../../../core/logic/money.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../category_logic.dart';
import '../menu_models.dart';
import '../menu_repository.dart';

/// "Add several dishes": one dish per line, `Name, price`, with a live preview.
Future<void> showQuickAddSheet(
  BuildContext context, {
  required List<MenuCategory> categories,
  required List<MenuItem> items,
  String? initialCategoryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (sheetContext) => _QuickAddBody(
      categories: categories,
      items: items,
      initialCategoryId: initialCategoryId,
    ),
  );
}

class _QuickAddBody extends ConsumerStatefulWidget {
  const _QuickAddBody({
    required this.categories,
    required this.items,
    this.initialCategoryId,
  });

  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final String? initialCategoryId;

  @override
  ConsumerState<_QuickAddBody> createState() => _QuickAddBodyState();
}

class _QuickAddBodyState extends ConsumerState<_QuickAddBody> {
  final TextEditingController _text = TextEditingController();
  String? _categoryId;
  bool _saving = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    final ids = {for (final c in widget.categories) c.id};
    _categoryId = ids.contains(widget.initialCategoryId)
        ? widget.initialCategoryId
        : (widget.categories.isEmpty ? null : buildCategoryTree(widget.categories).first.category.id);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _create(List<QuickAddRow> rows) async {
    final businessId = ref.read(currentBusinessIdProvider);
    final categoryId = _categoryId;
    if (businessId == null || categoryId == null || _saving) return;
    final valid = rows.where((r) => r.isValid).toList();
    if (valid.isEmpty) return;
    setState(() {
      _saving = true;
      _done = 0;
    });
    final repo = ref.read(menuRepositoryProvider);
    var order = nextItemSortOrder(widget.items.where((i) => i.categoryId == categoryId));
    var created = 0;
    try {
      for (final row in valid) {
        await repo.createItem(
          businessId,
          quickAddValues(row, categoryId: categoryId, sortOrder: order++),
        );
        created++;
        if (mounted) setState(() => _done = created);
      }
      ref.refreshMenu();
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, created == 1 ? '1 dish added' : '$created dishes added');
    } catch (error) {
      ref.refreshMenu();
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(
        context,
        created == 0
            ? friendlyError(error)
            : 'Added $created of ${valid.length} dishes. ${friendlyError(error)}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currency = ref.watch(currentBusinessProvider).valueOrNull?.currency ?? 'BDT';
    final rows = parseQuickAdd(_text.text);
    final valid = rows.where((r) => r.isValid).length;
    final errors = rows.length - valid;
    final tree = buildCategoryTree(widget.categories);
    final options = <SelectOption<String>>[
      for (final node in tree) ...[
        SelectOption(value: node.category.id, label: node.category.displayName),
        for (final child in node.children)
          SelectOption(value: child.id, label: '${node.category.displayName} / ${child.displayName}'),
      ],
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: widget.categories.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(Sp.xl),
              child: EmptyState(
                icon: Icons.category_outlined,
                title: 'Add a category first',
                message: 'Dishes live inside a category. Create one, then come back to add dishes.',
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add several dishes', style: context.textStyles.titleLarge),
                  const SizedBox(height: Sp.xs),
                  Text(
                    'Type or paste one dish per line. Add the price after a comma or a bar.',
                    style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: Sp.lg),
                  SelectField<String>(
                    label: 'Category',
                    options: options,
                    value: _categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: Sp.lg),
                  AppTextField(
                    label: 'Dishes',
                    controller: _text,
                    maxLines: 8,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                    hint: 'Chicken Burger, 250\nBeef Burger | 320\nচা, ৩০',
                    helper: 'Bangla digits and "tk" are fine. Prices can be left out and set later.',
                    enabled: !_saving,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Sp.md),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: rows.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(Rad.control),
                            ),
                            child: Column(
                              children: [
                                for (final row in rows.take(40))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          row.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                                          size: 18,
                                          color: row.isValid ? palette.success : palette.danger,
                                        ),
                                        const SizedBox(width: Sp.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row.name ?? row.raw,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: context.textStyles.bodyMedium,
                                              ),
                                              if (row.error != null)
                                                Text(
                                                  'Line ${row.line}: ${row.error}',
                                                  style: context.textStyles.bodySmall?.copyWith(color: palette.danger),
                                                )
                                              else if (row.warning != null)
                                                Text(
                                                  row.warning!,
                                                  style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (row.isValid)
                                          Text(
                                            formatMoney(row.price ?? 0, currency: currency),
                                            style: context.textStyles.labelLarge,
                                          ),
                                      ],
                                    ),
                                  ),
                                if (rows.length > 40)
                                  Padding(
                                    padding: const EdgeInsets.all(Sp.sm),
                                    child: Text('and ${rows.length - 40} more lines', style: context.textStyles.bodySmall),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: Sp.lg),
                  AppButton(
                    label: _saving
                        ? 'Adding $_done of $valid'
                        : (valid == 0
                              ? 'Add dishes'
                              : (valid == 1 ? 'Add 1 dish' : 'Add $valid dishes')),
                    icon: Icons.add_rounded,
                    expand: true,
                    loading: _saving,
                    onPressed: valid == 0 || _categoryId == null ? null : () => _create(rows),
                  ),
                  if (errors > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: Sp.sm),
                      child: Text(
                        errors == 1
                            ? '1 line has a problem and will be skipped.'
                            : '$errors lines have a problem and will be skipped.',
                        style: context.textStyles.bodySmall?.copyWith(color: palette.danger),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
