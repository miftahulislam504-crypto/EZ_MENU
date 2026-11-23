import 'menu_models.dart';

/// Pure helpers for the variants and add-ons editor: presets, rules that keep
/// a group valid for the database, resulting prices and validation messages.

typedef IdGenerator = String Function();

enum OptionPreset { size, crust, spice, extras, iceSugar, blank }

const Map<OptionPreset, String> optionPresetLabels = {
  OptionPreset.size: 'Size',
  OptionPreset.crust: 'Crust',
  OptionPreset.spice: 'Spice level',
  OptionPreset.extras: 'Extras',
  OptionPreset.iceSugar: 'Ice and sugar',
  OptionPreset.blank: 'Blank group',
};

const int optionNameMaxLength = 120;

ItemOption _option(
  IdGenerator newId,
  String en,
  String bn, {
  double price = 0,
  bool isDefault = false,
}) => ItemOption(id: newId(), nameEn: en, nameBn: bn, price: price, isDefault: isDefault);

/// A ready-made group. For Size the prices start at [basePrice] (price mode
/// "absolute": each option is the full price of that size).
OptionGroup presetGroup(
  OptionPreset preset, {
  required double basePrice,
  required IdGenerator newId,
}) {
  switch (preset) {
    case OptionPreset.size:
      return OptionGroup(
        id: newId(),
        nameEn: 'Size',
        nameBn: 'সাইজ',
        selectType: 'single',
        priceMode: 'absolute',
        isRequired: true,
        minSelect: 1,
        maxSelect: 1,
        options: [
          _option(newId, 'Small', 'ছোট', price: basePrice),
          _option(newId, 'Medium', 'মাঝারি', price: basePrice, isDefault: true),
          _option(newId, 'Large', 'বড়', price: basePrice),
        ],
      );
    case OptionPreset.crust:
      return OptionGroup(
        id: newId(),
        nameEn: 'Crust',
        nameBn: 'ক্রাস্ট',
        isRequired: true,
        minSelect: 1,
        maxSelect: 1,
        options: [
          _option(newId, 'Thin', 'পাতলা', isDefault: true),
          _option(newId, 'Thick', 'মোটা'),
        ],
      );
    case OptionPreset.spice:
      return OptionGroup(
        id: newId(),
        nameEn: 'Spice level',
        nameBn: 'ঝালের মাত্রা',
        maxSelect: 1,
        options: [
          _option(newId, 'Mild', 'হালকা'),
          _option(newId, 'Medium', 'মাঝারি'),
          _option(newId, 'Hot', 'বেশি ঝাল'),
        ],
      );
    case OptionPreset.extras:
      return OptionGroup(
        id: newId(),
        nameEn: 'Extras',
        nameBn: 'অতিরিক্ত',
        selectType: 'multiple',
        options: [
          _option(newId, 'Extra cheese', 'এক্সট্রা চিজ'),
          _option(newId, 'Extra sauce', 'এক্সট্রা সস'),
          _option(newId, 'Egg', 'ডিম'),
        ],
      );
    case OptionPreset.iceSugar:
      return OptionGroup(
        id: newId(),
        nameEn: 'Ice and sugar',
        nameBn: 'বরফ ও চিনি',
        maxSelect: 1,
        options: [
          _option(newId, 'Regular', 'সাধারণ', isDefault: true),
          _option(newId, 'Less ice', 'কম বরফ'),
          _option(newId, 'Less sugar', 'কম চিনি'),
          _option(newId, 'No sugar', 'চিনি ছাড়া'),
        ],
      );
    case OptionPreset.blank:
      return OptionGroup(id: newId(), maxSelect: 1, options: [ItemOption(id: newId())]);
  }
}

/// Makes min and max consistent with the select type and the Required switch,
/// following the database rules:
///   single   => min is 0 or 1 (1 when required) and max is 1
///   multiple => min is 0 unless required (then at least 1);
///               max is empty or at least max(min, 1)
/// Defaults are trimmed so a single group never has two.
OptionGroup normalizeGroup(OptionGroup group) {
  var next = group;
  if (next.isSingle) {
    next = next.copyWith(minSelect: next.isRequired ? 1 : 0, maxSelect: 1);
    next = _singleDefault(next);
    return next;
  }
  var min = next.minSelect < 0 ? 0 : next.minSelect;
  if (!next.isRequired) {
    min = 0;
  } else if (min < 1) {
    min = 1;
  }
  final max = next.maxSelect;
  if (max != null && max < min) {
    return next.copyWith(minSelect: min, maxSelect: min);
  }
  return next.copyWith(minSelect: min);
}

OptionGroup _singleDefault(OptionGroup group) {
  var seen = false;
  final options = <ItemOption>[];
  for (final option in group.options) {
    if (option.isDefault && !seen) {
      seen = true;
      options.add(option);
    } else if (option.isDefault) {
      options.add(option.copyWith(isDefault: false));
    } else {
      options.add(option);
    }
  }
  return group.copyWith(options: options);
}

/// Marks one option as the default of a single group (clears the others), or
/// toggles it in a multiple group.
OptionGroup setDefaultOption(OptionGroup group, String optionId, bool value) {
  final options = [
    for (final o in group.options)
      if (o.id == optionId)
        o.copyWith(isDefault: value)
      else if (group.isSingle && value)
        o.copyWith(isDefault: false)
      else
        o,
  ];
  return group.copyWith(options: options);
}

/// The number of options a customer could pick, for the min and max steppers.
int availableOptionCount(OptionGroup group) =>
    group.options.where((o) => o.isAvailable).length;

/// A short rule shown to customers above the options, for example
/// "Choose 1", "Optional, choose up to 3" or "Choose 2 to 4".
String selectionHint(OptionGroup group) {
  if (group.isSingle) {
    return group.isRequired ? 'Choose 1' : 'Optional, choose 1';
  }
  final min = group.minSelect < 0 ? 0 : group.minSelect;
  final max = group.maxSelect;
  if (group.isRequired) {
    final low = min < 1 ? 1 : min;
    if (max == null) return low == 1 ? 'Choose at least 1' : 'Choose at least $low';
    if (max <= low) return 'Choose $low';
    return 'Choose $low to $max';
  }
  if (max == null) return 'Optional, choose any';
  return 'Optional, choose up to $max';
}

/// What the customer pays for one option: the dish price plus the option
/// (additional), or the option price itself (absolute). An empty absolute
/// price (0) means "same as the dish price" for display.
double optionResultPrice(OptionGroup group, ItemOption option, double basePrice) {
  final price = option.discountPrice ?? option.price;
  if (group.isAbsolute) {
    return price <= 0 ? basePrice : price;
  }
  return basePrice + price;
}

/// A deep copy with new ids (used by "copy from another dish").
OptionGroup cloneGroup(OptionGroup group, IdGenerator newId) {
  return OptionGroup(
    id: newId(),
    nameEn: group.nameEn,
    nameBn: group.nameBn,
    selectType: group.selectType,
    priceMode: group.priceMode,
    isRequired: group.isRequired,
    minSelect: group.minSelect,
    maxSelect: group.maxSelect,
    options: [
      for (final o in group.options)
        ItemOption(
          id: newId(),
          nameEn: o.nameEn,
          nameBn: o.nameBn,
          price: o.price,
          discountPrice: o.discountPrice,
          imageUrl: o.imageUrl,
          isDefault: o.isDefault,
          isAvailable: o.isAvailable,
        ),
    ],
  );
}

/// Appends deep copies of [source] groups to [existing].
List<OptionGroup> appendClones(
  List<OptionGroup> existing,
  List<OptionGroup> source,
  IdGenerator newId,
) => [...existing, for (final g in source) cloneGroup(g, newId)];

/// Image urls used by options, for deleting files that are no longer used.
Set<String> optionImageUrls(List<OptionGroup> groups) => {
  for (final g in groups)
    for (final o in g.options)
      if (o.imageUrl != null && o.imageUrl!.isNotEmpty) o.imageUrl!,
};

bool _blank(String? text) => text == null || text.trim().isEmpty;

String _groupLabel(OptionGroup group, int index) {
  final name = _blank(group.nameEn) ? group.nameBn : group.nameEn;
  return _blank(name) ? 'Group ${index + 1}' : 'Group "${name!.trim()}"';
}

/// Plain English problems, empty when the groups can be saved.
List<String> validateOptionGroups(List<OptionGroup> groups) {
  final errors = <String>[];
  for (var gi = 0; gi < groups.length; gi++) {
    final group = groups[gi];
    final label = _groupLabel(group, gi);
    final named = !_blank(group.nameEn) || !_blank(group.nameBn);

    if (!named) {
      errors.add('Group ${gi + 1} needs a name in English or Bangla.');
    }
    if ((group.nameEn ?? '').trim().length > optionNameMaxLength ||
        (group.nameBn ?? '').trim().length > optionNameMaxLength) {
      errors.add('$label: the name must be $optionNameMaxLength characters or fewer.');
    }
    if (group.options.isEmpty) {
      errors.add('$label: add at least one option.');
    }

    if (group.isSingle) {
      if (group.minSelect > 1 || (group.maxSelect != null && group.maxSelect != 1)) {
        errors.add('$label: a single choice group lets the customer pick exactly one option.');
      }
    } else {
      if (group.minSelect < 0) {
        errors.add('$label: the minimum cannot be negative.');
      }
      if (group.maxSelect != null && group.maxSelect! < 1) {
        errors.add('$label: the maximum must be at least 1.');
      } else if (group.maxSelect != null && group.maxSelect! < group.minSelect) {
        errors.add('$label: maximum must be at least the minimum.');
      }
    }

    if (group.isRequired && group.options.isNotEmpty && availableOptionCount(group) == 0) {
      errors.add('$label: a required choice needs at least one available option.');
    }
    if (group.isRequired && !group.isSingle) {
      final available = availableOptionCount(group);
      if (group.minSelect > available && available > 0) {
        errors.add('$label: the minimum is higher than the number of available options.');
      }
    }
    if (group.isSingle && group.options.where((o) => o.isDefault).length > 1) {
      errors.add('$label: only one option can be the default.');
    }

    for (var oi = 0; oi < group.options.length; oi++) {
      final option = group.options[oi];
      if (_blank(option.nameEn) && _blank(option.nameBn)) {
        errors.add('Option ${oi + 1} in $label needs a name.');
        continue;
      }
      final optionName = _blank(option.nameEn) ? option.nameBn!.trim() : option.nameEn!.trim();
      if ((option.nameEn ?? '').trim().length > optionNameMaxLength ||
          (option.nameBn ?? '').trim().length > optionNameMaxLength) {
        errors.add('Option "$optionName": the name must be $optionNameMaxLength characters or fewer.');
      }
      if (option.price < 0) {
        errors.add('Option "$optionName": the price cannot be negative.');
      }
      final discount = option.discountPrice;
      if (discount != null) {
        if (discount < 0) {
          errors.add('Option "$optionName": the discount price cannot be negative.');
        } else if (discount >= option.price) {
          errors.add('Option "$optionName": discount must be lower than the price.');
        }
      }
    }
  }
  return errors;
}
