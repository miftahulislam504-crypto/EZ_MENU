import 'package:flutter/material.dart';

import '../../../core/utils/controllers.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import 'category_picker.dart';

/// Name, descriptions, category and visibility of a dish.
class ItemBasicsSection extends StatelessWidget {
  const ItemBasicsSection({
    super.key,
    required this.controllers,
    required this.errors,
    required this.categories,
    required this.categoryId,
    required this.onCategory,
    required this.isFeatured,
    required this.onFeatured,
    required this.isActive,
    required this.onActive,
  });

  final ControllerBag controllers;
  final Map<String, String> errors;
  final List<MenuCategory> categories;
  final String? categoryId;
  final ValueChanged<String> onCategory;
  final bool isFeatured;
  final ValueChanged<bool> onFeatured;
  final bool isActive;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Basics',
      subtitle: 'Fill in at least one language. Customers see the language they choose.',
      children: [
        BilingualFields(
          label: 'Name',
          englishController: controllers['nameEn'],
          banglaController: controllers['nameBn'],
          requireOne: true,
          maxLength: 160,
          hintEnglish: 'Chicken burger',
          hintBangla: 'চিকেন বার্গার',
        ),
        BilingualFields(
          label: 'Short description',
          englishController: controllers['shortEn'],
          banglaController: controllers['shortBn'],
          optional: true,
          maxLines: 2,
          maxLength: 200,
          hintBangla: 'এক লাইনের বর্ণনা',
        ),
        BilingualFields(
          label: 'Description',
          englishController: controllers['descEn'],
          banglaController: controllers['descBn'],
          optional: true,
          maxLines: 4,
          maxLength: 2000,
          hintBangla: 'খাবারের বিস্তারিত বর্ণনা',
        ),
        CategoryField(
          categories: categories,
          categoryId: categoryId,
          errorText: errors['category'],
          onChanged: onCategory,
        ),
        SwitchRow(
          title: 'Featured',
          subtitle: 'Highlight this dish near the top of the customer menu.',
          value: isFeatured,
          onChanged: onFeatured,
        ),
        SwitchRow(
          title: 'Visible to customers',
          subtitle: 'Turn off to hide this dish everywhere without deleting it.',
          value: isActive,
          onChanged: onActive,
        ),
      ],
    );
  }
}

/// Shows the chosen category (parent and child) and opens the category sheet.
class CategoryField extends StatelessWidget {
  const CategoryField({
    super.key,
    required this.categories,
    required this.categoryId,
    required this.onChanged,
    this.errorText,
  });

  final List<MenuCategory> categories;
  final String? categoryId;
  final ValueChanged<String> onChanged;
  final String? errorText;

  String? _label() {
    for (final c in categories) {
      if (c.id != categoryId) continue;
      if (c.parentId == null) return c.displayName;
      for (final p in categories) {
        if (p.id == c.parentId) return '${p.displayName} / ${c.displayName}';
      }
      return c.displayName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = _label();
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Category'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(Rad.control),
          onTap: () async {
            final pick = await showCategoryPicker(
              context,
              categories: categories,
              selectedId: categoryId,
              counts: const {},
            );
            if (pick?.id != null) onChanged(pick!.id!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.control),
              border: Border.all(
                color: hasError ? palette.danger : palette.lineStrong,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label ?? 'Choose a category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: label == null ? palette.muted : null,
                    ),
                  ),
                ),
                Icon(Icons.unfold_more_rounded, color: palette.muted),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: context.textStyles.bodySmall?.copyWith(color: palette.danger),
            ),
          ),
      ],
    );
  }
}
