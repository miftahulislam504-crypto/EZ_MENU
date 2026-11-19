import 'package:ez_menu/core/logic/hours.dart';
import 'package:flutter_test/flutter_test.dart';

HoursPeriod _p(int day, String open, String close) =>
    HoursPeriod(weekday: day, open: open, close: close);

void main() {
  group('parseClock', () {
    test('accepts HH:mm and HH:mm:ss', () {
      expect(parseClock('18:00:00'), const ClockTime(18, 0));
      expect(parseClock('08:30'), const ClockTime(8, 30));
      expect(parseClock('9:05'), const ClockTime(9, 5));
    });
    test('rejects invalid values', () {
      expect(parseClock(null), isNull);
      expect(parseClock(''), isNull);
      expect(parseClock('24:00'), isNull);
      expect(parseClock('12:60'), isNull);
      expect(parseClock('noon'), isNull);
    });
    test('clockToDb pads', () {
      expect(clockToDb(const ClockTime(9, 5)), '09:05');
    });
  });

  group('formatClock', () {
    test('English 12 hour clock', () {
      expect(formatClock('18:00:00'), '6:00 PM');
      expect(formatClock('00:00'), '12:00 AM');
      expect(formatClock('12:30'), '12:30 PM');
      expect(formatClock('09:05:00'), '9:05 AM');
    });
    test('Bangla clock names the part of the day', () {
      expect(formatClock('05:00', bangla: true), 'ভোর ৫:০০');
      expect(formatClock('09:00', bangla: true), 'সকাল ৯:০০');
      expect(formatClock('13:15', bangla: true), 'দুপুর ১:১৫');
      expect(formatClock('16:45', bangla: true), 'বিকেল ৪:৪৫');
      expect(formatClock('18:00', bangla: true), 'সন্ধ্যা ৬:০০');
      expect(formatClock('22:30', bangla: true), 'রাত ১০:৩০');
      expect(formatClock('00:00', bangla: true), 'রাত ১২:০০');
    });
    test('unparseable text is returned unchanged', () {
      expect(formatClock('soon'), 'soon');
      expect(formatClock(null), '');
    });
    test('formatPeriod', () {
      expect(formatPeriod('12:00', '15:00'), '12:00 PM - 3:00 PM');
    });
  });

  group('weekdayName', () {
    test('English and Bangla', () {
      expect(weekdayName(1), 'Monday');
      expect(weekdayName(7, short: true), 'Sun');
      expect(weekdayName(6, bangla: true), 'শনিবার');
      expect(weekdayName(1, bangla: true, short: true), 'সোম');
    });
  });

  group('summarizeWeek', () {
    test('groups consecutive days with the same hours, Saturday first', () {
      final week = [
        for (final d in [6, 7, 1, 2, 3, 4]) _p(d, '10:00', '22:00'),
      ];
      final groups = summarizeWeek(week);
      expect(groups, hasLength(2));
      expect(groups[0].firstWeekday, 6);
      expect(groups[0].lastWeekday, 4);
      expect(groups[0].periods, hasLength(1));
      expect(groups[1].firstWeekday, 5);
      expect(groups[1].isClosed, isTrue);
      expect(dayGroupLabel(groups[0]), 'Sat - Thu');
      expect(dayGroupLabel(groups[1]), 'Fri');
      expect(dayGroupLabel(groups[0], bangla: true), 'শনি - বৃহস্পতি');
    });

    test('split days with several periods form their own group', () {
      final week = [
        _p(6, '12:00', '15:00'),
        _p(6, '18:00', '23:00'),
        _p(7, '18:00', '23:00'),
        _p(7, '12:00', '15:00'),
        for (final d in [1, 2, 3, 4]) _p(d, '10:00', '22:00'),
      ];
      final groups = summarizeWeek(week);
      expect(groups.map((g) => [g.firstWeekday, g.lastWeekday]).toList(), [
        [6, 7],
        [1, 4],
        [5, 5],
      ]);
      expect(groups[0].periods.map((p) => p.open).toList(), ['12:00', '18:00']);
    });

    test('a week with no hours is one closed group', () {
      final groups = summarizeWeek(const []);
      expect(groups, hasLength(1));
      expect(groups.single.isClosed, isTrue);
      expect(groups.single.firstWeekday, 6);
      expect(groups.single.lastWeekday, 5);
    });
  });
}
