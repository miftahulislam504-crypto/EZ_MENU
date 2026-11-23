import '../../core/logic/bd_phone.dart';
import '../../core/logic/hours.dart';
import '../../core/logic/localized.dart';
import '../../core/logic/menu_catalog.dart';
import '../../core/logic/money.dart';
import '../../core/logic/pricing.dart';
import 'public_menu_models.dart';

/// Everything the customer menu decides without drawing anything: names in the
/// chosen language, sections, search, filters, prices, opening hours and
/// contact links. Pure Dart (no Flutter imports) and unit tested.

// ---- names --------------------------------------------------------------------------

String businessDisplayName(PublicBusiness business, {required bool bangla}) =>
    pickTextOr(business.nameEn, business.nameBn, bangla: bangla, fallback: 'Menu');

String branchDisplayName(PublicBranch branch, {required bool bangla}) =>
    pickTextOr(branch.nameEn, branch.nameBn, bangla: bangla);

String branchLinkName(PublicBranchLink branch, {required bool bangla}) =>
    pickTextOr(branch.nameEn, branch.nameBn, bangla: bangla, fallback: branch.slug);

String itemDisplayName(PublicItem item, {required bool bangla}) =>
    pickTextOr(item.nameEn, item.nameBn, bangla: bangla, fallback: bangla ? 'খাবার' : 'Dish');

String categoryDisplayName(PublicCategory category, {required bool bangla}) =>
    pickTextOr(category.nameEn, category.nameBn, bangla: bangla, fallback: bangla ? 'অন্যান্য' : 'Other');

String optionDisplayName(PublicOption option, {required bool bangla}) =>
    pickTextOr(option.nameEn, option.nameBn, bangla: bangla);

String groupDisplayName(PublicOptionGroup group, {required bool bangla}) =>
    pickTextOr(group.nameEn, group.nameBn, bangla: bangla, fallback: bangla ? 'পছন্দ' : 'Options');

/// Short line on a dish card: the short description, else the start of the
/// long one.
String? itemSummary(PublicItem item, {required bool bangla}) {
  final short = pickText(item.shortEn, item.shortBn, bangla: bangla);
  if (short != null) return short;
  return pickText(item.descriptionEn, item.descriptionBn, bangla: bangla);
}

/// "Table 5" / "টেবিল ৫", "Takeaway" / "টেকঅ্যাওয়ে", or null for a plain menu.
String? contextLabel(PublicContext context, {required bool bangla}) {
  if (context.isTable) {
    final name = context.tableName!.trim();
    return bangla ? 'টেবিল ${toBanglaDigits(name)}' : 'Table $name';
  }
  if (context.isTakeaway) return bangla ? 'টেকঅ্যাওয়ে' : 'Takeaway';
  return null;
}

// ---- search and filters ----------------------------------------------------------

/// Label ids offered as filter chips, in this order, when the menu has them.
const List<String> filterLabelIds = [
  'vegetarian',
  'vegan',
  'halal',
  'spicy',
  'gluten_free',
  'dairy_free',
];

/// The filters worth showing: only labels at least one dish has.
List<String> availableFilters(Iterable<PublicItem> items) {
  final present = <String>{for (final item in items) ...item.labels};
  return [
    for (final id in filterLabelIds)
      if (present.contains(id)) id,
  ];
}

String _normalize(String text) => toAsciiDigits(text.toLowerCase()).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Bangla digits to ASCII so "২" and "2" find each other.
String toAsciiDigits(String input) {
  const digits = '০১২৩৪৫৬৭৮৯';
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final index = digits.indexOf(ch);
    out.write(index >= 0 ? index.toString() : ch);
  }
  return out.toString();
}

String _haystack(PublicItem item) {
  final parts = <String?>[
    item.nameEn,
    item.nameBn,
    item.shortEn,
    item.shortBn,
    item.descriptionEn,
    item.descriptionBn,
    item.ingredientsEn,
    item.ingredientsBn,
    for (final id in item.labels) menuTagName(menuLabels, id),
    for (final id in item.labels) menuTagName(menuLabels, id, bangla: true),
  ];
  return _normalize(parts.whereType<String>().join(' '));
}

/// True when every word of [query] appears somewhere in the dish's names,
/// descriptions, ingredients or labels. An empty query matches everything.
bool matchesQuery(PublicItem item, String query) {
  final words = _normalize(query).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final text = _haystack(item);
  return words.every(text.contains);
}

/// True when the dish carries every selected label and, if asked, can be
/// ordered right now.
bool matchesFilters(PublicItem item, Set<String> labels, {bool onlyAvailable = false}) {
  if (onlyAvailable && !item.availability.canOrder) return false;
  return labels.every(item.labels.contains);
}

// ---- sections ------------------------------------------------------------------------

/// One block of dishes under a heading. A subcategory carries its parent's name.
class MenuSection {
  const MenuSection({
    required this.id,
    required this.rootId,
    required this.title,
    required this.items,
    this.parentTitle,
    this.description,
    this.imageUrl,
  });

  final String id;

  /// Top level category this block belongs to (the category bar jumps here).
  final String rootId;
  final String title;
  final String? parentTitle;
  final String? description;
  final String? imageUrl;
  final List<PublicItem> items;
}

/// A top level category for the category bar.
class MenuRoot {
  const MenuRoot({required this.id, required this.title, this.imageUrl, this.icon});

  final String id;
  final String title;
  final String? imageUrl;
  final String? icon;
}

const String otherSectionId = '_other';

/// Groups dishes by category, parents first and their subcategories after, in
/// the order the restaurant set. Categories with nothing to show are left out.
/// A dish in a category the menu does not list goes to "Other" at the end.
List<MenuSection> buildSections(
  PublicMenuData data, {
  required bool bangla,
  String query = '',
  Set<String> filters = const {},
  bool onlyAvailable = false,
}) {
  final byCategory = <String, List<PublicItem>>{};
  for (final item in data.items) {
    if (!matchesQuery(item, query) || !matchesFilters(item, filters, onlyAvailable: onlyAvailable)) {
      continue;
    }
    byCategory.putIfAbsent(item.categoryId, () => []).add(item);
  }

  final known = {for (final c in data.categories) c.id};
  final roots = [
    for (final c in data.categories)
      if (c.parentId == null || !known.contains(c.parentId)) c,
  ];
  final childrenOf = <String, List<PublicCategory>>{};
  for (final c in data.categories) {
    final parent = c.parentId;
    if (parent != null && known.contains(parent)) {
      childrenOf.putIfAbsent(parent, () => []).add(c);
    }
  }

  final sections = <MenuSection>[];
  final placed = <String>{};
  for (final root in roots) {
    final rootTitle = categoryDisplayName(root, bangla: bangla);
    final own = byCategory[root.id];
    placed.add(root.id);
    if (own != null && own.isNotEmpty) {
      sections.add(
        MenuSection(
          id: root.id,
          rootId: root.id,
          title: rootTitle,
          description: pickText(root.descriptionEn, root.descriptionBn, bangla: bangla),
          imageUrl: root.imageUrl,
          items: own,
        ),
      );
    }
    for (final child in childrenOf[root.id] ?? const <PublicCategory>[]) {
      placed.add(child.id);
      final items = byCategory[child.id];
      if (items == null || items.isEmpty) continue;
      sections.add(
        MenuSection(
          id: child.id,
          rootId: root.id,
          title: categoryDisplayName(child, bangla: bangla),
          parentTitle: rootTitle,
          description: pickText(child.descriptionEn, child.descriptionBn, bangla: bangla),
          imageUrl: child.imageUrl,
          items: items,
        ),
      );
    }
  }
  final stray = [
    for (final entry in byCategory.entries)
      if (!placed.contains(entry.key)) ...entry.value,
  ];
  if (stray.isNotEmpty) {
    sections.add(
      MenuSection(
        id: otherSectionId,
        rootId: otherSectionId,
        title: bangla ? 'অন্যান্য' : 'Other',
        items: stray,
      ),
    );
  }
  return sections;
}

/// The category bar: each top level category that has a section, in order.
List<MenuRoot> buildRoots(
  PublicMenuData data,
  List<MenuSection> sections, {
  required bool bangla,
}) {
  final byId = {for (final c in data.categories) c.id: c};
  final seen = <String>{};
  final roots = <MenuRoot>[];
  for (final section in sections) {
    if (!seen.add(section.rootId)) continue;
    final category = byId[section.rootId];
    roots.add(
      MenuRoot(
        id: section.rootId,
        title: category == null
            ? section.title
            : categoryDisplayName(category, bangla: bangla),
        imageUrl: category?.imageUrl,
        icon: category?.icon,
      ),
    );
  }
  return roots;
}

/// Number of dishes across [sections].
int countItems(List<MenuSection> sections) =>
    sections.fold<int>(0, (sum, section) => sum + section.items.length);

// ---- highlights ----------------------------------------------------------------------

/// A row of dishes the restaurant wants to stand out.
class HighlightRail {
  const HighlightRail({required this.id, required this.titleEn, required this.titleBn, required this.items});

  final String id;
  final String titleEn;
  final String titleBn;
  final List<PublicItem> items;

  String title({required bool bangla}) => bangla ? titleBn : titleEn;
}

/// Featured, popular, new, chef's special and recommended rows. A row with no
/// dishes is left out. Dishes that can be ordered come first.
List<HighlightRail> buildHighlights(Iterable<PublicItem> items, {int limit = 12}) {
  List<PublicItem> pick(bool Function(PublicItem) test) {
    final matching = [for (final item in items) if (test(item)) item];
    final orderable = [for (final item in matching) if (item.availability.canOrder) item];
    final rest = [for (final item in matching) if (!item.availability.canOrder) item];
    return [...orderable, ...rest].take(limit).toList();
  }

  final rails = <HighlightRail>[
    HighlightRail(id: 'featured', titleEn: 'Featured', titleBn: 'বিশেষ', items: pick((i) => i.isFeatured)),
    HighlightRail(id: 'popular', titleEn: 'Popular', titleBn: 'জনপ্রিয়', items: pick((i) => i.hasLabel('popular'))),
    HighlightRail(id: 'new', titleEn: 'New', titleBn: 'নতুন', items: pick((i) => i.hasLabel('new'))),
    HighlightRail(
      id: 'chefs_special',
      titleEn: "Chef's special",
      titleBn: 'শেফের বিশেষ',
      items: pick((i) => i.hasLabel('chefs_special')),
    ),
    HighlightRail(
      id: 'recommended',
      titleEn: 'Recommended',
      titleBn: 'প্রস্তাবিত',
      items: pick((i) => i.hasLabel('recommended')),
    ),
  ];
  return [for (final rail in rails) if (rail.items.isNotEmpty) rail];
}

// ---- prices ------------------------------------------------------------------------------

/// What to print as a dish's price on its card.
class PriceDisplay {
  const PriceDisplay({required this.amount, this.original, this.from = false});

  /// Price to pay (discount applied).
  final double amount;

  /// Price before discount, shown struck through.
  final double? original;

  /// True when the price is the lowest of several sizes ("from 250").
  final bool from;

  bool get hasDiscount => original != null && original! > amount;
}

/// Price shown on a card. A dish whose size or portion choice is required
/// shows "from" the cheapest available choice, because that choice replaces
/// the dish price.
PriceDisplay priceDisplay(PublicItem item) {
  final base = item.hasDiscount ? item.discountPrice! : item.price;
  final baseOriginal = item.hasDiscount ? item.price : null;

  for (final group in item.optionGroups) {
    if (group.mode != OptionPriceMode.absolute || !group.isRequired) continue;
    final available = [for (final o in group.options) if (o.isAvailable) o];
    if (available.isEmpty) continue;
    PublicOption cheapest = available.first;
    for (final option in available) {
      if ((option.discountPrice ?? option.price) < (cheapest.discountPrice ?? cheapest.price)) {
        cheapest = option;
      }
    }
    final amount = cheapest.discountPrice ?? cheapest.price;
    final differs = available.any((o) => (o.discountPrice ?? o.price) != amount);
    return PriceDisplay(
      amount: amount,
      original: (cheapest.discountPrice != null && cheapest.discountPrice! < cheapest.price)
          ? cheapest.price
          : null,
      from: differs,
    );
  }
  return PriceDisplay(amount: base, original: baseOriginal);
}

/// Percentage off for a badge ("20% off"), or null without a real discount.
int? discountPercent(PublicItem item) {
  if (!item.hasDiscount || item.price <= 0) return null;
  final percent = ((item.price - item.discountPrice!) / item.price * 100).round();
  return percent >= 1 ? percent : null;
}

String formatPriceDisplay(PriceDisplay price, {required String currency, required bool bangla}) {
  final text = formatMoney(price.amount, currency: currency, bangla: bangla);
  return price.from ? (bangla ? '$text থেকে' : 'From $text') : text;
}

// ---- dish facts -------------------------------------------------------------------------

/// Short facts under the name: preparation time, spice and calories.
List<String> itemFacts(PublicItem item, {required bool bangla}) {
  return [
    if (item.prepTimeMin != null)
      bangla
          ? '${toBanglaDigits('${item.prepTimeMin}')} মিনিট'
          : '${item.prepTimeMin} min',
    if (item.spiceLevel != null && item.spiceLevel! > 0)
      spiceLevelName(item.spiceLevel, bangla: bangla),
    if (item.calories != null)
      bangla
          ? '${toBanglaDigits('${item.calories}')} ক্যালরি'
          : '${item.calories} kcal',
  ];
}

/// Label names on the dish, in the order the restaurant lists them. Labels the
/// app does not know are skipped.
List<String> labelNames(PublicItem item, {required bool bangla, int? limit}) {
  final names = [
    for (final id in item.labels)
      if (findMenuTag(menuLabels, id) != null) menuTagName(menuLabels, id, bangla: bangla),
  ];
  return limit == null ? names : names.take(limit).toList();
}

List<String> allergenNames(PublicItem item, {required bool bangla}) => [
  for (final id in item.allergens)
    if (findMenuTag(menuAllergens, id) != null) menuTagName(menuAllergens, id, bangla: bangla),
];

/// `Protein 12 g` lines for the nutrition values the dish has.
List<String> nutritionLines(PublicItem item, {required bool bangla}) {
  final lines = <String>[];
  for (final field in nutritionFields) {
    final value = item.nutrition[field.key];
    if (value == null) continue;
    final text = formatAmount(value, bangla: bangla);
    lines.add('${field.name(bangla: bangla)} $text ${field.unit}');
  }
  return lines;
}

/// Why a dish cannot be ordered now ("Sold out", "Not available right now"),
/// or null when it can.
String? availabilityLabel(PublicItem item, {required bool bangla}) {
  switch (item.availability) {
    case ItemAvailability.available:
      return null;
    case ItemAvailability.soldOut:
      return bangla ? 'শেষ' : 'Sold out';
    case ItemAvailability.scheduled:
      return bangla ? 'এখন নেই' : 'Not available now';
  }
}

/// When a dish that is off the menu right now is served, such as
/// "Mon, Tue, 6:00 PM - 10:00 PM". Empty when there are no windows.
List<String> scheduleLines(PublicItem item, {required bool bangla}) => [
  for (final schedule in item.schedules)
    scheduleSummary(
      weekdays: schedule.weekdays,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      startDate: schedule.startDate,
      endDate: schedule.endDate,
      bangla: bangla,
    ),
];

// ---- choices (variants and add-ons) -------------------------------------------------

/// Starting choices: the options the restaurant marked as default.
Map<String, Set<String>> initialSelections(PublicItem item) {
  final defaults = {
    for (final group in item.optionGroups)
      for (final option in group.options)
        if (option.isDefault) option.id,
  };
  return defaultSelections([for (final g in item.optionGroups) g.toPriced()], defaults);
}

/// The selection after the customer taps [optionId]. A single choice group
/// switches to the tapped option (tapping the chosen one clears it unless the
/// group is required). A multiple choice group toggles it and refuses to go
/// past its maximum. Unavailable options cannot be chosen.
Map<String, Set<String>> toggleOption(
  Map<String, Set<String>> selections,
  PublicOptionGroup group,
  String optionId,
) {
  PublicOption? option;
  for (final candidate in group.options) {
    if (candidate.id == optionId) option = candidate;
  }
  if (option == null || !option.isAvailable) return selections;

  final current = {...(selections[group.id] ?? const <String>{})};
  if (!group.multiple) {
    if (current.contains(optionId)) {
      if (group.isRequired) return selections;
      current.clear();
    } else {
      current
        ..clear()
        ..add(optionId);
    }
  } else if (current.contains(optionId)) {
    current.remove(optionId);
  } else {
    final max = group.maxSelect;
    if (max != null && current.length >= max) return selections;
    current.add(optionId);
  }
  final next = {...selections};
  if (current.isEmpty) {
    next.remove(group.id);
  } else {
    next[group.id] = current;
  }
  return next;
}

/// Price for the current choices. Uses the same rules as the dashboard.
PriceBreakdown priceFor(PublicItem item, Map<String, Set<String>> selections) {
  return computeItemPrice(
    basePrice: item.price,
    baseDiscountPrice: item.hasDiscount ? item.discountPrice : null,
    groups: [for (final g in item.optionGroups) g.toPriced()],
    selections: selections,
  );
}

/// "Choose 1", "Choose up to 3", "Pick 2 to 4", "Optional" under a group name.
String groupRuleText(PublicOptionGroup group, {required bool bangla}) {
  final priced = group.toPriced();
  final min = priced.effectiveMin;
  final max = priced.effectiveMax;
  String n(int value) => bangla ? toBanglaDigits('$value') : '$value';
  if (!group.multiple) {
    if (group.isRequired) return bangla ? 'একটি বেছে নিন' : 'Choose 1';
    return bangla ? 'ঐচ্ছিক, একটি বেছে নিন' : 'Optional, choose 1';
  }
  if (min > 0 && max != null && min != max) {
    return bangla ? '${n(min)} থেকে ${n(max)}টি বেছে নিন' : 'Choose ${n(min)} to ${n(max)}';
  }
  if (min > 0 && max != null && min == max) {
    return bangla ? '${n(min)}টি বেছে নিন' : 'Choose ${n(min)}';
  }
  if (min > 0) return bangla ? 'কমপক্ষে ${n(min)}টি বেছে নিন' : 'Choose at least ${n(min)}';
  if (max != null) return bangla ? 'ঐচ্ছিক, সর্বোচ্চ ${n(max)}টি' : 'Optional, up to ${n(max)}';
  return bangla ? 'ঐচ্ছিক' : 'Optional';
}

/// Price text next to an option: "+ ৳ 40" for an add-on, "৳ 450" for a size
/// that replaces the dish price, empty for a free add-on.
String optionPriceText(
  PublicOption option,
  PublicOptionGroup group, {
  required String currency,
  required bool bangla,
}) {
  final value = option.discountPrice != null && option.discountPrice! < option.price
      ? option.discountPrice!
      : option.price;
  if (group.mode == OptionPriceMode.absolute) {
    return formatMoney(value, currency: currency, bangla: bangla);
  }
  if (value <= 0) return '';
  return '+ ${formatMoney(value, currency: currency, bangla: bangla)}';
}

/// What is wrong with the choices of [group], in words for a customer.
String? selectionProblemText(
  SelectionIssue issue,
  PublicOptionGroup group, {
  required bool bangla,
}) {
  final name = groupDisplayName(group, bangla: bangla);
  switch (issue.problem) {
    case SelectionProblem.required:
      return bangla ? '$name বেছে নিন' : 'Choose an option for $name';
    case SelectionProblem.tooFew:
      return bangla ? '$name-এ আরও বেছে নিন' : 'Choose more for $name';
    case SelectionProblem.tooMany:
      return bangla ? '$name-এ অনেক বেশি বেছে নেওয়া হয়েছে' : 'Too many chosen for $name';
    case SelectionProblem.unavailable:
      return bangla ? '$name-এর একটি পছন্দ এখন নেই' : 'An option for $name is not available';
  }
}

// ---- opening status and hours -------------------------------------------------------

const List<String> _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _monthsBn = [
  'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

/// `Fri 1 Jan` / `শুক্র ১ জানু` for a `yyyy-MM-dd` date. The input is returned
/// as it is when it is not a date.
String formatShortDate(String? isoDate, {required bool bangla}) {
  final date = DateTime.tryParse(isoDate ?? '');
  if (date == null) return isoDate ?? '';
  final weekday = weekdayName(date.weekday, bangla: bangla, short: true);
  final day = bangla ? toBanglaDigits('${date.day}') : '${date.day}';
  final month = (bangla ? _monthsBn : _monthsEn)[date.month - 1];
  return '$weekday $day $month';
}

/// "Open now", "Closed" or "Temporarily closed".
String statusHeadline(BranchStatus status, {required bool bangla}) {
  if (status.isTemporarilyClosed) return bangla ? 'সাময়িকভাবে বন্ধ' : 'Temporarily closed';
  if (status.isOpen) return bangla ? 'এখন খোলা' : 'Open now';
  return bangla ? 'বন্ধ' : 'Closed';
}

/// The line under the headline: when it closes, when it opens, or the
/// restaurant's own message for a temporary closure.
String? statusDetail(PublicMenuData data, {required bool bangla, DateTime? now}) {
  final status = data.status;
  if (status.isTemporarilyClosed) {
    final message = pickText(
      data.branch.tempClosedMessageEn,
      data.branch.tempClosedMessageBn,
      bangla: bangla,
    );
    if (message != null) return message;
    final until = status.until;
    if (until != null) {
      final local = until.toLocal();
      final day = bangla ? toBanglaDigits('${local.day}') : '${local.day}';
      final month = (bangla ? _monthsBn : _monthsEn)[local.month - 1];
      return bangla ? '$day $month তারিখে আবার খুলবে' : 'Back on $day $month';
    }
    return bangla ? 'আমরা কিছুক্ষণ বন্ধ আছি' : 'We are closed for a while';
  }
  if (status.isOpen) {
    final closes = status.closesAt;
    if (closes == null) return null;
    final time = formatClock(closes, bangla: bangla);
    return bangla ? '$time পর্যন্ত খোলা' : 'Closes at $time';
  }
  final opens = status.opensAt;
  if (opens == null) return null;
  final time = formatClock(opens, bangla: bangla);
  return bangla ? 'আজ $time-এ খুলবে' : 'Opens today at $time';
}

/// A line of the weekly hours table.
class HoursLine {
  const HoursLine({required this.days, required this.times, required this.closed, required this.isToday});

  /// `Sat - Thu`.
  final String days;

  /// `10:00 AM - 10:00 PM` (several periods joined by commas) or `Closed`.
  final String times;
  final bool closed;
  final bool isToday;
}

bool _groupHasDay(DayGroup group, int weekday) {
  final start = weekOrderBangladesh.indexOf(group.firstWeekday);
  final end = weekOrderBangladesh.indexOf(group.lastWeekday);
  final at = weekOrderBangladesh.indexOf(weekday);
  if (start < 0 || end < 0 || at < 0) return false;
  return at >= start && at <= end;
}

/// The weekly opening hours as table lines, Saturday first. Days with the same
/// hours are joined. [todayWeekday] (ISO, 1 = Monday) marks today's line.
List<HoursLine> weeklyHoursLines(
  PublicMenuData data, {
  required bool bangla,
  int? todayWeekday,
}) {
  if (data.weeklyHours.isEmpty) return const [];
  final groups = summarizeWeek([
    for (final row in data.weeklyHours)
      HoursPeriod(
        weekday: row.weekday,
        open: row.open,
        close: row.close,
        label: pickText(row.labelEn, row.labelBn, bangla: bangla),
      ),
  ]);
  return [
    for (final group in groups)
      HoursLine(
        days: dayGroupLabel(group, bangla: bangla),
        times: group.isClosed
            ? (bangla ? 'বন্ধ' : 'Closed')
            : group.periods
                  .map(
                    (p) => p.label == null
                        ? formatPeriod(p.open, p.close, bangla: bangla)
                        : '${p.label} ${formatPeriod(p.open, p.close, bangla: bangla)}',
                  )
                  .join(', '),
        closed: group.isClosed,
        isToday: todayWeekday != null && _groupHasDay(group, todayWeekday),
      ),
  ];
}

/// Holidays and special days still to come, as table lines.
List<HoursLine> specialHoursLines(PublicMenuData data, {required bool bangla}) {
  return [
    for (final row in data.specialHours)
      HoursLine(
        days: [
          formatShortDate(row.date, bangla: bangla),
          if (row.endDate != null && row.endDate != row.date)
            formatShortDate(row.endDate, bangla: bangla),
        ].join(' - '),
        times: _specialTimes(row, bangla: bangla),
        closed: row.isClosed,
        isToday: false,
      ),
  ];
}

String _specialTimes(PublicSpecialHour row, {required bool bangla}) {
  final label = pickText(row.labelEn, row.labelBn, bangla: bangla);
  final String times;
  if (row.isClosed) {
    times = bangla ? 'বন্ধ' : 'Closed';
  } else if (row.open != null && row.close != null) {
    times = formatPeriod(row.open, row.close, bangla: bangla);
  } else {
    times = bangla ? 'খোলা' : 'Open';
  }
  return label == null ? times : '$label: $times';
}

// ---- contact ----------------------------------------------------------------------------

enum ContactKind { call, whatsapp, email, map, website, facebook, instagram, tiktok, youtube }

class ContactAction {
  const ContactAction({required this.kind, required this.label, required this.value, required this.url});

  final ContactKind kind;

  /// "Call", "Directions"...
  final String label;

  /// What to show next to the label (number, address, host).
  final String value;
  final String url;
}

String? _firstText(String? a, String? b) {
  for (final value in [a, b]) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

/// Address shown on the menu: the branch's own address and area, else the
/// restaurant's.
String? displayAddress(PublicMenuData data) {
  final branch = data.branch;
  final address = _firstText(branch.address, data.business.address);
  final area = branch.area?.trim();
  if (address == null) return (area == null || area.isEmpty) ? null : area;
  if (area == null || area.isEmpty || address.toLowerCase().contains(area.toLowerCase())) {
    return address;
  }
  return '$address, $area';
}

/// Ways to reach the restaurant, branch details first. Entries without a
/// usable value are left out.
List<ContactAction> contactActions(PublicMenuData data, {required bool bangla}) {
  final business = data.business;
  final branch = data.branch;
  final actions = <ContactAction>[];

  final phone = _firstText(branch.phone, business.phone);
  if (phone != null) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    actions.add(
      ContactAction(
        kind: ContactKind.call,
        label: bangla ? 'ফোন করুন' : 'Call',
        value: BdPhone.format(phone),
        url: 'tel:${BdPhone.toE164(phone) ?? digits}',
      ),
    );
  }

  final whatsapp = business.whatsappNumber?.trim();
  if (whatsapp != null && whatsapp.isNotEmpty) {
    final link = BdPhone.whatsappLink(whatsapp);
    final digits = BdPhone.asciiDigits(whatsapp).replaceAll(RegExp(r'[^0-9]'), '');
    final url = link ?? (digits.isEmpty ? null : 'https://wa.me/$digits');
    if (url != null) {
      actions.add(
        ContactAction(
          kind: ContactKind.whatsapp,
          label: 'WhatsApp',
          value: BdPhone.format(whatsapp),
          url: url,
        ),
      );
    }
  }

  final email = _firstText(branch.email, business.email);
  if (email != null) {
    actions.add(
      ContactAction(
        kind: ContactKind.email,
        label: bangla ? 'ইমেইল' : 'Email',
        value: email,
        url: 'mailto:$email',
      ),
    );
  }

  final map = _firstText(branch.mapUrl, business.mapUrl);
  final lat = branch.latitude;
  final lng = branch.longitude;
  final mapUrl = map ??
      ((lat != null && lng != null)
          ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
          : null);
  if (mapUrl != null) {
    actions.add(
      ContactAction(
        kind: ContactKind.map,
        label: bangla ? 'ম্যাপ' : 'Directions',
        value: displayAddress(data) ?? '',
        url: mapUrl,
      ),
    );
  }

  void social(ContactKind kind, String label, String? url) {
    final text = url?.trim();
    if (text == null || text.isEmpty) return;
    actions.add(ContactAction(kind: kind, label: label, value: _host(text), url: text));
  }

  social(ContactKind.website, bangla ? 'ওয়েবসাইট' : 'Website', business.websiteUrl);
  social(ContactKind.facebook, 'Facebook', business.facebookUrl);
  social(ContactKind.instagram, 'Instagram', business.instagramUrl);
  social(ContactKind.tiktok, 'TikTok', business.tiktokUrl);
  social(ContactKind.youtube, 'YouTube', business.youtubeUrl);
  return actions;
}

String _host(String url) {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  final host = uri?.host ?? '';
  return host.isEmpty ? url : host.replaceFirst(RegExp(r'^www\.'), '');
}

// ---- about ----------------------------------------------------------------------------------

/// A block of policy or notice text for the info sheet.
class InfoBlock {
  const InfoBlock(this.title, this.body);

  final String title;
  final String body;
}

/// Welcome note, about text and policies the restaurant filled in.
List<InfoBlock> infoBlocks(PublicBusiness business, {required bool bangla}) {
  final blocks = <InfoBlock>[];
  void add(String titleEn, String titleBn, String? en, String? bn) {
    final text = pickText(en, bn, bangla: bangla);
    if (text != null) blocks.add(InfoBlock(bangla ? titleBn : titleEn, text));
  }

  add('About us', 'আমাদের সম্পর্কে', business.descriptionEn, business.descriptionBn);
  add('Allergen notice', 'অ্যালার্জি বিজ্ঞপ্তি', business.allergenNoticeEn, business.allergenNoticeBn);
  add('Cancellation and refunds', 'বাতিল ও ফেরত', business.refundEn, business.refundBn);
  add('Terms', 'শর্তাবলী', business.termsEn, business.termsBn);
  return blocks;
}

/// Opening welcome line, if the restaurant wrote one.
String? welcomeText(PublicBusiness business, {required bool bangla}) =>
    pickText(business.welcomeEn, business.welcomeBn, bangla: bangla);

// ---- when there is no menu ----------------------------------------------------------

/// Title and explanation shown when the menu cannot be opened.
class ProblemText {
  const ProblemText(this.title, this.message);

  final String title;
  final String message;
}

/// What to tell a customer who scanned a code or followed a link that does not
/// lead to a menu.
ProblemText problemText(PublicMenuProblem problem, {required bool bangla}) {
  switch (problem) {
    case PublicMenuProblem.notFound:
      return bangla
          ? const ProblemText('মেনু পাওয়া যায়নি', 'লিংক বা QR কোডটি ঠিক নেই। রেস্টুরেন্টের কর্মীকে জানান।')
          : const ProblemText('Menu not found', 'This link or QR code does not lead to a menu. Please ask the staff.');
    case PublicMenuProblem.qrInactive:
      return bangla
          ? const ProblemText('এই QR কোড এখন চালু নেই', 'রেস্টুরেন্টের কর্মীর কাছ থেকে নতুন কোড বা মেনু চেয়ে নিন।')
          : const ProblemText('This QR code is not active', 'Please ask the staff for a current code or menu.');
    case PublicMenuProblem.tableInactive:
      return bangla
          ? const ProblemText('এই টেবিল এখন ব্যবহার হচ্ছে না', 'অনুগ্রহ করে কর্মীকে জানান।')
          : const ProblemText('This table is not available', 'Please let the staff know.');
    case PublicMenuProblem.branchInactive:
      return bangla
          ? const ProblemText('এই শাখার মেনু এখন নেই', 'অন্য শাখা বা পরে আবার চেষ্টা করুন।')
          : const ProblemText('This branch is not available', 'Try another branch or come back later.');
    case PublicMenuProblem.unpublished:
      return bangla
          ? const ProblemText('মেনু এখনো প্রকাশিত হয়নি', 'রেস্টুরেন্ট শীঘ্রই মেনু চালু করবে।')
          : const ProblemText('This menu is not published yet', 'The restaurant will open its menu soon.');
    case PublicMenuProblem.unknown:
      return bangla
          ? const ProblemText('মেনু খোলা গেল না', 'ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।')
          : const ProblemText('Could not open the menu', 'Check your connection and try again.');
  }
}

/// Weekday (ISO, 1 = Monday) of [now] in the restaurant's time zone. Only the
/// Bangladesh zone is converted; any other zone uses the device's own day.
int todayWeekdayFor(String timezone, DateTime now) {
  if (timezone == 'Asia/Dhaka') return now.toUtc().add(const Duration(hours: 6)).weekday;
  return now.weekday;
}
