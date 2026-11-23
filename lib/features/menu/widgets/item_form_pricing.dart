import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/utils/controllers.dart';
import '../../../core/widgets/widgets.dart';
import '../item_form_logic.dart';
import 'editor_common.dart';

/// Regular price, discount price, preparation time and the internal code.
class ItemPricingSection extends StatelessWidget {
  const ItemPricingSection({
    super.key,
    required this.controllers,
    required this.errors,
    required this.currency,
  });

  final ControllerBag controllers;
  final Map<String, String> errors;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(currency);
    final price = parseMoneyText(controllers.text('price'));
    final discount = parseMoneyText(controllers.text('discount'));
    final saving = savingFor(price, discount);

    return FormSection(
      title: 'Pricing',
      subtitle: 'Prices are in ${currency.toUpperCase()}. Bangla digits are accepted.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Regular price',
                controller: controllers['price'],
                prefixText: '$symbol ',
                hint: '250',
                keyboardType: moneyKeyboard,
                inputFormatters: moneyInputFormatters,
                textInputAction: TextInputAction.next,
                validator: (_) => errors['price'],
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: AppTextField(
                label: 'Discount price',
                optional: true,
                controller: controllers['discount'],
                prefixText: '$symbol ',
                keyboardType: moneyKeyboard,
                inputFormatters: moneyInputFormatters,
                textInputAction: TextInputAction.next,
                validator: (_) => errors['discount'],
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: saving == null
              ? const SizedBox(width: double.infinity)
              : Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    'Customers save ${formatMoney(saving.amount, currency: currency)} (${saving.percent}% off)',
                    tone: PillTone.success,
                    icon: Icons.local_offer_outlined,
                  ),
                ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Preparation time',
                optional: true,
                controller: controllers['prep'],
                hint: '15',
                helper: 'Minutes, 0 to 600',
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters,
                textInputAction: TextInputAction.next,
                validator: (_) => errors['prepTime'],
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: AppTextField(
                label: 'Item code',
                optional: true,
                controller: controllers['sku'],
                hint: 'CB-01',
                helper: 'Your own code, SKU',
                maxLength: 60,
                textCapitalization: TextCapitalization.characters,
                validator: (_) => errors['sku'],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
