import '../../core/logic/hours.dart';
import '../../core/logic/menu_catalog.dart';
import 'menu_models.dart';

/// Pure helpers for the dish availability windows.

enum SchedulePreset { breakfast, lunch, dinner, weekends, lateNight }

const Map<SchedulePreset, String> schedulePresetLabels = {
  SchedulePreset.breakfast: 'Breakfast',
  SchedulePreset.lunch: 'Lunch',
  SchedulePreset.dinner: 'Dinner',
  SchedulePreset.weekends: 'Weekends only',
  SchedulePreset.lateNight: 'Late night',
};

const int scheduleLabelMaxLength = 80;

/// A ready-made window. Weekends are Friday and Saturday, as in Bangladesh.
ItemSchedule presetWindow(SchedulePreset preset) {
  switch (preset) {
    case SchedulePreset.breakfast:
      return const ItemSchedule(startTime: '06:00', endTime: '11:00', label: 'Breakfast');
    case SchedulePreset.lunch:
      return const ItemSchedule(startTime: '12:00', endTime: '15:00', label: 'Lunch');
    case SchedulePreset.dinner:
      return const ItemSchedule(startTime: '18:00', endTime: '23:00', label: 'Dinner');
    case SchedulePreset.weekends:
      return const ItemSchedule(weekdays: [5, 6], label: 'Weekends');
    case SchedulePreset.lateNight:
      return const ItemSchedule(startTime: '22:00', endTime: '02:00', label: 'Late night');
  }
}

/// Weekdays as a sorted list of unique ISO days; the day is added or removed.
List<int> toggleWeekday(List<int> weekdays, int day) {
  final set = weekdays.toSet();
  if (!set.add(day)) set.remove(day);
  return set.toList()..sort();
}

/// An empty list or all seven days both mean "every day".
bool isEveryDay(List<int> weekdays) {
  final set = weekdays.toSet();
  return set.isEmpty || set.length == 7;
}

bool hasTimeRange(ItemSchedule window) =>
    window.startTime != null && window.endTime != null;

/// 18:00 - 02:00 runs past midnight.
bool isOvernight(ItemSchedule window) {
  final open = parseClock(window.startTime);
  final close = parseClock(window.endTime);
  if (open == null || close == null) return false;
  return open.totalMinutes > close.totalMinutes;
}

/// The database treats equal start and end as all day.
bool isAllDayByEqualTimes(ItemSchedule window) {
  final open = parseClock(window.startTime);
  final close = parseClock(window.endTime);
  if (open == null || close == null) return false;
  return open.totalMinutes == close.totalMinutes;
}

String windowSummary(ItemSchedule window, {bool bangla = false}) {
  return scheduleSummary(
    weekdays: window.weekdays,
    startTime: window.startTime,
    endTime: window.endTime,
    startDate: window.startDate,
    endDate: window.endDate,
    bangla: bangla,
  );
}

List<ScheduleWindow> toScheduleWindows(List<ItemSchedule> windows) => [
  for (final w in windows)
    ScheduleWindow(
      weekdays: w.weekdays,
      startTime: w.startTime,
      endTime: w.endTime,
      startDate: w.startDate,
      endDate: w.endDate,
    ),
];

/// True when a customer could order the dish right now by its windows.
bool availableByScheduleNow(List<ItemSchedule> windows, DateTime localNow) =>
    isWithinSchedules(toScheduleWindows(windows), localNow);

String _key(ItemSchedule w) {
  final days = (w.weekdays.toSet().toList()..sort()).join(',');
  final everyDay = isEveryDay(w.weekdays) ? 'all' : days;
  return '$everyDay|${w.startTime}|${w.endTime}|${w.startDate}|${w.endDate}';
}

/// Plain English problems, empty when the windows can be saved.
List<String> validateSchedules(List<ItemSchedule> windows) {
  final errors = <String>[];
  final seen = <String, int>{};
  for (var i = 0; i < windows.length; i++) {
    final w = windows[i];
    final name = 'Window ${i + 1}';
    if ((w.label ?? '').trim().length > scheduleLabelMaxLength) {
      errors.add('$name: the label must be $scheduleLabelMaxLength characters or fewer.');
    }
    if (w.weekdays.any((d) => d < 1 || d > 7)) {
      errors.add('$name: a weekday is not valid.');
    }
    final hasStart = w.startTime != null;
    final hasEnd = w.endTime != null;
    if (hasStart != hasEnd) {
      errors.add('$name: set both a start time and an end time, or choose all day.');
    }
    if ((hasStart && parseClock(w.startTime) == null) ||
        (hasEnd && parseClock(w.endTime) == null)) {
      errors.add('$name: a time is not valid.');
    }
    final start = w.startDate;
    final end = w.endDate;
    if (start != null && end != null && start.compareTo(end) > 0) {
      errors.add('$name: the first date is after the last date.');
    }
    final key = _key(w);
    final first = seen[key];
    if (first != null) {
      errors.add('$name is the same as window $first.');
    } else {
      seen[key] = i + 1;
    }
  }
  return errors;
}
