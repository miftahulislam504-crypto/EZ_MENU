import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/branches/hours_editing.dart';

void main() {
  group('periodsOverlap', () {
    test('separate periods do not overlap', () {
      expect(
        periodsOverlap(
          const DraftPeriod(open: '12:00', close: '15:00'),
          const DraftPeriod(open: '18:00', close: '23:00'),
        ),
        isFalse,
      );
    });

    test('touching periods do not overlap', () {
      expect(
        periodsOverlap(
          const DraftPeriod(open: '12:00', close: '15:00'),
          const DraftPeriod(open: '15:00', close: '20:00'),
        ),
        isFalse,
      );
    });

    test('nested periods overlap', () {
      expect(
        periodsOverlap(
          const DraftPeriod(open: '10:00', close: '22:00'),
          const DraftPeriod(open: '12:00', close: '14:00'),
        ),
        isTrue,
      );
    });

    test('overnight period overlaps an evening period', () {
      expect(
        periodsOverlap(
          const DraftPeriod(open: '20:00', close: '02:00'),
          const DraftPeriod(open: '22:00', close: '23:30'),
        ),
        isTrue,
      );
    });
  });

  group('validateDay', () {
    test('accepts lunch and dinner', () {
      expect(
        validateDay(const [
          DraftPeriod(open: '12:00', close: '15:00', labelEn: 'Lunch'),
          DraftPeriod(open: '18:00', close: '23:00', labelEn: 'Dinner'),
        ]),
        isEmpty,
      );
    });

    test('rejects equal open and close', () {
      expect(
        validateDay(const [DraftPeriod(open: '10:00', close: '10:00')]),
        isNotEmpty,
      );
    });

    test('rejects overlap regardless of input order', () {
      expect(
        validateDay(const [
          DraftPeriod(open: '18:00', close: '23:00'),
          DraftPeriod(open: '12:00', close: '19:00'),
        ]),
        isNotEmpty,
      );
    });

    test('rejects unreadable times', () {
      expect(
        validateDay(const [DraftPeriod(open: '', close: '10:00')]),
        isNotEmpty,
      );
    });

    test('a day with no periods is valid (closed)', () {
      expect(validateDay(const []), isEmpty);
    });
  });

  group('week helpers', () {
    test('presetEveryDay fills all seven days', () {
      final week = presetEveryDay();
      expect(week.length, 7);
      expect(week.values.every((p) => p.length == 1), isTrue);
    });

    test('presetClosedOn leaves the chosen days empty', () {
      final week = presetClosedOn({5});
      expect(week[5], isEmpty);
      expect(week[6], hasLength(1));
      expect(week[1], hasLength(1));
    });

    test('copyDayTo copies periods without touching the source', () {
      final week = emptyWeek();
      week[6] = [
        const DraftPeriod(open: '09:00', close: '14:00'),
        const DraftPeriod(open: '17:00', close: '22:00'),
      ];
      final copied = copyDayTo(week, 6, [7, 1]);
      expect(copied[7], hasLength(2));
      expect(copied[1], hasLength(2));
      expect(copied[2], isEmpty);
      expect(week[7], isEmpty);
      copied[7]!.add(const DraftPeriod(open: '01:00', close: '02:00'));
      expect(copied[1], hasLength(2));
    });

    test('validateWeek names the day with the problem', () {
      final week = emptyWeek();
      week[3] = [
        const DraftPeriod(open: '10:00', close: '12:00'),
        const DraftPeriod(open: '11:00', close: '13:00'),
      ];
      final message = validateWeek(week);
      expect(message, isNotNull);
      expect(message!.startsWith('Wednesday'), isTrue);
    });

    test('weekIsEmpty', () {
      expect(weekIsEmpty(emptyWeek()), isTrue);
      expect(weekIsEmpty(presetEveryDay()), isFalse);
    });
  });

  group('rows', () {
    test('weekFromRows groups and sorts by day and opening time', () {
      final rows = [
        HoursRow.fromJson({
          'id': 'a',
          'branch_id': 'b',
          'weekday': 6,
          'open_time': '18:00:00',
          'close_time': '23:00:00',
        }),
        HoursRow.fromJson({
          'id': 'c',
          'branch_id': 'b',
          'weekday': 6,
          'open_time': '12:00:00',
          'close_time': '15:00:00',
          'label_en': 'Lunch',
        }),
        HoursRow.fromJson({
          'id': 'd',
          'branch_id': 'b',
          'special_date': '2026-12-25',
          'is_closed': true,
        }),
      ];
      final week = weekFromRows(rows);
      expect(week[6]!.map((p) => p.open).toList(), ['12:00', '18:00']);
      expect(week[6]!.first.labelEn, 'Lunch');
      expect(week[5], isEmpty);
    });

    test('specialDaysFromRows groups custom periods of one day', () {
      final rows = [
        HoursRow.fromJson({
          'id': '1',
          'branch_id': 'b',
          'special_date': '2026-12-31',
          'open_time': '10:00:00',
          'close_time': '14:00:00',
        }),
        HoursRow.fromJson({
          'id': '2',
          'branch_id': 'b',
          'special_date': '2026-12-31',
          'open_time': '18:00:00',
          'close_time': '23:59:00',
        }),
        HoursRow.fromJson({
          'id': '3',
          'branch_id': 'b',
          'special_date': '2026-12-25',
          'special_date_end': '2026-12-26',
          'is_closed': true,
        }),
      ];
      final days = specialDaysFromRows(rows);
      expect(days, hasLength(2));
      expect(days.first.isClosed, isTrue);
      expect(days.first.rowIds, ['3']);
      expect(days.last.periods, hasLength(2));
      expect(days.last.rowIds, ['1', '2']);
    });

    test('specialDayIsPast', () {
      final day = SpecialDay(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 3),
        isClosed: true,
        rowIds: const ['x'],
      );
      expect(specialDayIsPast(day, DateTime(2026, 11, 4)), isTrue);
      expect(specialDayIsPast(day, DateTime(2026, 11, 3, 22)), isFalse);
    });
  });

  group('dates', () {
    test('iso round trip', () {
      final d = DateTime(2026, 3, 7);
      expect(isoDate(d), '2026-03-07');
      expect(parseIsoDate('2026-03-07'), d);
      expect(parseIsoDate('bad'), isNull);
    });

    test('formatDate and range', () {
      expect(formatDate(DateTime(2026, 12, 25)), 'Fri, 25 Dec 2026');
      expect(
        formatDateRange(DateTime(2026, 12, 25), DateTime(2026, 12, 25)),
        'Fri, 25 Dec 2026',
      );
      expect(
        formatDateRange(DateTime(2026, 12, 24), DateTime(2026, 12, 26)),
        'Thu, 24 Dec 2026 to Sat, 26 Dec 2026',
      );
    });
  });
}
