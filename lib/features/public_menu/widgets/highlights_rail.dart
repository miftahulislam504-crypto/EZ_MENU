import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/images.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'menu_scope.dart';

/// Horizontal rows of dishes at the top of the menu: featured, popular, new,
/// and so on. Tapping a card opens the dish.
class HighlightsRails extends StatelessWidget {
  const HighlightsRails({super.key, required this.rails, required this.onOpen});

  final List<HighlightRail> rails;
  final ValueChanged<PublicItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rail in rails)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(rail.title(bangla: menu.bangla), style: menu.text(17, weight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rail.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _RailCard(item: rail.items[index], onTap: () => onOpen(rail.items[index])),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.item, required this.onTap});

  final PublicItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final name = itemDisplayName(item, bangla: bangla);
    final unavailable = availabilityLabel(item, bangla: bangla);
    final price = priceDisplay(item);
    return Semantics(
      button: true,
      label: '$name, ${formatPriceDisplay(price, currency: menu.currency, bangla: bangla)}'
          '${unavailable == null ? '' : ', $unavailable'}',
      child: SizedBox(
        width: 148,
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
              padding: const EdgeInsets.all(8),
              child: Opacity(
                opacity: unavailable == null ? 1 : 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NetworkImageBox(url: item.firstImage, width: 130, height: 100, radius: 11, cacheWidth: 130),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: menu.text(13.5, weight: FontWeight.w700, height: 1.25),
                    ),
                    const Spacer(),
                    Text(
                      unavailable ?? formatPriceDisplay(price, currency: menu.currency, bangla: bangla),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: withTabularFigures(
                        menu.text(
                          13.5,
                          weight: FontWeight.w700,
                          color: unavailable == null ? menu.palette.ink : menu.palette.closed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
