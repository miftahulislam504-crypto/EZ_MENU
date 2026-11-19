const String _banglaDigitChars = '০১২৩৪৫৬৭৮৯';

/// Replaces ASCII digits with Bangla digits.
String toBanglaDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final isAsciiDigit = rune >= 0x30 && rune <= 0x39;
    out.write(isAsciiDigit ? _banglaDigitChars[rune - 0x30] : ch);
  }
  return out.toString();
}

/// Groups digits the South Asian way: 1,250 / 12,500 / 1,25,000 / 12,50,000.
String groupSouthAsian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}

/// Amount without a currency symbol. Whole amounts have no decimals; others
/// keep two (e.g. 250, 1,250, 99.50).
String formatAmount(num value, {bool bangla = false}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = groupSouthAsian(parts[0]);
  final fraction = parts[1];
  var text = fraction == '00' ? whole : '$whole.$fraction';
  if (negative) text = '-$text';
  return bangla ? toBanglaDigits(text) : text;
}

/// Currency symbol for an ISO code. Unknown codes are returned as-is.
String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'BDT':
      return '৳';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'INR':
      return '₹';
    default:
      return code.toUpperCase();
  }
}

/// `৳ 380` / `৳ ৩৮০` with a thin gap between symbol and amount.
String formatMoney(num value, {String currency = 'BDT', bool bangla = false}) {
  return '${currencySymbol(currency)} ${formatAmount(value, bangla: bangla)}';
}

/// Parses user input such as "250", "1,250.50" or "২৫০" into a number.
/// Returns null when the text is empty or not a number.
double? parseAmount(String? input) {
  if (input == null) return null;
  var text = input.trim();
  if (text.isEmpty) return null;
  final ascii = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final index = _banglaDigitChars.indexOf(ch);
    ascii.write(index >= 0 ? index.toString() : ch);
  }
  text = ascii.toString().replaceAll(',', '').replaceAll('৳', '').trim();
  return double.tryParse(text);
}
