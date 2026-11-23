import 'package:flutter/material.dart';

import '../../../core/logic/menu_catalog.dart';
import '../../../core/logic/menu_search.dart';
import '../../../core/logic/money.dart';
import '../../../core/logic/sold_out.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import 'menu_ui.dart';

enum ItemAction { edit, duplicate, move, soldOut, delete }

/// One dish in the list: photo, names, price, badges, the Visible and Sold out
/// switches, and the actions menu.
class ItemListTile extends StatelessWidget {
  const ItemListTile({
    super.key,
    required this.item,
    required this.price,
    required this.currency,
    required this.now,
    required this.soldOut,
    required this.hiddenAtBranch,
    required this.onTap,
    required this.onVisibleChanged,
    required this.onSoldOutChanged,
    required this.onAction,
    this.soldOutUntil,
    this.categoryName,
    this.selected = false,
    this.selecting = false,
    this.onLongPress,
    this.reorderIndex,
  });

  final MenuItem item;
  final EffectivePrice price;
  final String currency;
  final DateTime now;
  final bool soldOut;
  final DateTime? soldOutUntil;
  final bool hiddenAtBranch;
  final String? categoryName;
  final bool selected;
  final bool selecting;
  final int? reorderIndex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool> onVisibleChanged;
  final ValueChanged<bool> onSoldOutChanged;
  final ValueChanged<ItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final hasBoth = (item.nameEn ?? '').trim().isNotEmpty && (item.nameBn ?? '').trim().isNotEmpty;
    final hidden = !item.isActive || hiddenAtBranch;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(color: selected ? scheme.primary : palette.line, width: selected ? 1.5 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.panel)),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.xs, Sp.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecting)
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.sm, top: Sp.md),
                      child: Icon(
                        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: selected ? scheme.primary : palette.muted,
                      ),
                    ),
                  MenuThumb(url: item.coverImage, size: 64, dimmed: hidden || soldOut),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.titleSmall?.copyWith(
                            color: hidden ? palette.muted : null,
                          ),
                        ),
                        if (hasBoth)
                          Text(
                            item.nameBn!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                          ),
                        const SizedBox(height: 4),
                        _PriceLine(price: price, currency: currency),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (categoryName != null)
                              StatusPill(categoryName!, icon: Icons.folder_outlined),
                            if (soldOut)
                              StatusPill(
                                soldOutUntil == null
                                    ? 'Sold out'
                                    : 'Sold out, ${backAtText(soldOutUntil!, now)}',
                                tone: PillTone.danger,
                              ),
                            if (!item.isActive)
                              const StatusPill('Hidden', tone: PillTone.warning)
                            else if (hiddenAtBranch)
                              const StatusPill('Hidden at this branch', tone: PillTone.warning),
                            if (item.isFeatured)
                              const StatusPill('Featured', tone: PillTone.info, icon: Icons.star_rounded),
                            if (item.imageUrls.isEmpty)
                              const StatusPill('Needs photo', icon: Icons.image_outlined),
                            for (final label in item.labels.take(3))
                              StatusPill(menuTagName(menuLabels, label)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!selecting)
                    PopupMenuButton<ItemAction>(
                      tooltip: 'More actions',
                      icon: Icon(Icons.more_vert_rounded, color: palette.muted),
                      onSelected: onAction,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: ItemAction.edit,
                          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero),
                        ),
                        const PopupMenuItem(
                          value: ItemAction.duplicate,
                          child: ListTile(leading: Icon(Icons.copy_rounded), title: Text('Duplicate'), contentPadding: EdgeInsets.zero),
                        ),
                        const PopupMenuItem(
                          value: ItemAction.move,
                          child: ListTile(leading: Icon(Icons.drive_file_move_outline), title: Text('Move to category'), contentPadding: EdgeInsets.zero),
                        ),
                        PopupMenuItem(
                          value: ItemAction.soldOut,
                          child: ListTile(
                            leading: Icon(soldOut ? Icons.check_circle_outline_rounded : Icons.block_rounded),
                            title: Text(soldOut ? 'Mark available' : 'Mark sold out'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: ItemAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded, color: palette.danger),
                            title: Text('Move to trash', style: TextStyle(color: palette.danger)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (!selecting) ...[
            Divider(height: 1, color: palette.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md),
              child: Row(
                children: [
                  Expanded(
                    child: _LabeledSwitch(
                      label: 'Visible',
                      value: item.isActive,
                      onChanged: onVisibleChanged,
                    ),
                  ),
                  Expanded(
                    child: _LabeledSwitch(
                      label: 'Sold out',
                      value: soldOut,
                      onChanged: onSoldOutChanged,
                      activeColor: palette.danger,
                    ),
                  ),
                  if (reorderIndex != null)
                    ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: Tooltip(
                        message: 'Drag to change order',
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.sm),
                          child: Icon(Icons.drag_indicator_rounded, color: palette.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledSwitch extends StatelessWidget {
  const _LabeledSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: Sp.xs),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: context.textStyles.labelLarge),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.price, required this.currency});

  final EffectivePrice price;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatMoney(price.payable, currency: currency),
          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (price.hasDiscount)
          Text(
            formatMoney(price.price, currency: currency),
            style: context.textStyles.bodySmall?.copyWith(
              color: palette.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (price.isBranchPrice)
          const StatusPill('Branch price', tone: PillTone.info),
      ],
    );
  }
}
