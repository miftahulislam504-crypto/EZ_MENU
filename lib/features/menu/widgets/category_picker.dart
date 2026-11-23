import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../category_logic.dart';
import '../menu_models.dart';

/// The result of the picker. `id == null` means "all categories" (clear).
class CategoryPick {
  const CategoryPick(this.id);
  final String? id;
}

/// A bottom sheet with the category tree. Returns null when dismissed.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  required List<MenuCategory> categories,
  String? selectedId,
  String title = 'Choose a category',
  bool allowAll = false,
  Map<String, int> counts = const {},
}) {
  final tree = buildCategoryTree(categories);
  return showAppSheet<CategoryPick>(
    context,
    title: title,
    builder: (sheetContext) {
      Widget row(MenuCategory c, {required bool sub}) {
        final selected = c.id == selectedId;
        return ListTile(
          contentPadding: EdgeInsets.only(left: sub ? Sp.xxl + Sp.lg : Sp.xl, right: Sp.xl),
          leading: Icon(
            categoryIconFor(c.icon) ?? (sub ? Icons.subdirectory_arrow_right_rounded : Icons.category_outlined),
            color: c.isActive ? null : sheetContext.palette.muted,
          ),
          title: Text(c.displayName),
          subtitle: c.isActive ? null : const Text('Hidden'),
          trailing: selected
              ? Icon(Icons.check_rounded, color: sheetContext.colors.primary)
              : (counts[c.id] == null ? null : Text('${counts[c.id]}')),
          onTap: () => Navigator.of(sheetContext).pop(CategoryPick(c.id)),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowAll)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              leading: const Icon(Icons.apps_rounded),
              title: const Text('All categories'),
              trailing: selectedId == null ? Icon(Icons.check_rounded, color: sheetContext.colors.primary) : null,
              onTap: () => Navigator.of(sheetContext).pop(const CategoryPick(null)),
            ),
          for (final node in tree) ...[
            row(node.category, sub: false),
            for (final child in node.children) row(child, sub: true),
          ],
          const SizedBox(height: Sp.lg),
        ],
      );
    },
  );
}
