import 'package:ez_menu/core/logic/bd_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BdPhone.normalize', () {
    test('accepts the common written forms', () {
      expect(BdPhone.normalize('01712345678'), '01712345678');
      expect(BdPhone.normalize('01712-345678'), '01712345678');
      expect(BdPhone.normalize('+8801712345678'), '01712345678');
      expect(BdPhone.normalize('8801712345678'), '01712345678');
      expect(BdPhone.normalize('1712345678'), '01712345678');
      expect(BdPhone.normalize('+88 01712 345678'), '01712345678');
    });
    test('accepts Bangla digits', () {
      expect(BdPhone.normalize('০১৭১২৩৪৫৬৭৮'), '01712345678');
    });
    test('rejects invalid numbers', () {
      expect(BdPhone.normalize(''), isNull);
      expect(BdPhone.normalize('abc'), isNull);
      expect(BdPhone.normalize('0171234567'), isNull); // too short
      expect(BdPhone.normalize('017123456789'), isNull); // too long
      expect(
        BdPhone.normalize('01212345678'),
        isNull,
      ); // 012 is not a mobile prefix
      expect(BdPhone.normalize('02912345678'), isNull);
    });
    test('accepts every operator prefix 013-019', () {
      for (final p in ['013', '014', '015', '016', '017', '018', '019']) {
        expect(BdPhone.isValid('${p}12345678'), isTrue, reason: p);
      }
    });
  });

  group('BdPhone formats', () {
    test('e164, display and WhatsApp link', () {
      expect(BdPhone.toE164('01712345678'), '+8801712345678');
      expect(BdPhone.format('01712345678'), '01712-345678');
      expect(
        BdPhone.whatsappLink('01712345678'),
        'https://wa.me/8801712345678',
      );
    });
    test('invalid input passes through or returns null', () {
      expect(BdPhone.toE164('abc'), isNull);
      expect(BdPhone.format(' abc '), 'abc');
      expect(BdPhone.whatsappLink('abc'), isNull);
    });
  });
}
