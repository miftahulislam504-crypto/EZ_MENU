import 'package:flutter/material.dart';

import '../../../core/logic/menu_search.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import 'menu_ui.dart';

/// Step 1: which dishes change.
class BulkPriceSelectCard extends StatelessWidget {
  const BulkPriceSelectCard({
    super.key,
    required this.items,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<MenuItem> items;
  final List<MenuCategory> categories;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Set<String> _idsOf(MenuCategory category) {
    final family = categoryWithDescendants(category.id, categories);
    return {
      for (final item in items)
        if (family.contains(item.categoryId)) item.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topLevel = [for (final c in categories) if (c.parentId == null) c];
    final everyone = {for (final item in items) item.id};
    final allSelected = everyone.isNotEmpty && selected.length == everyone.length;

    return FormSection(
      title: '1. Choose the dishes',
      subtitle: 'Start with all dishes, a category, or pick them one by one.',
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  selected.isEmpty
                      ? 'No dishes chosen yet'
                      : '${selected.length} of ${items.length} dishes chosen',
                  key: ValueKey(selected.length),
                  style: context.textStyles.titleSmall,
                ),
              ),
            ),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(<String>{}),
                child: const Text('Clear'),
              ),
          ],
        ),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [
            FilterChip(
              label: const Text('All dishes'),
              selected: allSelected,
              onSelected: (on) => onChanged(on ? everyone : <String>{}),
            ),
            for (final category in topLevel)
              Builder(
                builder: (context) {
                  final ids = _idsOf(category);
                  if (ids.isEmpty) return const SizedBox.shrink();
                  final all = ids.every(selected.contains);
                  return FilterChip(
                    label: Text('${category.displayName} (${ids.length})'),
                    selected: all,
                    onSelected: (on) =>
                        onChanged(on ? {...selected, ...ids} : selected.difference(ids)),
                  );
                },
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Pick dishes',
            icon: Icons.checklist_rounded,
            kind: AppButtonKind.tonal,
            onPressed: () async {
              final result = await showModalBottomSheet<Set<String>>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                constraints: const BoxConstraints(maxWidth: 640),
                builder: (_) => _PickerSheet(
                  items: items,
                  categories: categories,
                  initial: selected,
                ),
              );
              if (result != null) onChanged(result);
            },
          ),
        ),
        if (items.isEmpty)
          Text(
            'There are no dishes yet.',
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
      ],
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.items,
    required this.categories,
    required this.initial,
  });

  final List<MenuItem> items;
  final List<MenuCategory> categories;
  final Set<String> initial;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late Set<String> _chosen = {...widget.initial};
  String _query = '';

  String _categoryName(String id) {
    for (final c in widget.categories) {
      if (c.id == id) return c.displayName;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final item in widget.items)
        if (itemMatchesQuery(item, _query)) item,
    ];
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.sm),
              child: Text('Pick dishes', style: context.textStyles.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search dishes',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 2),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _chosen = {..._chosen, for (final i in shown) i.id},
                    ),
                    child: Text('Select shown (${shown.length})'),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _chosen = _chosen.difference({for (final i in shown) i.id}),
                    ),
                    child: const Text('Unselect shown'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No dishes match',
                      message: 'Try another name.',
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final item = shown[index];
                        final on = _chosen.contains(item.id);
                        return CheckboxListTile(
                          value: on,
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                          secondary: MenuThumb(url: item.coverImage, size: 40),
                          title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            _categoryName(item.categoryId),
                            style: TextStyle(color: palette.muted),
                          ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _chosen = {..._chosen, item.id};
                            } else {
                              _chosen = _chosen.difference({item.id});
                            }
                          }),
                        );
                      },
                    ),
            ),
            StickyActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      kind: AppButtonKind.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Use ${_chosen.length} dish${_chosen.length == 1 ? '' : 'es'}',
                      onPressed: () => Navigator.of(context).pop(_chosen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
