/// Bangladeshi mobile number helpers.
///
/// Accepted inputs: 01712345678, 01712-345678, +8801712345678,
/// 8801712345678, 1712345678 and the same written with Bangla digits.
class BdPhone {
  const BdPhone._();

  static const String _banglaDigits = '০১২৩৪৫৬৭৮৯';

  /// Replaces Bangla digits with ASCII digits.
  static String asciiDigits(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final index = _banglaDigits.indexOf(ch);
      out.write(index >= 0 ? index.toString() : ch);
    }
    return out.toString();
  }

  /// Canonical national form `01XXXXXXXXX`, or null when [input] is not a
  /// valid Bangladeshi mobile number (operator prefix 013-019).
  static String? normalize(String input) {
    var digits = asciiDigits(input).replaceAll(RegExp(r'[\s\-().]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('880') && digits.length == 13) {
      digits = '0${digits.substring(3)}';
    } else if (digits.length == 10 && digits.startsWith('1')) {
      digits = '0$digits';
    }
    return RegExp(r'^01[3-9]\d{8}$').hasMatch(digits) ? digits : null;
  }

  static bool isValid(String input) => normalize(input) != null;

  /// `+8801712345678`, or null when invalid.
  static String? toE164(String input) {
    final national = normalize(input);
    return national == null ? null : '+88${national}';
  }

  /// `01712-345678` for display, or the trimmed input when it is not valid.
  static String format(String input) {
    final national = normalize(input);
    if (national == null) return input.trim();
    return '${national.substring(0, 5)}-${national.substring(5)}';
  }

  /// `https://wa.me/8801712345678` for click-to-chat, or null when invalid.
  static String? whatsappLink(String input) {
    final national = normalize(input);
    return national == null ? null : 'https://wa.me/88$national';
  }
}
