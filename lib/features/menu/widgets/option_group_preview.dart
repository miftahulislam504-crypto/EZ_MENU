import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../option_groups_logic.dart';

/// "How customers will see it": the group as a menu would show it, so the
/// effect of the price mode and the selection rule is visible at once.
class OptionGroupPreview extends StatelessWidget {
  const OptionGroupPreview({
    super.key,
    required this.group,
    required this.basePrice,
    required this.currency,
  });

  final OptionGroup group;
  final double basePrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final shown = group.options
        .where((o) => (o.nameEn ?? '').trim().isNotEmpty || (o.nameBn ?? '').trim().isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(Rad.control),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How customers will see it',
            style: context.textStyles.labelSmall?.copyWith(
              color: palette.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  group.displayName,
                  style: context.textStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.isRequired)
                const StatusPill('Required', tone: PillTone.warning),
            ],
          ),
          Text(
            selectionHint(group),
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Sp.sm),
          if (shown.isEmpty)
            Text(
              'Options appear here as you name them.',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            )
          else
            for (final option in shown)
              _PreviewRow(
                group: group,
                option: option,
                basePrice: basePrice,
                currency: currency,
                accent: scheme.primary,
              ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.group,
    required this.option,
    required this.basePrice,
    required this.currency,
    required this.accent,
  });

  final OptionGroup group;
  final ItemOption option;
  final double basePrice;
  final String currency;
  final Color accent;

  String _priceText() {
    if (group.isAbsolute) {
      final result = optionResultPrice(group, option, basePrice);
      return formatMoney(result, currency: currency);
    }
    final price = option.discountPrice ?? option.price;
    if (price <= 0) return '';
    return '+ ${formatMoney(price, currency: currency)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final available = option.isAvailable;
    final IconData icon;
    if (group.isSingle) {
      icon = option.isDefault
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded;
    } else {
      icon = option.isDefault
          ? Icons.check_box_rounded
          : Icons.check_box_outline_blank_rounded;
    }
    final muted = context.textStyles.bodyMedium?.copyWith(color: palette.muted);
    final hasDiscount = option.discountPrice != null && option.discountPrice! < option.price;
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: option.isDefault && available ? accent : palette.muted,
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                option.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodyMedium?.copyWith(
                  decoration: available ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (!available)
              Text('Unavailable', style: context.textStyles.bodySmall?.copyWith(color: palette.muted))
            else ...[
              if (hasDiscount && !group.isAbsolute)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    formatMoney(option.price, currency: currency),
                    style: muted?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(_priceText(), style: context.textStyles.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
