import '../logic/bd_phone.dart';
import '../logic/money.dart';
import '../logic/slug.dart';

/// Ready-made validators for [AppTextField.validator]. Each returns null when
/// the value is fine, or a message the person can act on.
class Validators {
  const Validators._();

  static String? Function(String?) required(String what) {
    return (value) {
      if (value == null || value.trim().isEmpty) return 'Enter $what.';
      return null;
    };
  }

  static String? Function(String?) maxLength(int max, {String? what}) {
    return (value) {
      if (value != null && value.trim().length > max) {
        return '${what ?? 'This'} must be $max characters or fewer.';
      }
      return null;
    };
  }

  /// A valid email address. Empty is allowed unless [requiredField] is true.
  static String? Function(String?) email({bool requiredField = true}) {
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return requiredField ? 'Enter your email.' : null;
      if (!pattern.hasMatch(text)) return 'Enter a valid email address.';
      return null;
    };
  }

  /// A Bangladeshi mobile number (01XXXXXXXXX, with or without +880).
  static String? Function(String?) bdMobile({bool requiredField = false}) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return requiredField ? 'Enter a mobile number.' : null;
      if (!BdPhone.isValid(text)) {
        return 'Enter a valid Bangladeshi mobile number, like 01712345678.';
      }
      return null;
    };
  }

  /// A web address. Accepts input without https://. Empty is allowed unless
  /// [requiredField] is true.
  static String? Function(String?) url({bool requiredField = false}) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return requiredField ? 'Enter a link.' : null;
      final withScheme = text.contains('://') ? text : 'https://$text';
      final uri = Uri.tryParse(withScheme);
      if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
        return 'Enter a valid link, like www.example.com.';
      }
      return null;
    };
  }

  /// A public link name: lowercase letters, numbers and single hyphens.
  /// Businesses need at least 3 characters, branches at least 2.
  static String? Function(String?) slug({int minLength = 3}) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'Enter a link name.';
      if (!isValidSlug(text, minLength: minLength)) {
        return 'Use lowercase letters, numbers and hyphens, '
            '$minLength to 60 characters.';
      }
      return null;
    };
  }

  /// A money amount. Empty is allowed unless [requiredField] is true.
  static String? Function(String?) price({bool requiredField = true}) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return requiredField ? 'Enter a price.' : null;
      final number = parseAmount(text);
      if (number == null) return 'Enter a number, like 250.';
      if (number < 0) return 'The price cannot be negative.';
      if (number > 10000000) return 'That price is too high.';
      return null;
    };
  }

  /// Either name must be filled in.
  static String? atLeastOne(String? a, String? b, String message) {
    final hasA = a != null && a.trim().isNotEmpty;
    final hasB = b != null && b.trim().isNotEmpty;
    return (hasA || hasB) ? null : message;
  }
}
