import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/logic/pricing.dart';
import '../../../core/logic/localized.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/images.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'menu_item_card.dart';
import 'menu_scope.dart';
import 'menu_sheet.dart';

/// Everything about one dish: pictures, description, ingredients, allergens,
/// nutrition and, for dishes with sizes or add-ons, the choices with the price
/// updating as the customer picks. There is no cart in this phase, so the bar
/// at the bottom only shows the price for the chosen options.
class ItemDetailSheet extends StatefulWidget {
  const ItemDetailSheet({super.key, required this.item, required this.onClose});

  final PublicItem item;
  final VoidCallback onClose;

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  late Map<String, Set<String>> _selections = initialSelections(widget.item);

  void _toggle(PublicOptionGroup group, String optionId) {
    setState(() => _selections = toggleOption(_selections, group, optionId));
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final item = widget.item;
    final bangla = menu.bangla;
    final groups = [for (final g in item.optionGroups) if (g.options.isNotEmpty) g];
    final hasChoices = groups.isNotEmpty;
    final breakdown = priceFor(item, _selections);
    final unavailable = availabilityLabel(item, bangla: bangla);

    return MenuSheetFrame(
      title: bangla ? 'খাবারের বিবরণ' : 'Dish details',
      onClose: widget.onClose,
      footer: _PriceBar(item: item, breakdown: breakdown, groups: groups, hasChoices: hasChoices, unavailable: unavailable),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrls.isNotEmpty) _Gallery(urls: item.imageUrls),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _Summary(item: item, unavailable: unavailable),
            ),
            if (hasChoices)
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: _OptionGroupView(
                    group: group,
                    selected: _selections[group.id] ?? const <String>{},
                    onToggle: (id) => _toggle(group, id),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: _Details(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls});

  final List<String> urls;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final urls = widget.urls;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: urls.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => NetworkImageBox(url: urls[index], radius: 0, cacheWidth: 640),
                ),
              ),
              if (urls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < urls.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page ? menu.palette.paper : menu.palette.paper.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.item, required this.unavailable});

  final PublicItem item;
  final String? unavailable;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final facts = itemFacts(item, bangla: bangla);
    final labels = labelNames(item, bangla: bangla);
    final description = pickText(item.descriptionEn, item.descriptionBn, bangla: bangla) ??
        pickText(item.shortEn, item.shortBn, bangla: bangla);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(itemDisplayName(item, bangla: bangla), style: menu.text(22, weight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 8),
        MenuPriceLine(item: item, size: 17),
        if (unavailable != null || labels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (unavailable != null) MenuTag(unavailable!, filled: true, color: menu.palette.closed),
              for (final label in labels) MenuTag(label),
            ],
          ),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(facts.join('  ·  '), style: menu.text(13, color: menu.palette.muted)),
        ],
        if (description != null) ...[
          const SizedBox(height: 14),
          Text(description, style: menu.text(14.5, height: 1.55)),
        ],
      ],
    );
  }
}

/// One group of choices ("Size", "Extras").
class _OptionGroupView extends StatelessWidget {
  const _OptionGroupView({required this.group, required this.selected, required this.onToggle});

  final PublicOptionGroup group;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    return Container(
      decoration: BoxDecoration(
        color: menu.palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(groupDisplayName(group, bangla: bangla), style: menu.text(15.5, weight: FontWeight.w800)),
              ),
              if (group.isRequired)
                MenuTag(bangla ? 'আবশ্যক' : 'Required', filled: true, color: menu.accent),
            ],
          ),
          const SizedBox(height: 2),
          Text(groupRuleText(group, bangla: bangla), style: menu.text(12.5, color: menu.palette.muted)),
          const SizedBox(height: 6),
          for (final option in group.options)
            _OptionRow(
              option: option,
              group: group,
              selected: selected.contains(option.id),
              onTap: () => onToggle(option.id),
            ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.group, required this.selected, required this.onTap});

  final PublicOption option;
  final PublicOptionGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final enabled = option.isAvailable;
    final priceText = optionPriceText(option, group, currency: menu.currency, bangla: bangla);
    final hasOffer = option.discountPrice != null && option.discountPrice! < option.price;
    final multiple = group.multiple;
    final tone = selected ? menu.brand : menu.palette.line;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: optionDisplayName(option, bangla: bangla),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? menu.brand : Colors.transparent,
                    shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: multiple ? BorderRadius.circular(6) : null,
                    border: Border.all(color: tone, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Icon(
                          multiple ? Icons.check_rounded : Icons.circle,
                          size: multiple ? 16 : 8,
                          color: menu.onBrand,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(optionDisplayName(option, bangla: bangla), style: menu.text(14.5, weight: FontWeight.w600)),
                      if (!enabled)
                        Text(
                          bangla ? 'এখন নেই' : 'Not available',
                          style: menu.text(12, color: menu.palette.closed),
                        ),
                    ],
                  ),
                ),
                if (priceText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  if (hasOffer && group.mode != OptionPriceMode.absolute) ...[
                    Text(
                      formatMoney(option.price, currency: menu.currency, bangla: bangla),
                      style: withTabularFigures(
                        menu.text(12, color: menu.palette.muted).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(priceText, style: withTabularFigures(menu.text(13.5, weight: FontWeight.w700))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ingredients, allergens, nutrition and when the dish is served.
class _Details extends StatelessWidget {
  const _Details({required this.item});

  final PublicItem item;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final ingredients = pickText(item.ingredientsEn, item.ingredientsBn, bangla: bangla);
    final allergens = allergenNames(item, bangla: bangla);
    final note = item.allergenNote?.trim();
    final dietary = item.dietaryInfo?.trim();
    final nutrition = nutritionLines(item, bangla: bangla);
    final schedule = item.availability == ItemAvailability.scheduled ? scheduleLines(item, bangla: bangla) : const <String>[];

    final blocks = <Widget>[
      if (schedule.isNotEmpty)
        _DetailBlock(
          title: bangla ? 'কখন পাওয়া যায়' : 'When it is served',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final line in schedule) Text(line, style: menu.text(13.5, height: 1.5))],
          ),
        ),
      if (ingredients != null)
        _DetailBlock(
          title: bangla ? 'উপকরণ' : 'Ingredients',
          child: Text(ingredients, style: menu.text(13.5, height: 1.5)),
        ),
      if (allergens.isNotEmpty || (note != null && note.isNotEmpty))
        _DetailBlock(
          title: bangla ? 'অ্যালার্জেন' : 'Allergens',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allergens.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final name in allergens) MenuTag(name, filled: true, color: menu.palette.caution)],
                ),
              if (note != null && note.isNotEmpty) ...[
                if (allergens.isNotEmpty) const SizedBox(height: 8),
                Text(note, style: menu.text(13, color: menu.palette.muted, height: 1.45)),
              ],
            ],
          ),
        ),
      if (dietary != null && dietary.isNotEmpty)
        _DetailBlock(
          title: bangla ? 'খাদ্যাভ্যাস' : 'Dietary information',
          child: Text(dietary, style: menu.text(13.5, height: 1.5)),
        ),
      if (nutrition.isNotEmpty)
        _DetailBlock(
          title: bangla ? 'পুষ্টি তথ্য' : 'Nutrition',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final line in nutrition)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: menu.palette.surface, borderRadius: BorderRadius.circular(10)),
                  child: Text(line, style: withTabularFigures(menu.text(12.5, weight: FontWeight.w600))),
                ),
            ],
          ),
        ),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          blocks[i],
        ],
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: menu.text(13, weight: FontWeight.w800, color: menu.palette.muted)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// The price for the chosen options, with what is still missing when the
/// choices are not complete.
class _PriceBar extends StatelessWidget {
  const _PriceBar({
    required this.item,
    required this.breakdown,
    required this.groups,
    required this.hasChoices,
    required this.unavailable,
  });

  final PublicItem item;
  final PriceBreakdown breakdown;
  final List<PublicOptionGroup> groups;
  final bool hasChoices;
  final String? unavailable;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    String? problem;
    if (hasChoices && breakdown.issues.isNotEmpty) {
      final issue = breakdown.issues.first;
      for (final group in groups) {
        if (group.id == issue.groupId) problem = selectionProblemText(issue, group, bangla: bangla);
      }
    }
    final total = formatMoney(breakdown.unitPrice, currency: menu.currency, bangla: bangla);
    final original = formatMoney(breakdown.unitOriginalPrice, currency: menu.currency, bangla: bangla);
    return Container(
      decoration: BoxDecoration(
        color: menu.palette.paper,
        border: Border(top: BorderSide(color: menu.palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasChoices ? (bangla ? 'আপনার পছন্দে দাম' : 'Price for your choice') : (bangla ? 'দাম' : 'Price'),
                    style: menu.text(12, color: menu.palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          total,
                          key: ValueKey(total),
                          style: withTabularFigures(menu.text(21, weight: FontWeight.w800, height: 1.15)),
                        ),
                      ),
                      if (breakdown.hasDiscount) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            original,
                            style: withTabularFigures(
                              menu.text(13, color: menu.palette.muted).copyWith(decoration: TextDecoration.lineThrough),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (problem != null || unavailable != null)
              Flexible(
                child: Text(
                  problem ?? unavailable!,
                  textAlign: TextAlign.end,
                  style: menu.text(
                    12.5,
                    weight: FontWeight.w700,
                    color: problem != null ? menu.palette.caution : menu.palette.closed,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
