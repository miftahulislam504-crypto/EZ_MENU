import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/images.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'menu_scope.dart';

/// A small outlined tag ("Halal", "Spicy").
class MenuTag extends StatelessWidget {
  const MenuTag(this.label, {super.key, this.filled = false, this.color});

  final String label;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final tone = color ?? menu.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: menu.palette.line),
      ),
      child: Text(
        label,
        style: menu.text(11, weight: FontWeight.w600, color: filled ? tone : menu.palette.muted, height: 1.2),
      ),
    );
  }
}

/// Price with the old price struck through and a percent badge.
class MenuPriceLine extends StatelessWidget {
  const MenuPriceLine({super.key, required this.item, this.size = 15});

  final PublicItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final price = priceDisplay(item);
    final percent = discountPercent(item);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          formatPriceDisplay(price, currency: menu.currency, bangla: menu.bangla),
          style: withTabularFigures(menu.text(size, weight: FontWeight.w700)),
        ),
        if (price.hasDiscount)
          Text(
            formatMoney(price.original!, currency: menu.currency, bangla: menu.bangla),
            style: withTabularFigures(
              menu.text(size - 3, color: menu.palette.muted).copyWith(decoration: TextDecoration.lineThrough),
            ),
          ),
        if (percent != null && !price.from)
          MenuTag(
            menu.bangla ? '${toBanglaDigits('$percent')}% ছাড়' : '$percent% off',
            filled: true,
            color: menu.palette.open,
          ),
      ],
    );
  }
}

/// A dish in the list or grid. Tapping opens its details.
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item, required this.onTap, this.grid = false});

  final PublicItem item;
  final VoidCallback onTap;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final name = itemDisplayName(item, bangla: menu.bangla);
    final summary = itemSummary(item, bangla: menu.bangla);
    final unavailable = availabilityLabel(item, bangla: menu.bangla);
    final labels = labelNames(item, bangla: menu.bangla, limit: 2);
    final price = priceDisplay(item);

    final card = grid ? _grid(context, name, summary, unavailable, labels) : _list(context, name, summary, unavailable, labels);
    return Semantics(
      button: true,
      label: '$name, ${formatPriceDisplay(price, currency: menu.currency, bangla: menu.bangla)}'
          '${unavailable == null ? '' : ', $unavailable'}',
      child: Material(
        color: menu.palette.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: menu.palette.line),
            ),
            child: Opacity(opacity: unavailable == null ? 1 : 0.62, child: card),
          ),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, {required double width, required double height, String? badge}) {
    final menu = context.menu;
    return Stack(
      children: [
        NetworkImageBox(
          url: item.firstImage,
          width: width,
          height: height,
          radius: 12,
          cacheWidth: width.isFinite ? width.round() : 220,
        ),
        if (badge != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: menu.palette.paper.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge, style: menu.text(11, weight: FontWeight.w700, color: menu.palette.closed, height: 1.2)),
            ),
          ),
      ],
    );
  }

  Widget _texts(BuildContext context, String name, String? summary, String? unavailable, List<String> labels,
      {required int summaryLines}) {
    final menu = context.menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: menu.text(15, weight: FontWeight.w700)),
        if (summary != null) ...[
          const SizedBox(height: 3),
          Text(
            summary,
            maxLines: summaryLines,
            overflow: TextOverflow.ellipsis,
            style: menu.text(12.5, color: menu.palette.muted),
          ),
        ],
        const SizedBox(height: 8),
        MenuPriceLine(item: item),
        if (labels.isNotEmpty || (unavailable != null && item.firstImage == null)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (unavailable != null && item.firstImage == null)
                MenuTag(unavailable, filled: true, color: menu.palette.closed),
              for (final label in labels) MenuTag(label),
            ],
          ),
        ],
      ],
    );
  }

  Widget _list(BuildContext context, String name, String? summary, String? unavailable, List<String> labels) {
    final hasImage = item.firstImage != null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _texts(context, name, summary, unavailable, labels, summaryLines: 2)),
          if (hasImage) ...[
            const SizedBox(width: 12),
            _image(context, width: 96, height: 96, badge: unavailable),
          ],
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, String name, String? summary, String? unavailable, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _image(context, width: constraints.maxWidth, height: constraints.maxHeight, badge: unavailable),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: _texts(context, name, summary, null, labels, summaryLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}
