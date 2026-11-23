import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/features/menu/menu_models.dart';
import 'package:ez_menu/features/menu/schedule_logic.dart';

void main() {
  group('presets', () {
    test('breakfast lunch dinner are time windows', () {
      final b = presetWindow(SchedulePreset.breakfast);
      expect(b.startTime, equals('06:00'));
      expect(b.endTime, equals('11:00'));
      expect(presetWindow(SchedulePreset.lunch).startTime, equals('12:00'));
      expect(presetWindow(SchedulePreset.dinner).endTime, equals('23:00'));
    });

    test('weekends are Friday and Saturday all day', () {
      final w = presetWindow(SchedulePreset.weekends);
      expect(w.weekdays, equals([5, 6]));
      expect(hasTimeRange(w), isFalse);
    });

    test('late night is overnight', () {
      expect(isOvernight(presetWindow(SchedulePreset.lateNight)), isTrue);
      expect(isOvernight(presetWindow(SchedulePreset.dinner)), isFalse);
    });

    test('every preset is valid and has a label', () {
      for (final p in SchedulePreset.values) {
        expect(validateSchedules([presetWindow(p)]), isEmpty);
        expect(schedulePresetLabels.containsKey(p), isTrue);
      }
    });
  });

  group('weekdays', () {
    test('toggleWeekday adds, removes and sorts', () {
      expect(toggleWeekday([], 6), equals([6]));
      expect(toggleWeekday([6, 1], 3), equals([1, 3, 6]));
      expect(toggleWeekday([1, 3], 3), equals([1]));
    });

    test('isEveryDay', () {
      expect(isEveryDay([]), isTrue);
      expect(isEveryDay([1, 2, 3, 4, 5, 6, 7]), isTrue);
      expect(isEveryDay([1, 2]), isFalse);
    });
  });

  group('time helpers', () {
    test('equal times count as all day', () {
      expect(isAllDayByEqualTimes(const ItemSchedule(startTime: '10:00', endTime: '10:00')), isTrue);
      expect(isAllDayByEqualTimes(const ItemSchedule(startTime: '10:00', endTime: '11:00')), isFalse);
      expect(isAllDayByEqualTimes(const ItemSchedule()), isFalse);
    });

    test('overnight needs both times', () {
      expect(isOvernight(const ItemSchedule(startTime: '22:00')), isFalse);
    });
  });

  group('windowSummary', () {
    test('days and time', () {
      final text = windowSummary(const ItemSchedule(weekdays: [5, 6], startTime: '18:00', endTime: '22:00'));
      expect(text.contains('Fri'), isTrue);
      expect(text.contains('Sat'), isTrue);
    });

    test('every day all day', () {
      expect(windowSummary(const ItemSchedule()), equals('Every day, All day'));
    });

    test('date range', () {
      final text = windowSummary(const ItemSchedule(startDate: '2026-12-01', endDate: '2026-12-31'));
      expect(text.contains('2026-12-01 to 2026-12-31'), isTrue);
    });
  });

  group('availableByScheduleNow', () {
    final friday = DateTime(2026, 11, 20, 13, 0);

    test('no windows means always available', () {
      expect(availableByScheduleNow(const [], friday), isTrue);
    });

    test('inside and outside a time window', () {
      const lunch = ItemSchedule(startTime: '12:00', endTime: '15:00');
      expect(availableByScheduleNow(const [lunch], friday), isTrue);
      expect(availableByScheduleNow(const [lunch], DateTime(2026, 11, 20, 16, 0)), isFalse);
    });

    test('weekday window', () {
      const saturdayOnly = ItemSchedule(weekdays: [6]);
      expect(availableByScheduleNow(const [saturdayOnly], friday), isFalse);
      expect(availableByScheduleNow(const [saturdayOnly], DateTime(2026, 11, 21, 9)), isTrue);
    });

    test('overnight window after midnight', () {
      const late = ItemSchedule(startTime: '22:00', endTime: '02:00');
      expect(availableByScheduleNow(const [late], DateTime(2026, 11, 21, 1, 0)), isTrue);
      expect(availableByScheduleNow(const [late], DateTime(2026, 11, 21, 3, 0)), isFalse);
    });

    test('any window is enough', () {
      const a = ItemSchedule(startTime: '06:00', endTime: '08:00');
      const b = ItemSchedule(startTime: '12:00', endTime: '14:00');
      expect(availableByScheduleNow(const [a, b], friday), isTrue);
    });

    test('date range', () {
      const promo = ItemSchedule(startDate: '2026-12-01', endDate: '2026-12-31');
      expect(availableByScheduleNow(const [promo], friday), isFalse);
      expect(availableByScheduleNow(const [promo], DateTime(2026, 12, 5, 12)), isTrue);
    });
  });

  group('validateSchedules', () {
    test('empty is valid', () => expect(validateSchedules(const []), isEmpty));

    test('start without end', () {
      final errors = validateSchedules([const ItemSchedule(startTime: '10:00')]);
      expect(errors.length, equals(1));
      expect(errors.first.contains('both a start time and an end time'), isTrue);
    });

    test('end without start', () {
      expect(validateSchedules([const ItemSchedule(endTime: '10:00')]).isNotEmpty, isTrue);
    });

    test('a time that cannot be read', () {
      expect(validateSchedules([const ItemSchedule(startTime: 'abc', endTime: '10:00')]).isNotEmpty, isTrue);
    });

    test('first date after last date', () {
      final errors = validateSchedules([const ItemSchedule(startDate: '2026-12-31', endDate: '2026-12-01')]);
      expect(errors.length, equals(1));
      expect(errors.first.contains('after'), isTrue);
    });

    test('same first and last date is fine', () {
      expect(validateSchedules([const ItemSchedule(startDate: '2026-12-01', endDate: '2026-12-01')]), isEmpty);
    });

    test('equal times are allowed', () {
      expect(validateSchedules([const ItemSchedule(startTime: '10:00', endTime: '10:00')]), isEmpty);
    });

    test('label length', () {
      expect(validateSchedules([ItemSchedule(label: 'a' * 81)]).length, equals(1));
      expect(validateSchedules([ItemSchedule(label: 'a' * 80)]), isEmpty);
    });

    test('a weekday outside 1 to 7', () {
      expect(validateSchedules([const ItemSchedule(weekdays: [0])]).isNotEmpty, isTrue);
      expect(validateSchedules([const ItemSchedule(weekdays: [8])]).isNotEmpty, isTrue);
    });

    test('identical windows are reported once', () {
      final errors = validateSchedules([
        const ItemSchedule(weekdays: [1, 2], startTime: '10:00', endTime: '12:00'),
        const ItemSchedule(weekdays: [2, 1], startTime: '10:00', endTime: '12:00', label: 'copy'),
      ]);
      expect(errors, equals(['Window 2 is the same as window 1.']));
    });

    test('every day listed explicitly equals an empty list', () {
      final errors = validateSchedules([
        const ItemSchedule(),
        const ItemSchedule(weekdays: [1, 2, 3, 4, 5, 6, 7]),
      ]);
      expect(errors.length, equals(1));
    });

    test('different windows are fine', () {
      expect(
        validateSchedules([
          const ItemSchedule(startTime: '06:00', endTime: '11:00'),
          const ItemSchedule(startTime: '18:00', endTime: '23:00'),
        ]),
        isEmpty,
      );
    });
  });
}
