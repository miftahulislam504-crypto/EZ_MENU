import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/logic/price_adjust.dart';
import '../../../core/session/models.dart';
import '../../../core/widgets/widgets.dart';
import 'editor_common.dart';

const Map<PriceChangeMode, String> _modeLabels = {
  PriceChangeMode.percentIncrease: 'Increase by %',
  PriceChangeMode.percentDecrease: 'Decrease by %',
  PriceChangeMode.fixedIncrease: 'Increase by amount',
  PriceChangeMode.fixedDecrease: 'Decrease by amount',
  PriceChangeMode.setExact: 'Set exact price',
};

/// Step 2: what changes and where.
class BulkPriceChangeCard extends StatelessWidget {
  const BulkPriceChangeCard({
    super.key,
    required this.mode,
    required this.onMode,
    required this.valueController,
    required this.onValueChanged,
    required this.target,
    required this.onTarget,
    required this.roundWhole,
    required this.onRoundWhole,
    required this.currency,
    required this.branches,
    required this.branchId,
    required this.onBranch,
    this.problem,
    this.notice,
  });

  final PriceChangeMode mode;
  final ValueChanged<PriceChangeMode> onMode;
  final TextEditingController valueController;
  final VoidCallback onValueChanged;
  final PriceTarget target;
  final ValueChanged<PriceTarget> onTarget;
  final bool roundWhole;
  final ValueChanged<bool> onRoundWhole;
  final String currency;

  /// All branches; the scope control shows only with more than one.
  final List<Branch> branches;

  /// Null changes the dish prices; otherwise the price override of the branch.
  final String? branchId;
  final ValueChanged<String?> onBranch;
  final String? problem;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final symbol = currencySymbol(currency);
    return FormSection(
      title: '2. Choose the change',
      subtitle: 'The review below updates as you type.',
      children: [
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [
            for (final entry in _modeLabels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: mode == entry.key,
                onSelected: (_) => onMode(entry.key),
              ),
          ],
        ),
        AppTextField(
          label: mode.isPercent
              ? 'Percent'
              : (mode == PriceChangeMode.setExact ? 'New price' : 'Amount'),
          controller: valueController,
          prefixText: mode.isPercent ? null : '$symbol ',
          suffix: mode.isPercent
              ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text('%', style: context.textStyles.titleSmall),
                )
              : null,
          hint: mode.isPercent ? '10' : '20',
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          validator: (_) => problem,
          onChanged: (_) => onValueChanged(),
        ),
        SegmentedChoice<PriceTarget>(
          label: 'Change which price',
          value: target,
          onChanged: onTarget,
          options: const [
            ChoiceOption(value: PriceTarget.price, label: 'Regular'),
            ChoiceOption(value: PriceTarget.discount, label: 'Discount'),
            ChoiceOption(value: PriceTarget.both, label: 'Both'),
          ],
        ),
        SwitchRow(
          title: 'Round to whole taka',
          subtitle: 'Without this, prices keep up to two decimals.',
          value: roundWhole,
          onChanged: onRoundWhole,
        ),
        if (branches.length > 1)
          SelectField<String>(
            label: 'Apply to',
            hint: 'Dish prices (all branches)',
            optional: true,
            value: branchId,
            options: [
              for (final branch in branches)
                SelectOption<String>(
                  value: branch.id,
                  label: '${branch.name} only',
                  subtitle: 'Changes the price override of this branch',
                ),
            ],
            onChanged: onBranch,
          ),
        if (branchId != null)
          const EditorNote(
            'A branch price replaces both the regular and the discount price at that branch. '
            'Other branches are not affected.',
          ),
        if (problem != null) EditorNote(problem!, tone: PillTone.danger),
        if (notice != null && problem == null)
          EditorNote(notice!, tone: PillTone.warning),
        Text(
          'A discount that is no longer lower than the price is removed.',
          style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
