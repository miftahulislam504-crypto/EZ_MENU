import 'package:ez_menu/core/logic/localized.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickText', () {
    test('uses the requested language when present', () {
      expect(pickText('Beef', 'গরু', bangla: false), 'Beef');
      expect(pickText('Beef', 'গরু', bangla: true), 'গরু');
    });
    test('falls back to the other language', () {
      expect(pickText('Beef', null, bangla: true), 'Beef');
      expect(pickText(null, 'গরু', bangla: false), 'গরু');
      expect(pickText('Beef', '   ', bangla: true), 'Beef');
    });
    test('returns null when both are empty', () {
      expect(pickText(null, null, bangla: true), isNull);
      expect(pickText('  ', '', bangla: false), isNull);
    });
    test('trims the result', () {
      expect(pickText('  Beef ', null, bangla: false), 'Beef');
    });
  });

  group('helpers', () {
    test('pickTextOr uses the fallback', () {
      expect(pickTextOr(null, null, bangla: true, fallback: 'x'), 'x');
    });
    test('dashboardName prefers English', () {
      expect(dashboardName('Spice', 'স্পাইস'), 'Spice');
      expect(dashboardName(null, 'স্পাইস'), 'স্পাইস');
      expect(dashboardName(null, null), 'Untitled');
    });
  });
}
