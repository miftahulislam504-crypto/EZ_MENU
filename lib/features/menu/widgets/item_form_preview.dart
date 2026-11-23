import 'package:flutter/material.dart';

import '../../../core/logic/localized.dart';
import '../../../core/logic/menu_catalog.dart';
import '../../../core/logic/money.dart';
import '../../../core/session/models.dart';
import '../../../core/theme/menu_palette.dart';
import '../../../core/widgets/widgets.dart';

/// The values the preview card needs, as they are being typed.
class ItemPreviewData {
  const ItemPreviewData({
    this.nameEn = '',
    this.nameBn = '',
    this.shortEn = '',
    this.shortBn = '',
    this.price,
    this.discountPrice,
    this.imageUrl,
    this.labels = const [],
    this.spiceLevel,
    this.isSoldOut = false,
    this.isActive = true,
    this.prepTime,
    this.optionGroupCount = 0,
  });

  final String nameEn;
  final String nameBn;
  final String shortEn;
  final String shortBn;
  final double? price;
  final double? discountPrice;
  final String? imageUrl;
  final List<String> labels;
  final int? spiceLevel;
  final bool isSoldOut;
  final bool isActive;
  final int? prepTime;
  final int optionGroupCount;
}

/// "Customer card preview": the dish card as customers will see it, in the
/// business colours and theme, with an English and Bangla switch.
class ItemPreviewCard extends StatefulWidget {
  const ItemPreviewCard({super.key, required this.data, required this.business});

  final ItemPreviewData data;
  final Business? business;

  @override
  State<ItemPreviewCard> createState() => _ItemPreviewCardState();
}

class _ItemPreviewCardState extends State<ItemPreviewCard> {
  bool _bangla = false;

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final palette = MenuPalette.of(business?.menuTheme);
    final brand = hexToColor(business?.brandColor);
    final accent = palette.accentFor(brand);
    final currency = business?.currency ?? 'BDT';
    final d = widget.data;

    final name = pickText(d.nameEn, d.nameBn, bangla: _bangla) ?? (_bangla ? 'ডিশের নাম' : 'Dish name');
    final short = pickText(d.shortEn, d.shortBn, bangla: _bangla);
    final price = d.price;
    final hasDiscount = price != null && d.discountPrice != null && d.discountPrice! < price;
    final payable = hasDiscount ? d.discountPrice! : price;

    final shownLabels = [
      for (final id in d.labels.take(3)) menuTagName(menuLabels, id, bangla: _bangla),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedChoice<bool>(
          value: _bangla,
          onChanged: (value) => setState(() => _bangla = value),
          options: const [
            ChoiceOption(value: false, label: 'English'),
            ChoiceOption(value: true, label: 'Bangla'),
          ],
        ),
        const SizedBox(height: Sp.md),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(
            color: palette.paper,
            borderRadius: BorderRadius.circular(Rad.panel),
            border: Border.all(color: palette.line),
          ),
          child: Opacity(
            opacity: d.isActive ? 1 : 0.55,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (short != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          short,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: Sp.sm),
                      if (shownLabels.isNotEmpty || d.spiceLevel != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Sp.sm),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final label in shownLabels)
                                _Tag(text: label, palette: palette),
                              if (d.spiceLevel != null && d.spiceLevel! > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < d.spiceLevel!; i++)
                                      Icon(Icons.local_fire_department_rounded, size: 15, color: AppColors.chili),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          if (payable != null)
                            Text(
                              formatMoney(payable, currency: currency, bangla: _bangla),
                              style: TextStyle(
                                color: accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            Text('Price', style: TextStyle(color: palette.muted, fontSize: 14)),
                          if (hasDiscount) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(price, currency: currency, bangla: _bangla),
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          if (d.prepTime != null) ...[
                            const Spacer(),
                            Icon(Icons.schedule_rounded, size: 14, color: palette.muted),
                            const SizedBox(width: 3),
                            Text(
                              _bangla ? '${toBanglaDigits('${d.prepTime}')} মিনিট' : '${d.prepTime} min',
                              style: TextStyle(color: palette.muted, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      if (d.optionGroupCount > 0) ...[
                        const SizedBox(height: Sp.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _bangla ? 'কাস্টমাইজ করুন' : 'Customisable',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Sp.md),
                _Photo(url: d.imageUrl, soldOut: d.isSoldOut, palette: palette, bangla: _bangla),
              ],
            ),
          ),
        ),
        if (!d.isActive)
          Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(
              'This dish is hidden, so customers will not see this card.',
              style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.palette});

  final String text;
  final MenuPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.line),
      ),
      child: Text(text, style: TextStyle(color: palette.ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.url,
    required this.soldOut,
    required this.palette,
    required this.bangla,
  });

  final String? url;
  final bool soldOut;
  final MenuPalette palette;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    const size = 92.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          NetworkImageBox(url: url, width: size, height: size, radius: 14, cacheWidth: 92),
          if (soldOut)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  alignment: Alignment.center,
                  child: Text(
                    bangla ? 'শেষ' : 'Sold out',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
