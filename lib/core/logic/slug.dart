import 'dart:math';

/// Turns free text into a URL-safe slug (lowercase a-z, 0-9 and single dashes).
///
/// Characters outside a-z / 0-9 (including Bangla letters) become separators,
/// so a purely Bangla name yields an empty string. Callers should then fall
/// back to [slugCandidates] with a fallback word.
String slugify(String input, {int maxLength = 40}) {
  final buffer = StringBuffer();
  var lastWasDash = true; // true at the start so no leading dash is written
  for (final unit in input.toLowerCase().codeUnits) {
    final isLetter = unit >= 0x61 && unit <= 0x7a;
    final isDigit = unit >= 0x30 && unit <= 0x39;
    if (isLetter || isDigit) {
      buffer.writeCharCode(unit);
      lastWasDash = false;
    } else if (!lastWasDash) {
      buffer.write('-');
      lastWasDash = true;
    }
  }
  var result = buffer.toString();
  if (result.length > maxLength) {
    result = result.substring(0, maxLength);
  }
  return result.replaceAll(RegExp(r'-+$'), '');
}

final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Matches the database rule for business and branch slugs.
bool isValidSlug(String slug, {int minLength = 3, int maxLength = 60}) {
  return slug.length >= minLength &&
      slug.length <= maxLength &&
      _slugPattern.hasMatch(slug);
}

/// Slugs to try, best first: the base itself, then numbered and random
/// variants. If [name] has no usable letters the [fallback] word is used.
Iterable<String> slugCandidates(
  String name, {
  String fallback = 'restaurant',
  int minLength = 3,
  Random? random,
}) sync* {
  var base = slugify(name, maxLength: 40);
  if (base.length < minLength) {
    base = slugify(fallback, maxLength: 40);
    if (base.length < minLength) base = 'menu';
  }
  yield base;
  for (var i = 2; i <= 6; i++) {
    yield '$base-$i';
  }
  final rng = random ?? Random();
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  for (var i = 0; i < 4; i++) {
    final suffix = List.generate(
      4,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    yield '$base-$suffix';
  }
}
