import '../../core/logic/menu_catalog.dart';
import '../../core/logic/money.dart';
import 'menu_models.dart';

export '../../core/logic/money.dart' show parseMoneyText;

/// Pure logic of the dish editor: parsing what was typed, validation, the
/// column values to save, the saving shown next to a discount, and which photo
/// files to delete. No Flutter or Supabase imports.

const int maxItemImages = 8;
const double maxItemPrice = 10000000;

/// What the form holds, as typed (strings are not trimmed or parsed yet).
class ItemFormInput {
  const ItemFormInput({
    this.nameEn = '',
    this.nameBn = '',
    this.shortEn = '',
    this.shortBn = '',
    this.descEn = '',
    this.descBn = '',
    this.ingredientsEn = '',
    this.ingredientsBn = '',
    this.price = '',
    this.discountPrice = '',
    this.prepTime = '',
    this.sku = '',
    this.allergenNote = '',
    this.dietaryInfo = '',
    this.calories = '',
    this.nutrition = const {},
    this.categoryId,
    this.labels = const [],
    this.allergens = const [],
    this.spiceLevel,
    this.imageUrls = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.isSoldOut = false,
    this.soldOutUntil,
  });

  final String nameEn;
  final String nameBn;
  final String shortEn;
  final String shortBn;
  final String descEn;
  final String descBn;
  final String ingredientsEn;
  final String ingredientsBn;
  final String price;
  final String discountPrice;
  final String prepTime;
  final String sku;
  final String allergenNote;
  final String dietaryInfo;
  final String calories;

  /// Nutrition field key (see `nutritionFields`) to the typed text.
  final Map<String, String> nutrition;
  final String? categoryId;
  final List<String> labels;
  final List<String> allergens;
  final int? spiceLevel;
  final List<String> imageUrls;
  final bool isActive;
  final bool isFeatured;
  final bool isSoldOut;
  final DateTime? soldOutUntil;
}

/// A whole number such as "20" or "২০". Null when empty or not whole.
int? parseWholeNumber(String? text) {
  final value = parseMoneyText(text);
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}

/// Money saved by a discount.
class Saving {
  const Saving(this.amount, this.percent);
  final double amount;
  final int percent;
}

/// The saving shown under the price fields; null when there is none.
Saving? savingFor(double? price, double? discount) {
  if (price == null || discount == null || price <= 0 || discount >= price || discount < 0) {
    return null;
  }
  final amount = price - discount;
  final percent = (amount / price * 100).round();
  return Saving(amount, percent < 1 ? 1 : percent);
}

String _t(String value) => value.trim();

/// Field key to message. Empty means the form can be saved. Keys: `name`,
/// `nameEn`, `nameBn`, `shortEn`, `shortBn`, `descEn`, `descBn`,
/// `ingredientsEn`, `ingredientsBn`, `price`, `discount`, `prepTime`, `sku`,
/// `allergenNote`, `dietaryInfo`, `calories`, `nutrition.<key>`, `category`,
/// `images`, `soldOutUntil`.
Map<String, String> validateItemForm(ItemFormInput input, {DateTime? now}) {
  final errors = <String, String>{};

  final en = _t(input.nameEn);
  final bn = _t(input.nameBn);
  if (en.isEmpty && bn.isEmpty) {
    errors['name'] = 'Enter a name in English or Bangla.';
  }
  void maxLength(String key, String value, int max, String label) {
    if (_t(value).length > max) {
      errors[key] = '$label must be $max characters or fewer.';
    }
  }

  maxLength('nameEn', input.nameEn, 160, 'The English name');
  maxLength('nameBn', input.nameBn, 160, 'The Bangla name');
  maxLength('shortEn', input.shortEn, 200, 'The English short description');
  maxLength('shortBn', input.shortBn, 200, 'The Bangla short description');
  maxLength('descEn', input.descEn, 2000, 'The English description');
  maxLength('descBn', input.descBn, 2000, 'The Bangla description');
  maxLength('ingredientsEn', input.ingredientsEn, 800, 'The English ingredients');
  maxLength('ingredientsBn', input.ingredientsBn, 800, 'The Bangla ingredients');
  maxLength('sku', input.sku, 60, 'The item code');
  maxLength('allergenNote', input.allergenNote, 400, 'The allergen note');
  maxLength('dietaryInfo', input.dietaryInfo, 400, 'The dietary information');

  final priceText = _t(input.price);
  double? price;
  if (priceText.isEmpty) {
    errors['price'] = 'Enter the regular price.';
  } else {
    price = parseMoneyText(priceText);
    if (price == null) {
      errors['price'] = priceText.startsWith('-')
          ? 'The price cannot be negative.'
          : 'Enter a valid price, for example 250 or 99.50.';
    } else if (price > maxItemPrice) {
      errors['price'] = 'The price is too high.';
    }
  }

  final discountText = _t(input.discountPrice);
  if (discountText.isNotEmpty) {
    final discount = parseMoneyText(discountText);
    if (discount == null) {
      errors['discount'] = discountText.startsWith('-')
          ? 'The discount price cannot be negative.'
          : 'Enter the discount price as a number.';
    } else if (price != null && discount >= price) {
      errors['discount'] = 'The discount price must be lower than the regular price.';
    }
  }

  final prepText = _t(input.prepTime);
  if (prepText.isNotEmpty) {
    final prep = parseWholeNumber(prepText);
    if (prep == null || prep < 0 || prep > 600) {
      errors['prepTime'] = 'Use a whole number of minutes from 0 to 600.';
    }
  }

  final caloriesText = _t(input.calories);
  if (caloriesText.isNotEmpty) {
    final calories = parseWholeNumber(caloriesText);
    if (calories == null || calories < 0) {
      errors['calories'] = 'Calories must be a whole number, 0 or more.';
    }
  }

  for (final field in nutritionFields) {
    final text = _t(input.nutrition[field.key] ?? '');
    if (text.isEmpty) continue;
    final value = parseMoneyText(text);
    if (value == null) {
      errors['nutrition.${field.key}'] = '${field.en} must be a number, 0 or more.';
    }
  }

  if (input.categoryId == null || input.categoryId!.isEmpty) {
    errors['category'] = 'Choose a category.';
  }
  if (input.imageUrls.length > maxItemImages) {
    errors['images'] = 'A dish can have at most $maxItemImages photos.';
  }
  final until = input.soldOutUntil;
  if (input.isSoldOut && until != null && !until.isAfter(now ?? DateTime.now())) {
    errors['soldOutUntil'] = 'The return time must be in the future.';
  }
  return errors;
}

String? _nullIfEmpty(String value) {
  final t = value.trim();
  return t.isEmpty ? null : t;
}

num _tidy(double value) => value == value.roundToDouble() ? value.toInt() : value;

/// Column values for `menu_items` (insert or update). Call only after
/// [validateItemForm] returned no errors. Unknown labels and allergens are
/// dropped so they can never violate the database check.
Map<String, dynamic> itemValues(ItemFormInput input, {int? sortOrder}) {
  final labelIds = {for (final t in menuLabels) t.id};
  final allergenIds = {for (final t in menuAllergens) t.id};

  final nutrition = <String, dynamic>{};
  for (final field in nutritionFields) {
    final value = parseMoneyText(input.nutrition[field.key]);
    if (value != null) nutrition[field.key] = _tidy(value);
  }

  List<String> pick(List<String> values, Set<String> allowed) {
    final seen = <String>{};
    return [
      for (final v in values)
        if (allowed.contains(v) && seen.add(v)) v,
    ];
  }

  return {
    'category_id': input.categoryId,
    'name_en': _nullIfEmpty(input.nameEn),
    'name_bn': _nullIfEmpty(input.nameBn),
    'short_description_en': _nullIfEmpty(input.shortEn),
    'short_description_bn': _nullIfEmpty(input.shortBn),
    'description_en': _nullIfEmpty(input.descEn),
    'description_bn': _nullIfEmpty(input.descBn),
    'ingredients_en': _nullIfEmpty(input.ingredientsEn),
    'ingredients_bn': _nullIfEmpty(input.ingredientsBn),
    'price': parseMoneyText(input.price) ?? 0,
    'discount_price': parseMoneyText(input.discountPrice),
    'prep_time_min': parseWholeNumber(input.prepTime),
    'sku': _nullIfEmpty(input.sku),
    'labels': pick(input.labels, labelIds),
    'allergens': pick(input.allergens, allergenIds),
    'allergen_note': _nullIfEmpty(input.allergenNote),
    'dietary_info': _nullIfEmpty(input.dietaryInfo),
    'spice_level': input.spiceLevel,
    'calories': parseWholeNumber(input.calories),
    'nutrition': nutrition,
    'image_urls': input.imageUrls,
    'is_active': input.isActive,
    'is_featured': input.isFeatured,
    'is_sold_out': input.isSoldOut,
    'sold_out_until': input.isSoldOut ? input.soldOutUntil?.toUtc().toIso8601String() : null,
    if (sortOrder != null) 'sort_order': sortOrder,
  };
}

/// A stable text of the whole form, to tell whether anything changed.
String itemFormSignature(ItemFormInput input) {
  final nutrition = [
    for (final field in nutritionFields) '${field.key}=${input.nutrition[field.key] ?? ''}',
  ].join(',');
  return [
    input.nameEn,
    input.nameBn,
    input.shortEn,
    input.shortBn,
    input.descEn,
    input.descBn,
    input.ingredientsEn,
    input.ingredientsBn,
    input.price,
    input.discountPrice,
    input.prepTime,
    input.sku,
    input.allergenNote,
    input.dietaryInfo,
    input.calories,
    nutrition,
    input.categoryId ?? '',
    (input.labels.toList()..sort()).join(','),
    (input.allergens.toList()..sort()).join(','),
    '${input.spiceLevel}',
    input.imageUrls.join(','),
    '${input.isActive}',
    '${input.isFeatured}',
    '${input.isSoldOut}',
    input.soldOutUntil?.toUtc().toIso8601String() ?? '',
  ].join('|');
}

// ---- photos ---------------------------------------------------------------

/// Makes the photo at [index] the cover (first position).
List<String> makeCover(List<String> urls, int index) {
  if (index <= 0 || index >= urls.length) return List<String>.of(urls);
  final next = List<String>.of(urls);
  final url = next.removeAt(index);
  next.insert(0, url);
  return next;
}

List<String> removeImageAt(List<String> urls, int index) {
  if (index < 0 || index >= urls.length) return List<String>.of(urls);
  return [...urls.sublist(0, index), ...urls.sublist(index + 1)];
}

/// Moves a photo (Flutter `onReorder` convention).
List<String> moveImage(List<String> urls, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= urls.length) return List<String>.of(urls);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, urls.length - 1);
  final next = List<String>.of(urls);
  next.insert(target, next.removeAt(oldIndex));
  return next;
}

/// Files to delete once the dish is saved: photos that were on the dish before
/// and are gone now, plus uploads of this session that ended up unused.
List<String> imagesToDeleteAfterSave({
  required List<String> original,
  required List<String> current,
  required Iterable<String> sessionUploads,
}) {
  final keep = current.toSet();
  final result = <String>{};
  for (final url in original) {
    if (!keep.contains(url)) result.add(url);
  }
  for (final url in sessionUploads) {
    if (!keep.contains(url)) result.add(url);
  }
  return result.toList();
}

/// Files to delete when the person discards the form: every upload of this
/// session (the original photos stay).
List<String> imagesToDeleteOnDiscard({
  required List<String> original,
  required Iterable<String> sessionUploads,
}) {
  final keep = original.toSet();
  return [
    for (final url in sessionUploads.toSet())
      if (!keep.contains(url)) url,
  ];
}

// ---- change detection for the sub-resources ----------------------------------

/// A stable text of the option groups, to tell whether they changed.
String optionGroupsSignature(List<OptionGroup> groups) {
  return groups
      .map((g) {
        final options = g.options
            .map(
              (o) => [
                o.id,
                o.nameEn ?? '',
                o.nameBn ?? '',
                o.price,
                o.discountPrice ?? '',
                o.imageUrl ?? '',
                o.isDefault,
                o.isAvailable,
              ].join('~'),
            )
            .join('^');
        return [
          g.id,
          g.nameEn ?? '',
          g.nameBn ?? '',
          g.selectType,
          g.priceMode,
          g.isRequired,
          g.minSelect,
          g.maxSelect ?? '',
          options,
        ].join('|');
      })
      .join('#');
}

/// A stable text of the availability windows, to tell whether they changed.
String schedulesSignature(List<ItemSchedule> windows) {
  return windows
      .map(
        (w) => [
          (w.weekdays.toList()..sort()).join(','),
          w.startTime ?? '',
          w.endTime ?? '',
          w.startDate ?? '',
          w.endDate ?? '',
          (w.label ?? '').trim(),
        ].join('|'),
      )
      .join('#');
}

/// One branch entry as text.
String branchSettingSignature(BranchItemSetting s) => [
  s.branchId,
  s.isOffered,
  s.price ?? '',
  s.price == null ? '' : (s.discountPrice ?? ''),
  s.isSoldOut,
  s.isSoldOut ? (s.soldOutUntil?.toUtc().toIso8601String() ?? '') : '',
].join('|');

/// All branch entries as text, independent of their order.
String branchSettingsSignature(List<BranchItemSetting> settings) {
  final parts = settings.map(branchSettingSignature).toList()..sort();
  return parts.join('#');
}
