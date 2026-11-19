/// Safe readers for JSON maps returned by Supabase.
///
/// PostgREST sends numeric columns as numbers, dates and times as strings and
/// arrays as lists; these helpers tolerate nulls and a few type variations so
/// models stay short.
extension JsonMapReader on Map<String, dynamic> {
  String? str(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  String requireStr(String key) => str(key) ?? '';

  bool boolean(String key, {bool fallback = false}) {
    final value = this[key];
    if (value is bool) return value;
    if (value is String) return value == 'true' || value == 't';
    return fallback;
  }

  int integer(String key, {int fallback = 0}) => intOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double number(String key, {double fallback = 0}) =>
      numberOrNull(key) ?? fallback;

  double? numberOrNull(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? date(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const <String>[];
  }

  Map<String, dynamic> map(String key) {
    final value = this[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> mapList(String key) {
    final value = this[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }
}

/// `null` when the trimmed text is empty, so empty form fields are stored as
/// NULL rather than empty strings.
String? emptyToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
