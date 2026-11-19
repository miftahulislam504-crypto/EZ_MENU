import 'package:ez_menu/core/logic/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupSouthAsian', () {
    test('groups as 3 then 2s', () {
      expect(groupSouthAsian('1'), '1');
      expect(groupSouthAsian('999'), '999');
      expect(groupSouthAsian('1000'), '1,000');
      expect(groupSouthAsian('12500'), '12,500');
      expect(groupSouthAsian('125000'), '1,25,000');
      expect(groupSouthAsian('1250000'), '12,50,000');
      expect(groupSouthAsian('12345678'), '1,23,45,678');
    });
  });

  group('formatAmount', () {
    test('whole amounts have no decimals', () {
      expect(formatAmount(380), '380');
      expect(formatAmount(1250), '1,250');
      expect(formatAmount(0), '0');
      expect(formatAmount(125000), '1,25,000');
    });
    test('fractions keep two decimals', () {
      expect(formatAmount(99.5), '99.50');
      expect(formatAmount(-1250.75), '-1,250.75');
    });
    test('Bangla digits', () {
      expect(formatAmount(380, bangla: true), '৩৮০');
      expect(formatAmount(1250, bangla: true), '১,২৫০');
    });
  });

  group('formatMoney', () {
    test('uses the currency symbol', () {
      expect(formatMoney(380), '৳ 380');
      expect(formatMoney(380, bangla: true), '৳ ৩৮০');
      expect(formatMoney(5, currency: 'USD'), '\$ 5');
    });
    test('currencySymbol is case insensitive and keeps unknown codes', () {
      expect(currencySymbol('bdt'), '৳');
      expect(currencySymbol('xyz'), 'XYZ');
    });
  });

  group('toBanglaDigits', () {
    test('converts only digits', () {
      expect(toBanglaDigits('Table 12'), 'Table ১২');
      expect(toBanglaDigits('0123456789'), '০১২৩৪৫৬৭৮৯');
    });
  });

  group('parseAmount', () {
    test('parses common inputs', () {
      expect(parseAmount('250'), 250);
      expect(parseAmount('1,250.50'), 1250.5);
      expect(parseAmount('২৫০'), 250);
      expect(parseAmount('৳ 380'), 380);
      expect(parseAmount(' 12.5 '), 12.5);
    });
    test('returns null for empty or invalid input', () {
      expect(parseAmount(null), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('  '), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12.5.1'), isNull);
    });
  });
}
