import 'hours.dart';

/// Fixed vocabularies used by menu items. The ids match the check constraints
/// in the database, so a value picked here is always accepted there.

class MenuTag {
  const MenuTag(this.id, this.en, this.bn);
  final String id;
  final String en;
  final String bn;

  String name({bool bangla = false}) => bangla ? bn : en;
}

/// Item labels (`menu_items.labels`).
const List<MenuTag> menuLabels = [
  MenuTag('vegetarian', 'Vegetarian', 'নিরামিষ'),
  MenuTag('vegan', 'Vegan', 'ভেগান'),
  MenuTag('spicy', 'Spicy', 'ঝাল'),
  MenuTag('popular', 'Popular', 'জনপ্রিয়'),
  MenuTag('chefs_special', "Chef's special", 'শেফের বিশেষ'),
  MenuTag('new', 'New', 'নতুন'),
  MenuTag('recommended', 'Recommended', 'প্রস্তাবিত'),
  MenuTag('halal', 'Halal', 'হালাল'),
  MenuTag('gluten_free', 'Gluten free', 'গ্লুটেন মুক্ত'),
  MenuTag('dairy_free', 'Dairy free', 'দুগ্ধমুক্ত'),
];

/// Allergens (`menu_items.allergens`).
const List<MenuTag> menuAllergens = [
  MenuTag('milk', 'Milk', 'দুধ'),
  MenuTag('eggs', 'Eggs', 'ডিম'),
  MenuTag('peanuts', 'Peanuts', 'চীনাবাদাম'),
  MenuTag('tree_nuts', 'Tree nuts', 'বাদাম'),
  MenuTag('gluten', 'Gluten', 'গ্লুটেন'),
  MenuTag('soy', 'Soy', 'সয়া'),
  MenuTag('fish', 'Fish', 'মাছ'),
  MenuTag('shellfish', 'Shellfish', 'চিংড়ি ও শেলফিশ'),
  MenuTag('sesame', 'Sesame', 'তিল'),
  MenuTag('mustard', 'Mustard', 'সরিষা'),
];

/// Spice levels (`menu_items.spice_level`, 0 to 3).
const List<MenuTag> menuSpiceLevels = [
  MenuTag('0', 'Not spicy', 'ঝাল নেই'),
  MenuTag('1', 'Mild', 'হালকা ঝাল'),
  MenuTag('2', 'Medium', 'মাঝারি ঝাল'),
  MenuTag('3', 'Hot', 'বেশি ঝাল'),
];

/// Keys allowed inside `menu_items.nutrition`.
class NutritionField {
  const NutritionField(this.key, this.en, this.bn, this.unit);
  final String key;
  final String en;
  final String bn;
  final String unit;

  String name({bool bangla = false}) => bangla ? bn : en;
}

const List<NutritionField> nutritionFields = [
  NutritionField('protein_g', 'Protein', 'প্রোটিন', 'g'),
  NutritionField('carbs_g', 'Carbohydrates', 'শর্করা', 'g'),
  NutritionField('fat_g', 'Fat', 'চর্বি', 'g'),
  NutritionField('sugar_g', 'Sugar', 'চিনি', 'g'),
  NutritionField('fiber_g', 'Fibre', 'আঁশ', 'g'),
  NutritionField('sodium_mg', 'Sodium', 'সোডিয়াম', 'mg'),
];

MenuTag? findMenuTag(List<MenuTag> list, String id) {
  for (final tag in list) {
    if (tag.id == id) return tag;
  }
  return null;
}

/// Display name for a stored id; unknown ids are returned as they are.
String menuTagName(List<MenuTag> list, String id, {bool bangla = false}) {
  final tag = findMenuTag(list, id);
  return tag == null ? id : tag.name(bangla: bangla);
}

String spiceLevelName(int? level, {bool bangla = false}) {
  if (level == null) return '';
  return menuTagName(menuSpiceLevels, level.toString(), bangla: bangla);
}

/// Human readable summary of one availability window, for example
/// `Mon, Tue  18:00 - 22:00` or `Every day  all day`.
///
/// [weekdays] are ISO weekdays (1 = Monday ... 7 = Sunday); empty means every
/// day. Times are `HH:mm` strings or null for all day. Dates are `yyyy-MM-dd`.
String scheduleSummary({
  required List<int> weekdays,
  String? startTime,
  String? endTime,
  String? startDate,
  String? endDate,
  bool bangla = false,
}) {
  final days = _daysText(weekdays, bangla: bangla);
  final hasTime = startTime != null && endTime != null;
  final time = hasTime
      ? formatPeriod(startTime, endTime, bangla: bangla)
      : (bangla ? 'সারাদিন' : 'All day');

  final buffer = StringBuffer('$days, $time');
  if (startDate != null && endDate != null) {
    buffer.write(bangla ? ' ($startDate থেকে $endDate)' : ' ($startDate to $endDate)');
  } else if (startDate != null) {
    buffer.write(bangla ? ' ($startDate থেকে)' : ' (from $startDate)');
  } else if (endDate != null) {
    buffer.write(bangla ? ' ($endDate পর্যন্ত)' : ' (until $endDate)');
  }
  return buffer.toString();
}

String _daysText(List<int> weekdays, {required bool bangla}) {
  final unique = weekdays.toSet().toList();
  if (unique.isEmpty || unique.length == 7) {
    return bangla ? 'প্রতিদিন' : 'Every day';
  }
  final ordered = [
    for (final day in weekOrderBangladesh)
      if (unique.contains(day)) day,
  ];
  return ordered
      .map((day) => weekdayName(day, bangla: bangla, short: true))
      .join(', ');
}

/// True when [now] is inside the window. Mirrors the database function
/// `item_in_schedule` so the dashboard preview agrees with the public menu.
/// An item with no schedules at all is always available.
bool isWithinSchedules(
  List<ScheduleWindow> windows,
  DateTime localNow,
) {
  if (windows.isEmpty) return true;
  return windows.any((window) => window.contains(localNow));
}

/// One availability window in plain Dart (no database types).
class ScheduleWindow {
  const ScheduleWindow({
    this.weekdays = const [],
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
  });

  final List<int> weekdays;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;

  bool contains(DateTime localNow) {
    if (weekdays.isNotEmpty && !weekdays.contains(localNow.weekday)) {
      return false;
    }
    final today = _dateText(localNow);
    if (startDate != null && today.compareTo(startDate!) < 0) return false;
    if (endDate != null && today.compareTo(endDate!) > 0) return false;

    final open = parseClock(startTime);
    final close = parseClock(endTime);
    if (open == null || close == null) return true;
    final minutes = localNow.hour * 60 + localNow.minute;
    if (open.totalMinutes < close.totalMinutes) {
      return minutes >= open.totalMinutes && minutes < close.totalMinutes;
    }
    // A window such as 18:00 - 02:00 runs past midnight (same as the database).
    return minutes >= open.totalMinutes || minutes < close.totalMinutes;
  }
}

String _dateText(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// `yyyy-MM-dd` for storing in a `date` column.
String dateToDb(DateTime date) => _dateText(date);
