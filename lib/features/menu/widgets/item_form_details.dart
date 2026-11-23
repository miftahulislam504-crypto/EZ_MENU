import 'package:flutter/material.dart';

import '../../../core/logic/menu_catalog.dart';
import '../../../core/utils/controllers.dart';
import '../../../core/widgets/widgets.dart';
import 'editor_common.dart';

/// Labels, spice level, allergens, ingredients, calories and nutrition.
class ItemDetailsSection extends StatelessWidget {
  const ItemDetailsSection({
    super.key,
    required this.controllers,
    required this.errors,
    required this.labels,
    required this.onLabels,
    required this.allergens,
    required this.onAllergens,
    required this.spiceLevel,
    required this.onSpice,
  });

  final ControllerBag controllers;
  final Map<String, String> errors;
  final List<String> labels;
  final ValueChanged<List<String>> onLabels;
  final List<String> allergens;
  final ValueChanged<List<String>> onAllergens;
  final int? spiceLevel;
  final ValueChanged<int?> onSpice;

  List<String> _toggled(List<String> values, String id, bool on) {
    final next = values.where((v) => v != id).toList();
    if (on) next.add(id);
    return next;
  }

  Widget _tagChips(
    List<MenuTag> tags,
    List<String> selected,
    ValueChanged<List<String>> onChanged,
  ) {
    return Wrap(
      spacing: Sp.sm,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          FilterChip(
            label: Text(tag.en),
            selected: selected.contains(tag.id),
            visualDensity: VisualDensity.compact,
            onSelected: (on) => onChanged(_toggled(selected, tag.id, on)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FormSection(
      title: 'Details',
      subtitle: 'All optional. Labels and allergens help customers choose with confidence.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Labels', optional: true),
            const SizedBox(height: Sp.sm),
            _tagChips(menuLabels, labels, onLabels),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Spice level', optional: true),
            const SizedBox(height: Sp.sm),
            Wrap(
              spacing: Sp.sm,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Not set'),
                  selected: spiceLevel == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSpice(null),
                ),
                for (final level in menuSpiceLevels)
                  ChoiceChip(
                    label: Text(level.en),
                    selected: spiceLevel.toString() == level.id,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onSpice(int.parse(level.id)),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Allergens', optional: true),
            const SizedBox(height: Sp.sm),
            _tagChips(menuAllergens, allergens, onAllergens),
          ],
        ),
        AppTextField(
          label: 'Allergen note',
          optional: true,
          controller: controllers['allergenNote'],
          hint: 'May contain traces of nuts',
          maxLines: 2,
          maxLength: 400,
          validator: (_) => errors['allergenNote'],
        ),
        AppTextField(
          label: 'Dietary information',
          optional: true,
          controller: controllers['dietary'],
          hint: 'Prepared without pork or alcohol',
          maxLines: 2,
          maxLength: 400,
          validator: (_) => errors['dietaryInfo'],
        ),
        BilingualFields(
          label: 'Ingredients',
          englishController: controllers['ingEn'],
          banglaController: controllers['ingBn'],
          optional: true,
          maxLines: 3,
          maxLength: 800,
          hintBangla: 'মুরগি, পাউরুটি, সস',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: AppTextField(
                label: 'Calories',
                optional: true,
                controller: controllers['calories'],
                hint: '450',
                helper: 'kcal per serving',
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters,
                validator: (_) => errors['calories'],
              ),
            ),
            const SizedBox(height: Sp.lg),
            Text('Nutrition per serving', style: context.textStyles.titleSmall),
            Text(
              'Only the values you fill in are shown to customers.',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Sp.md),
            Wrap(
              spacing: Sp.md,
              runSpacing: Sp.md,
              children: [
                for (final field in nutritionFields)
                  SizedBox(
                    width: 150,
                    child: AppTextField(
                      label: '${field.en} (${field.unit})',
                      controller: controllers['nutrition.${field.key}'],
                      keyboardType: moneyKeyboard,
                      inputFormatters: moneyInputFormatters,
                      validator: (_) => errors['nutrition.${field.key}'],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
