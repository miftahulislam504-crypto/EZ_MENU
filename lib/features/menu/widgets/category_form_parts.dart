import 'package:flutter/material.dart';

import '../../../core/session/models.dart';
import '../../../core/widgets/widgets.dart';
import 'menu_ui.dart';

/// A grid of icons for a category. Tapping the selected icon again clears it.
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    return Wrap(
      spacing: Sp.sm,
      runSpacing: Sp.sm,
      children: [
        for (final entry in categoryIcons.entries)
          Tooltip(
            message: entry.key.replaceAll('_', ' '),
            child: Semantics(
              button: true,
              selected: entry.key == selected,
              label: entry.key.replaceAll('_', ' '),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(entry.key == selected ? null : entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? scheme.primaryContainer
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: entry.key == selected ? scheme.primary : palette.line,
                      width: entry.key == selected ? 1.6 : 1,
                    ),
                  ),
                  child: Icon(
                    entry.value,
                    color: entry.key == selected ? scheme.primary : palette.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// How the category will look on the customer menu: the chip in the category
/// bar and the card in the overview, drawn with the brand colour.
class CategoryPreview extends StatelessWidget {
  const CategoryPreview({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.icon,
    required this.business,
  });

  final String name;
  final String? imageUrl;
  final String? icon;
  final Business? business;

  @override
  Widget build(BuildContext context) {
    final brand = hexToColor(business?.brandColor);
    final onBrand = onColor(brand);
    final label = name.trim().isEmpty ? 'Category name' : name.trim();
    final iconData = categoryIconFor(icon);
    final palette = context.palette;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category bar', style: context.textStyles.labelMedium?.copyWith(color: palette.muted)),
              const SizedBox(height: Sp.sm),
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  _Chip(label: label, icon: iconData, background: brand, foreground: onBrand),
                  _Chip(
                    label: 'Drinks',
                    icon: Icons.local_drink_rounded,
                    background: context.colors.surface,
                    foreground: context.colors.onSurface,
                    outline: palette.line,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: Sp.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card', style: context.textStyles.labelMedium?.copyWith(color: palette.muted)),
            const SizedBox(height: Sp.sm),
            Container(
              width: 112,
              padding: const EdgeInsets.all(Sp.sm),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(Rad.panel),
                border: Border.all(color: palette.line),
              ),
              child: Column(
                children: [
                  MenuThumb(
                    url: hasImage ? imageUrl : null,
                    icon: iconData ?? Icons.restaurant_menu_rounded,
                    size: 96,
                    radius: 12,
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.textStyles.labelLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.outline,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: outline == null ? null : Border.all(color: outline!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelLarge?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// One switch per branch for a category.
class CategoryBranchSwitches extends StatelessWidget {
  const CategoryBranchSwitches({
    super.key,
    required this.branches,
    required this.values,
    required this.onChanged,
  });

  final List<Branch> branches;
  final Map<String, bool> values;
  final void Function(String branchId, bool active) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final branch in branches)
          SwitchRow(
            title: branch.name,
            subtitle: (values[branch.id] ?? true)
                ? 'Shown at this branch'
                : 'Hidden at this branch',
            value: values[branch.id] ?? true,
            onChanged: (v) => onChanged(branch.id, v),
          ),
      ],
    );
  }
}
