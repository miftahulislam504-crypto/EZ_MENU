/// Picks the text for the active language, falling back to the other one.
///
/// Menu content is stored as paired `_en` / `_bn` fields and either may be
/// empty. Returns null when both are empty.
String? pickText(String? en, String? bn, {required bool bangla}) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  final english = clean(en);
  final bengali = clean(bn);
  return bangla ? (bengali ?? english) : (english ?? bengali);
}

/// Same as [pickText] but never null.
String pickTextOr(
  String? en,
  String? bn, {
  required bool bangla,
  String fallback = '',
}) {
  return pickText(en, bn, bangla: bangla) ?? fallback;
}

/// Name shown in the English dashboard: English when present, else Bangla.
String dashboardName(String? en, String? bn, {String fallback = 'Untitled'}) {
  return pickText(en, bn, bangla: false) ?? fallback;
}
