/// Sold-out presets and the "back at" wording, shared by the dish list and the
/// availability screen. Pure Dart, all times are the device local time.

enum SoldOutPreset { manual, oneHour, twoHours, endOfToday, endOfTomorrow, custom }

const Map<SoldOutPreset, String> soldOutPresetLabels = {
  SoldOutPreset.manual: 'Until I turn it back on',
  SoldOutPreset.oneHour: 'For 1 hour',
  SoldOutPreset.twoHours: 'For 2 hours',
  SoldOutPreset.endOfToday: 'Until end of today',
  SoldOutPreset.endOfTomorrow: 'Until end of tomorrow',
  SoldOutPreset.custom: 'Pick date and time',
};

/// When the dish returns by itself, or null to stay sold out until switched
/// back on. [custom] is used only for [SoldOutPreset.custom].
DateTime? soldOutUntilFor(
  SoldOutPreset preset,
  DateTime now, {
  DateTime? custom,
}) {
  switch (preset) {
    case SoldOutPreset.manual:
      return null;
    case SoldOutPreset.oneHour:
      return now.add(const Duration(hours: 1));
    case SoldOutPreset.twoHours:
      return now.add(const Duration(hours: 2));
    case SoldOutPreset.endOfToday:
      return DateTime(now.year, now.month, now.day + 1);
    case SoldOutPreset.endOfTomorrow:
      return DateTime(now.year, now.month, now.day + 2);
    case SoldOutPreset.custom:
      return custom;
  }
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `3:05 PM`, `12:00 AM`.
String formatClock12(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

/// "back at 3:30 PM", "back tomorrow at 10:00 AM", "back 24 Nov at 10:00 AM".
String backAtText(DateTime until, DateTime now) {
  final local = until.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = day.difference(today).inDays;
  final clock = formatClock12(local);
  if (diffDays <= 0) return 'back at $clock';
  if (diffDays == 1) return 'back tomorrow at $clock';
  return 'back ${local.day} ${_months[local.month - 1]} at $clock';
}
