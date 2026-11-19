import '../../core/logic/hours.dart';
import '../../core/utils/json_utils.dart';

// Pure logic behind the opening hours editor. No Flutter imports, so it is
// unit tested.

/// One service period in the editor. Times are `HH:mm`.
class DraftPeriod {
  const DraftPeriod({
    required this.open,
    required this.close,
    this.labelEn = '',
    this.labelBn = '',
  });

  final String open;
  final String close;
  final String labelEn;
  final String labelBn;

  DraftPeriod copyWith({
    String? open,
    String? close,
    String? labelEn,
    String? labelBn,
  }) {
    return DraftPeriod(
      open: open ?? this.open,
      close: close ?? this.close,
      labelEn: labelEn ?? this.labelEn,
      labelBn: labelBn ?? this.labelBn,
    );
  }

  /// Closing time is at or before opening time, so the period ends after
  /// midnight.
  bool get isOvernight {
    final o = parseClock(open);
    final c = parseClock(close);
    if (o == null || c == null) return false;
    return c.totalMinutes <= o.totalMinutes;
  }

  @override
  bool operator ==(Object other) =>
      other is DraftPeriod &&
      other.open == open &&
      other.close == close &&
      other.labelEn == labelEn &&
      other.labelBn == labelBn;

  @override
  int get hashCode => Object.hash(open, close, labelEn, labelBn);
}

/// The default period offered when a closed day is switched to open.
const DraftPeriod defaultPeriod = DraftPeriod(open: '10:00', close: '22:00');

/// A week: ISO weekday (1 = Monday ... 7 = Sunday) to its periods. A missing
/// or empty entry means closed.
typedef WeekDraft = Map<int, List<DraftPeriod>>;

WeekDraft emptyWeek() => {
  for (final d in weekOrderBangladesh) d: <DraftPeriod>[],
};

WeekDraft copyWeek(WeekDraft week) => {
  for (final d in weekOrderBangladesh)
    d: List<DraftPeriod>.of(week[d] ?? const <DraftPeriod>[]),
};

/// Sorts periods by opening time.
List<DraftPeriod> sortPeriods(List<DraftPeriod> periods) {
  final sorted = List<DraftPeriod>.of(periods);
  sorted.sort((a, b) => a.open.compareTo(b.open));
  return sorted;
}

/// Every day gets [period].
WeekDraft presetEveryDay([DraftPeriod period = defaultPeriod]) => {
  for (final d in weekOrderBangladesh) d: [period],
};

/// Every day gets [period] except [closedDays], which are closed.
WeekDraft presetClosedOn(
  Set<int> closedDays, [
  DraftPeriod period = defaultPeriod,
]) => {
  for (final d in weekOrderBangladesh)
    d: closedDays.contains(d) ? <DraftPeriod>[] : [period],
};

/// Copies the periods of [from] onto each day in [targets].
WeekDraft copyDayTo(WeekDraft week, int from, Iterable<int> targets) {
  final next = copyWeek(week);
  final source = week[from] ?? const <DraftPeriod>[];
  for (final day in targets) {
    if (day == from) continue;
    next[day] = List<DraftPeriod>.of(source);
  }
  return next;
}

int _minutes(String value) => parseClock(value)?.totalMinutes ?? -1;

/// True when two periods on the same day share any time. An overnight period
/// is treated as running to the end of the day plus its early-morning tail
/// (only the part on this day is compared).
bool periodsOverlap(DraftPeriod a, DraftPeriod b) {
  final aStart = _minutes(a.open);
  final bStart = _minutes(b.open);
  if (aStart < 0 || bStart < 0) return false;
  final aEnd = a.isOvernight ? 1440 : _minutes(a.close);
  final bEnd = b.isOvernight ? 1440 : _minutes(b.close);
  return aStart < bEnd && bStart < aEnd;
}

/// Problems with one day's periods, in plain language. Empty means fine.
List<String> validateDay(List<DraftPeriod> periods) {
  final problems = <String>[];
  for (final p in periods) {
    final o = parseClock(p.open);
    final c = parseClock(p.close);
    if (o == null || c == null) {
      problems.add('Choose an opening and closing time.');
    } else if (o.totalMinutes == c.totalMinutes) {
      problems.add('Opening and closing time cannot be the same.');
    }
  }
  final sorted = sortPeriods(periods);
  for (var i = 1; i < sorted.length; i++) {
    if (periodsOverlap(sorted[i - 1], sorted[i])) {
      problems.add('Periods overlap. Change one of the times.');
      break;
    }
  }
  return problems;
}

/// The first problem in the week, with the day name, or null when valid.
String? validateWeek(WeekDraft week) {
  for (final day in weekOrderBangladesh) {
    final problems = validateDay(week[day] ?? const <DraftPeriod>[]);
    if (problems.isNotEmpty) return '${weekdayName(day)}: ${problems.first}';
  }
  return null;
}

/// True when no day has any period.
bool weekIsEmpty(WeekDraft week) =>
    week.values.every((periods) => periods.isEmpty);

/// A row of `branch_hours`.
class HoursRow {
  const HoursRow({
    required this.id,
    required this.branchId,
    this.weekday,
    this.specialDate,
    this.specialDateEnd,
    this.isClosed = false,
    this.openTime,
    this.closeTime,
    this.labelEn,
    this.labelBn,
  });

  final String id;
  final String branchId;
  final int? weekday;
  final DateTime? specialDate;
  final DateTime? specialDateEnd;
  final bool isClosed;

  /// `HH:mm`
  final String? openTime;
  final String? closeTime;
  final String? labelEn;
  final String? labelBn;

  bool get isWeekly => weekday != null;

  factory HoursRow.fromJson(Map<String, dynamic> j) {
    String? time(String key) {
      final parsed = parseClock(j.str(key));
      return parsed == null ? null : clockToDb(parsed);
    }

    return HoursRow(
      id: j.requireStr('id'),
      branchId: j.requireStr('branch_id'),
      weekday: j.intOrNull('weekday'),
      specialDate: parseIsoDate(j.str('special_date')),
      specialDateEnd: parseIsoDate(j.str('special_date_end')),
      isClosed: j.boolean('is_closed'),
      openTime: time('open_time'),
      closeTime: time('close_time'),
      labelEn: j.str('label_en'),
      labelBn: j.str('label_bn'),
    );
  }

  DraftPeriod? toPeriod() {
    if (openTime == null || closeTime == null) return null;
    return DraftPeriod(
      open: openTime!,
      close: closeTime!,
      labelEn: labelEn ?? '',
      labelBn: labelBn ?? '',
    );
  }
}

/// Builds the editable week from stored rows.
WeekDraft weekFromRows(Iterable<HoursRow> rows) {
  final week = emptyWeek();
  for (final row in rows) {
    final day = row.weekday;
    final period = row.toPeriod();
    if (day == null || period == null) continue;
    week[day]?.add(period);
  }
  for (final day in weekOrderBangladesh) {
    week[day] = sortPeriods(week[day] ?? const <DraftPeriod>[]);
  }
  return week;
}

/// A special day (or range) as the person sees it: one closed entry, or one
/// custom-hours entry holding all its periods.
class SpecialDay {
  const SpecialDay({
    required this.start,
    this.end,
    required this.isClosed,
    this.periods = const <DraftPeriod>[],
    required this.rowIds,
    this.noteEn,
    this.noteBn,
  });

  final DateTime start;
  final DateTime? end;
  final bool isClosed;
  final List<DraftPeriod> periods;
  final List<String> rowIds;

  /// A short reason such as "Eid holiday", stored as the row label.
  final String? noteEn;
  final String? noteBn;

  DateTime get lastDay => end ?? start;
}

/// Groups special-day rows (same start, end and kind) into [SpecialDay]s,
/// soonest first.
List<SpecialDay> specialDaysFromRows(Iterable<HoursRow> rows) {
  final groups = <String, List<HoursRow>>{};
  for (final row in rows) {
    final start = row.specialDate;
    if (start == null) continue;
    final key =
        '${isoDate(start)}|${row.specialDateEnd == null ? '' : isoDate(row.specialDateEnd!)}|${row.isClosed}';
    groups.putIfAbsent(key, () => <HoursRow>[]).add(row);
  }
  final result = <SpecialDay>[];
  for (final group in groups.values) {
    final first = group.first;
    final periods = <DraftPeriod>[];
    for (final row in group) {
      final period = row.toPeriod();
      if (period != null) periods.add(period);
    }
    String? note(String? Function(HoursRow) pick) {
      for (final row in group) {
        final value = pick(row);
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    result.add(
      SpecialDay(
        noteEn: note((r) => r.labelEn),
        noteBn: note((r) => r.labelBn),
        start: first.specialDate!,
        end: first.specialDateEnd,
        isClosed: first.isClosed,
        periods: sortPeriods(periods),
        rowIds: [for (final r in group) r.id],
      ),
    );
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

/// True when the special day is entirely before [today].
bool specialDayIsPast(SpecialDay day, DateTime today) {
  final last = DateTime(day.lastDay.year, day.lastDay.month, day.lastDay.day);
  final now = DateTime(today.year, today.month, today.day);
  return last.isBefore(now);
}

// ---- dates ----------------------------------------------------------------

const List<String> _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `2026-12-25`
String isoDate(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

DateTime? parseIsoDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// `Fri, 25 Dec 2026`
String formatDate(DateTime date) {
  final day = weekdayName(date.weekday, short: true);
  return '$day, ${date.day} ${_monthShort[date.month - 1]} ${date.year}';
}

/// `Fri, 25 Dec 2026` or `Thu, 24 Dec 2026 to Sat, 26 Dec 2026`
String formatDateRange(DateTime start, DateTime? end) {
  if (end == null || isoDate(end) == isoDate(start)) return formatDate(start);
  return '${formatDate(start)} to ${formatDate(end)}';
}
