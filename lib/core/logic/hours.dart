import 'money.dart';

/// Days in the order Bangladeshi menus list them: Saturday first.
/// Values are ISO weekdays (1 = Monday ... 7 = Sunday).
const List<int> weekOrderBangladesh = [6, 7, 1, 2, 3, 4, 5];

const List<String> _weekdayEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _weekdayEnShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _weekdayBn = [
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
  'রবিবার',
];
const List<String> _weekdayBnShort = [
  'সোম',
  'মঙ্গল',
  'বুধ',
  'বৃহস্পতি',
  'শুক্র',
  'শনি',
  'রবি',
];

/// Name of an ISO weekday (1 = Monday ... 7 = Sunday).
String weekdayName(int isoWeekday, {bool bangla = false, bool short = false}) {
  final index = (isoWeekday - 1) % 7;
  if (bangla) return short ? _weekdayBnShort[index] : _weekdayBn[index];
  return short ? _weekdayEnShort[index] : _weekdayEn[index];
}

class ClockTime {
  const ClockTime(this.hour, this.minute);
  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Parses `HH:mm` or `HH:mm:ss`. Returns null for anything else.
ClockTime? parseClock(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return ClockTime(hour, minute);
}

/// `HH:mm` (zero padded) for storing or sending to the database.
String clockToDb(ClockTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _banglaDayPart(int hour) {
  if (hour >= 4 && hour < 6) return 'ভোর';
  if (hour >= 6 && hour < 12) return 'সকাল';
  if (hour >= 12 && hour < 16) return 'দুপুর';
  if (hour >= 16 && hour < 18) return 'বিকেল';
  if (hour >= 18 && hour < 20) return 'সন্ধ্যা';
  return 'রাত';
}

/// Friendly time text.
///   English: `6:00 PM`      Bangla: `সন্ধ্যা ৬:০০`
String formatClock(String? value, {bool bangla = false}) {
  final time = parseClock(value);
  if (time == null) return value ?? '';
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  if (bangla) {
    return '${_banglaDayPart(time.hour)} ${toBanglaDigits('$hour12:$minute')}';
  }
  return '$hour12:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// `12:00 PM - 3:00 PM` (a plain hyphen, no special characters).
String formatPeriod(String? open, String? close, {bool bangla = false}) {
  return '${formatClock(open, bangla: bangla)} - ${formatClock(close, bangla: bangla)}';
}

/// One opening period on a weekday.
class HoursPeriod {
  const HoursPeriod({
    required this.weekday,
    required this.open,
    required this.close,
    this.label,
  });

  final int weekday;
  final String open;
  final String close;
  final String? label;
}

/// A run of consecutive days that share identical periods.
class DayGroup {
  const DayGroup({
    required this.firstWeekday,
    required this.lastWeekday,
    required this.periods,
  });

  final int firstWeekday;
  final int lastWeekday;

  /// Empty means closed.
  final List<HoursPeriod> periods;

  bool get isClosed => periods.isEmpty;
  bool get isSingleDay => firstWeekday == lastWeekday;
}

String _signature(List<HoursPeriod> periods) =>
    periods.map((p) => '${p.open}|${p.close}').join(';');

/// Groups the week (Saturday first) into runs of days with identical hours,
/// e.g. "Sat - Thu: 10:00 AM - 10:00 PM" and "Fri: Closed".
List<DayGroup> summarizeWeek(List<HoursPeriod> all) {
  final byDay = <int, List<HoursPeriod>>{
    for (final d in weekOrderBangladesh) d: <HoursPeriod>[],
  };
  for (final p in all) {
    byDay[p.weekday]?.add(p);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.open.compareTo(b.open));
  }

  final groups = <DayGroup>[];
  int? start;
  int? previous;
  String? currentSignature;
  void flush() {
    final first = start;
    final last = previous;
    if (first == null || last == null) return;
    groups.add(
      DayGroup(
        firstWeekday: first,
        lastWeekday: last,
        periods: byDay[first] ?? const <HoursPeriod>[],
      ),
    );
  }

  for (final day in weekOrderBangladesh) {
    final signature = _signature(byDay[day]!);
    if (start != null && signature == currentSignature) {
      previous = day;
    } else {
      flush();
      start = day;
      previous = day;
      currentSignature = signature;
    }
  }
  flush();
  return groups;
}

/// `Sat - Thu`, `Fri`, `শনি - বৃহস্পতি`
String dayGroupLabel(DayGroup group, {bool bangla = false}) {
  final first = weekdayName(group.firstWeekday, bangla: bangla, short: true);
  if (group.isSingleDay) return first;
  final last = weekdayName(group.lastWeekday, bangla: bangla, short: true);
  return '$first - $last';
}
