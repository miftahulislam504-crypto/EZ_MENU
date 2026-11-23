import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../availability_logic.dart';
import '../menu_models.dart';

/// Top of the availability screen: which branch and scope the switches apply
/// to, the three counts, the search box and the category chips.
class AvailabilityHeader extends StatelessWidget {
  const AvailabilityHeader({
    super.key,
    required this.counts,
    required this.search,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    this.branchName,
    this.scope = StockScope.thisBranch,
    this.onScope,
  });

  final StockCounts counts;
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  /// Top level categories shown as chips.
  final List<MenuCategory> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategory;

  /// Set only when the business has more than one branch.
  final String? branchName;
  final StockScope scope;
  final ValueChanged<StockScope>? onScope;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (branchName != null && onScope != null) ...[
          SegmentedChoice<StockScope>(
            label: 'Sold out switches apply to',
            value: scope,
            onChanged: onScope!,
            options: [
              ChoiceOption(
                value: StockScope.thisBranch,
                label: branchName!,
                icon: Icons.storefront_outlined,
              ),
              const ChoiceOption(
                value: StockScope.allBranches,
                label: 'All branches',
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
        ],
        Row(
          children: [
            Expanded(
              child: _CountTile(
                label: 'Available',
                value: counts.available,
                color: palette.success,
                soft: palette.successSoft,
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: _CountTile(
                label: 'Sold out',
                value: counts.soldOut,
                color: palette.danger,
                soft: palette.dangerSoft,
              ),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: _CountTile(
                label: 'Back later',
                value: counts.scheduled,
                color: palette.warning,
                soft: palette.warningSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.lg),
        AppTextField(
          label: 'Find a dish',
          controller: search,
          hint: 'Name in English or Bangla, or code',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          suffix: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClearSearch,
                ),
        ),
        if (categories.length > 1) ...[
          const SizedBox(height: Sp.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: categoryId == null,
                  onSelected: (_) => onCategory(null),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: Sp.sm),
                  ChoiceChip(
                    label: Text(category.displayName),
                    selected: categoryId == category.id,
                    onSelected: (_) => onCategory(
                      categoryId == category.id ? null : category.id,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
    required this.soft,
  });

  final String label;
  final int value;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: withTabularFigures(
                context.textStyles.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ) ??
                    TextStyle(color: color),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
