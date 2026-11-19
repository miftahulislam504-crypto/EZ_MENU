import 'dart:math';

import 'package:ez_menu/core/logic/slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slugify', () {
    test('lowercases and joins words with dashes', () {
      expect(slugify('Spice Garden'), 'spice-garden');
    });
    test('collapses punctuation and trims', () {
      expect(slugify("  Dhaka's  Best  Biryani!! "), 'dhaka-s-best-biryani');
    });
    test('drops Bangla letters, leaving nothing for a Bangla-only name', () {
      expect(slugify('স্পাইস গার্ডেন'), '');
    });
    test('keeps ASCII parts of mixed names', () {
      expect(slugify('Café Léon 24'), 'caf-l-on-24');
    });
    test('truncates without leaving a trailing dash', () {
      expect(slugify('aaaa bbbb', maxLength: 5), 'aaaa');
    });
  });

  group('isValidSlug', () {
    test('accepts well formed slugs', () {
      expect(isValidSlug('spice-garden'), isTrue);
      expect(isValidSlug('abc'), isTrue);
      expect(isValidSlug('a1-b2-c3'), isTrue);
    });
    test('rejects malformed slugs', () {
      expect(isValidSlug('Spice'), isFalse);
      expect(isValidSlug('ab'), isFalse);
      expect(isValidSlug('abc-'), isFalse);
      expect(isValidSlug('-abc'), isFalse);
      expect(isValidSlug('a--b'), isFalse);
      expect(isValidSlug('a b c'), isFalse);
    });
    test('branch slugs may be shorter', () {
      expect(isValidSlug('ab', minLength: 2), isTrue);
    });
  });

  group('slugCandidates', () {
    test('starts with the base, then numbered variants', () {
      final list = slugCandidates('Spice Garden', random: Random(1)).toList();
      expect(list.take(3).toList(), [
        'spice-garden',
        'spice-garden-2',
        'spice-garden-3',
      ]);
      expect(list, hasLength(10));
    });
    test('falls back for names without usable letters', () {
      final list = slugCandidates('স্পাইস', random: Random(1)).toList();
      expect(list.first, 'restaurant');
    });
    test('every candidate is a valid slug', () {
      for (final c in slugCandidates('Spice Garden', random: Random(7))) {
        expect(isValidSlug(c), isTrue, reason: c);
      }
      for (final c in slugCandidates('x', random: Random(7))) {
        expect(isValidSlug(c), isTrue, reason: c);
      }
    });
  });
}
