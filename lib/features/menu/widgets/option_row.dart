import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../option_groups_logic.dart';
import 'editor_common.dart';

/// The text controllers of one option row.
class OptionControllers {
  OptionControllers(ItemOption option)
    : nameEn = TextEditingController(text: option.nameEn ?? ''),
      nameBn = TextEditingController(text: option.nameBn ?? ''),
      price = TextEditingController(text: option.price == 0 ? '' : plainNumber(option.price)),
      discount = TextEditingController(text: plainNumber(option.discountPrice)),
      focus = FocusNode();

  final TextEditingController nameEn;
  final TextEditingController nameBn;
  final TextEditingController price;
  final TextEditingController discount;

  /// Focus of the English name, used to jump to a new option.
  final FocusNode focus;

  void dispose() {
    nameEn.dispose();
    nameBn.dispose();
    price.dispose();
    discount.dispose();
    focus.dispose();
  }
}

/// One option inside a group: names, price, discount, default, availability
/// and an optional picture.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.index,
    required this.group,
    required this.option,
    required this.controllers,
    required this.basePrice,
    required this.currency,
    required this.uploading,
    required this.onNameEn,
    required this.onNameBn,
    required this.onPrice,
    required this.onDiscount,
    required this.onDefault,
    required this.onAvailable,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onDelete,
    required this.onSubmitted,
  });

  final int index;
  final OptionGroup group;
  final ItemOption option;
  final OptionControllers controllers;
  final double basePrice;
  final String currency;
  final bool uploading;
  final ValueChanged<String> onNameEn;
  final ValueChanged<String> onNameBn;
  final ValueChanged<String> onPrice;
  final ValueChanged<String> onDiscount;
  final ValueChanged<bool> onDefault;
  final ValueChanged<bool> onAvailable;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onDelete;

  /// The person pressed Enter in a name field.
  final VoidCallback onSubmitted;

  String _resultText() {
    final result = optionResultPrice(group, option, basePrice);
    final total = formatMoney(result, currency: currency);
    if (group.isAbsolute) {
      return option.price <= 0
          ? 'Same as the dish price: $total'
          : 'Customer pays $total';
    }
    return 'Dish total with this option: $total';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final symbol = currencySymbol(currency);

    final english = AppTextField(
      label: 'Name in English',
      controller: controllers.nameEn,
      focusNode: controllers.focus,
      hint: 'e.g. Large',
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onNameEn,
      onSubmitted: (_) => onSubmitted(),
    );
    final bangla = AppTextField(
      label: 'Name in Bangla',
      controller: controllers.nameBn,
      hint: 'যেমন: বড়',
      textInputAction: TextInputAction.next,
      onChanged: onNameBn,
      onSubmitted: (_) => onSubmitted(),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(2, Sp.sm, Sp.sm, Sp.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.control),
        border: Border.all(
          color: option.isDefault && option.isAvailable
              ? context.colors.primary.withValues(alpha: 0.45)
              : palette.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: DragHandle(index: index, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 440) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: english),
                          const SizedBox(width: Sp.md),
                          Expanded(child: bangla),
                        ],
                      );
                    }
                    return Column(
                      children: [english, const SizedBox(height: Sp.sm), bangla],
                    );
                  },
                ),
                const SizedBox(height: Sp.md),
                Wrap(
                  spacing: Sp.md,
                  runSpacing: Sp.sm,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 136,
                      child: AppTextField(
                        label: group.isAbsolute ? 'Price' : 'Extra price',
                        controller: controllers.price,
                        prefixText: '$symbol ',
                        hint: group.isAbsolute ? 'Dish price' : '0',
                        keyboardType: moneyKeyboard,
                        inputFormatters: moneyInputFormatters,
                        onChanged: onPrice,
                      ),
                    ),
                    SizedBox(
                      width: 156,
                      child: AppTextField(
                        label: 'Discount price',
                        optional: true,
                        controller: controllers.discount,
                        prefixText: '$symbol ',
                        keyboardType: moneyKeyboard,
                        inputFormatters: moneyInputFormatters,
                        onChanged: onDiscount,
                      ),
                    ),
                    _ImageButton(
                      url: option.imageUrl,
                      uploading: uploading,
                      onPick: onPickImage,
                      onRemove: onRemoveImage,
                    ),
                  ],
                ),
                const SizedBox(height: Sp.sm),
                Text(
                  _resultText(),
                  style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: Sp.sm),
                Wrap(
                  spacing: Sp.sm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Default'),
                      selected: option.isDefault,
                      onSelected: onDefault,
                      visualDensity: VisualDensity.compact,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: option.isAvailable, onChanged: onAvailable),
                        Text(
                          option.isAvailable ? 'Available' : 'Unavailable',
                          style: context.textStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove option',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: Icon(Icons.close_rounded, size: 20, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ImageButton extends StatelessWidget {
  const _ImageButton({
    required this.url,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const size = 48.0;
    final hasImage = url != null && url!.isNotEmpty;
    if (uploading) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(Rad.control),
          border: Border.all(color: palette.line),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    if (!hasImage) {
      return Tooltip(
        message: 'Add a photo of this option',
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.control),
          onTap: onPick,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.control),
              border: Border.all(color: palette.lineStrong),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 22,
              color: palette.muted,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.control),
              onTap: onPick,
              child: NetworkImageBox(
                url: url,
                width: size,
                height: size,
                radius: Rad.control,
                cacheWidth: 48,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Tooltip(
              message: 'Remove photo',
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.lineStrong),
                  ),
                  child: Icon(Icons.close_rounded, size: 14, color: palette.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
