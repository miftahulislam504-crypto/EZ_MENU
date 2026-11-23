import 'package:flutter_test/flutter_test.dart';
import 'package:ez_menu/core/logic/sold_out.dart';

void main() {
  final now = DateTime(2026, 11, 20, 14, 30);

  group('soldOutUntilFor', () {
    test('manual has no return time', () {
      expect(soldOutUntilFor(SoldOutPreset.manual, now), isNull);
    });

    test('hours', () {
      expect(soldOutUntilFor(SoldOutPreset.oneHour, now), equals(DateTime(2026, 11, 20, 15, 30)));
      expect(soldOutUntilFor(SoldOutPreset.twoHours, now), equals(DateTime(2026, 11, 20, 16, 30)));
    });

    test('end of today is the next midnight', () {
      expect(soldOutUntilFor(SoldOutPreset.endOfToday, now), equals(DateTime(2026, 11, 21)));
    });

    test('end of tomorrow', () {
      expect(soldOutUntilFor(SoldOutPreset.endOfTomorrow, now), equals(DateTime(2026, 11, 22)));
    });

    test('end of today across a month boundary', () {
      expect(soldOutUntilFor(SoldOutPreset.endOfToday, DateTime(2026, 11, 30, 10)), equals(DateTime(2026, 12, 1)));
    });

    test('custom passes the picked time through', () {
      final picked = DateTime(2026, 12, 1, 9);
      expect(soldOutUntilFor(SoldOutPreset.custom, now, custom: picked), equals(picked));
      expect(soldOutUntilFor(SoldOutPreset.custom, now), isNull);
    });
  });

  group('formatClock12', () {
    test('midnight, noon and afternoon', () {
      expect(formatClock12(DateTime(2026, 1, 1, 0, 5)), equals('12:05 AM'));
      expect(formatClock12(DateTime(2026, 1, 1, 12, 0)), equals('12:00 PM'));
      expect(formatClock12(DateTime(2026, 1, 1, 15, 7)), equals('3:07 PM'));
      expect(formatClock12(DateTime(2026, 1, 1, 9, 30)), equals('9:30 AM'));
    });
  });

  group('backAtText', () {
    test('same day', () {
      expect(backAtText(DateTime(2026, 11, 20, 16, 0), now), equals('back at 4:00 PM'));
    });

    test('tomorrow', () {
      expect(backAtText(DateTime(2026, 11, 21, 10, 0), now), equals('back tomorrow at 10:00 AM'));
    });

    test('later date', () {
      expect(backAtText(DateTime(2026, 11, 24, 10, 0), now), equals('back 24 Nov at 10:00 AM'));
    });

    test('a time that has passed reads as today', () {
      expect(backAtText(DateTime(2026, 11, 20, 8, 0), now), equals('back at 8:00 AM'));
    });
  });

  test('every preset has a label', () {
    for (final preset in SoldOutPreset.values) {
      expect(soldOutPresetLabels.containsKey(preset), isTrue);
    }
  });
}
