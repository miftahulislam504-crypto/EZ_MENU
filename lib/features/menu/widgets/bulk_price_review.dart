import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/logic/price_adjust.dart';
import '../../../core/widgets/widgets.dart';
import 'editor_common.dart';

/// Step 3: the preview table, the totals and the Apply button.
class BulkPriceReviewCard extends StatelessWidget {
  const BulkPriceReviewCard({
    super.key,
    required this.rows,
    required this.summary,
    required this.currency,
    required this.ready,
    required this.applying,
    required this.onApply,
    this.hint,
  });

  /// Empty until the change is complete.
  final List<PriceRow> rows;
  final PriceSummary summary;
  final String currency;
  final bool ready;
  final bool applying;
  final VoidCallback onApply;

  /// Shown instead of the table while the change is incomplete.
  final String? hint;

  static const int _shownRows = 60;

  String _delta(double value) {
    if (value == 0) return 'No change';
    final sign = value > 0 ? '+' : '-';
    return '$sign${formatMoney(value.abs(), currency: currency)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final changedRows = [for (final r in rows) if (r.changed) r];
    final shown = changedRows.take(_shownRows).toList();
    final more = changedRows.length - shown.length;

    return FormSection(
      title: '3. Review and apply',
      subtitle: 'Check the new prices before anything is saved.',
      children: [
        if (!ready)
          Text(
            hint ?? 'Choose dishes and enter a value to see the review.',
            style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
          )
        else ...[
          Wrap(
            spacing: Sp.sm,
            runSpacing: 6,
            children: [
              StatusPill(
                '${summary.changed} will change',
                tone: summary.changed == 0 ? PillTone.neutral : PillTone.success,
              ),
              if (summary.unchanged > 0)
                StatusPill('${summary.unchanged} stay the same'),
              if (summary.discountsDropped > 0)
                StatusPill(
                  '${summary.discountsDropped} discount${summary.discountsDropped == 1 ? '' : 's'} removed',
                  tone: PillTone.warning,
                ),
              if (summary.becameFree > 0)
                StatusPill('${summary.becameFree} become free', tone: PillTone.danger),
              if (summary.createsBranchPrice > 0)
                StatusPill(
                  '${summary.createsBranchPrice} get a branch price',
                  tone: PillTone.info,
                ),
            ],
          ),
          if (summary.changed > 0)
            Text(
              'Total effect on regular prices: ${_delta(summary.totalDelta)}',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            ),
          if (summary.changed == 0)
            const EditorNote(
              'This change would not alter any price. Try another value.',
              tone: PillTone.warning,
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Rad.control),
                border: Border.all(color: palette.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: palette.line),
                    _PreviewRow(row: shown[i], currency: currency, delta: _delta(shown[i].delta)),
                  ],
                ],
              ),
            ),
          if (more > 0)
            Text(
              'and $more more dishes with the same kind of change.',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            ),
        ],
        AppButton(
          label: ready && summary.changed > 0
              ? 'Apply to ${summary.changed} dish${summary.changed == 1 ? '' : 'es'}'
              : 'Apply',
          icon: Icons.check_rounded,
          expand: true,
          loading: applying,
          onPressed: ready && summary.changed > 0 && !applying ? onApply : null,
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row, required this.currency, required this.delta});

  final PriceRow row;
  final String currency;
  final String delta;

  String _warning(PriceWarning warning) {
    switch (warning) {
      case PriceWarning.becomesFree:
        return 'The price becomes 0';
      case PriceWarning.discountDropped:
        return 'Discount removed, it is no longer lower than the price';
      case PriceWarning.createsBranchPrice:
        return 'Gets its own price at this branch';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final discountText = (row.oldDiscount != null || row.newDiscount != null)
        ? 'Discount ${row.oldDiscount == null ? 'none' : formatMoney(row.oldDiscount!, currency: currency)}'
            ' to ${row.newDiscount == null ? 'none' : formatMoney(row.newDiscount!, currency: currency)}'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall),
                if (discountText != null && row.discountChanged)
                  Text(discountText, style: context.textStyles.bodySmall?.copyWith(color: palette.muted)),
                for (final warning in row.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _warning(warning),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: warning == PriceWarning.becomesFree ? palette.danger : palette.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.priceChanged) ...[
                    Text(
                      formatMoney(row.oldPrice, currency: currency),
                      style: context.textStyles.bodySmall?.copyWith(
                        color: palette.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(formatMoney(row.newPrice, currency: currency), style: context.textStyles.titleSmall),
                ],
              ),
              if (row.priceChanged)
                Text(delta, style: context.textStyles.bodySmall?.copyWith(color: palette.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
