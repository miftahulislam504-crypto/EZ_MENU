import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import 'menu_ui.dart';

enum CategoryAction { edit, addSub, viewDishes, branches, duplicate, delete }

/// One row of the category list: picture or icon, names, dish count, status,
/// the Show / Hide switch and the actions menu.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.dishCount,
    required this.onTap,
    required this.onActiveChanged,
    required this.onAction,
    this.reorderIndex,
    this.selected = false,
    this.selecting = false,
    this.onLongPress,
    this.offBranches = 0,
    this.showBranchAction = false,
    this.leadingExtra,
    this.compact = false,
  });

  final MenuCategory category;
  final int dishCount;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<CategoryAction> onAction;

  /// Index inside its sibling list; null hides the drag handle.
  final int? reorderIndex;
  final bool selected;
  final bool selecting;
  final VoidCallback? onLongPress;

  /// Number of branches where the category is switched off.
  final int offBranches;
  final bool showBranchAction;

  /// Shown before the picture (the expand arrow of a parent).
  final Widget? leadingExtra;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final bangla = category.nameBn;
    final english = category.nameEn;
    final hasBoth = (english ?? '').trim().isNotEmpty && (bangla ?? '').trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(
          color: selected ? scheme.primary : palette.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.panel),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Sp.md,
            vertical: compact ? Sp.sm : Sp.md,
          ),
          child: Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.sm),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? scheme.primary : palette.muted,
                  ),
                ),
              if (leadingExtra != null) leadingExtra!,
              MenuThumb(
                url: category.imageUrl,
                icon: categoryIconFor(category.icon) ?? Icons.category_outlined,
                size: compact ? 44 : 52,
                dimmed: !category.isActive,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall?.copyWith(
                        color: category.isActive ? null : palette.muted,
                      ),
                    ),
                    if (hasBoth)
                      Text(
                        bangla!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          dishCount == 1 ? '1 dish' : '$dishCount dishes',
                          icon: Icons.restaurant_menu_rounded,
                        ),
                        if (!category.isActive)
                          const StatusPill('Hidden', tone: PillTone.warning),
                        if (offBranches > 0)
                          StatusPill(
                            offBranches == 1
                                ? 'Off at 1 branch'
                                : 'Off at $offBranches branches',
                            tone: PillTone.warning,
                            icon: Icons.storefront_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selecting) ...[
                Tooltip(
                  message: category.isActive ? 'Visible to customers' : 'Hidden from customers',
                  child: Switch(
                    value: category.isActive,
                    onChanged: onActiveChanged,
                  ),
                ),
                PopupMenuButton<CategoryAction>(
                  tooltip: 'More actions',
                  icon: Icon(Icons.more_vert_rounded, color: palette.muted),
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: CategoryAction.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!category.isSub)
                      const PopupMenuItem(
                        value: CategoryAction.addSub,
                        child: ListTile(
                          leading: Icon(Icons.subdirectory_arrow_right_rounded),
                          title: Text('Add subcategory'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: CategoryAction.viewDishes,
                      child: ListTile(
                        leading: Icon(Icons.restaurant_menu_rounded),
                        title: Text('View dishes'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (showBranchAction)
                      const PopupMenuItem(
                        value: CategoryAction.branches,
                        child: ListTile(
                          leading: Icon(Icons.storefront_outlined),
                          title: Text('Branch availability'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: CategoryAction.duplicate,
                      child: ListTile(
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Duplicate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: CategoryAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded, color: palette.danger),
                        title: Text('Move to trash', style: TextStyle(color: palette.danger)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: Tooltip(
                      message: 'Drag to change order',
                      child: Padding(
                        padding: const EdgeInsets.all(Sp.xs),
                        child: Icon(Icons.drag_indicator_rounded, color: palette.muted),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
