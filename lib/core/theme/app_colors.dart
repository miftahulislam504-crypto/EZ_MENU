import 'package:flutter/material.dart';

/// EZ Menu palette.
///
/// Drawn from the food itself: banana-leaf green for actions, turmeric yellow
/// for highlights, red chili for anything destructive or sold out, on a cool
/// leaf-tinted paper background.
class AppColors {
  const AppColors._();

  // Brand
  static const Color leaf = Color(0xFF166A4C);
  static const Color leafDeep = Color(0xFF0F4B36);
  static const Color leafSoft = Color(0xFFE2F0E8);
  static const Color haldi = Color(0xFFF0A81C);
  static const Color haldiSoft = Color(0xFFFCEFD0);
  static const Color haldiDeep = Color(0xFF6B4700);
  static const Color chili = Color(0xFFD6382F);
  static const Color chiliSoft = Color(0xFFFBE4E2);
  static const Color chiliDeep = Color(0xFF7A1812);

  // Light surfaces
  static const Color ink = Color(0xFF0F2A21);
  static const Color muted = Color(0xFF5B6F65);
  static const Color paper = Color(0xFFF4F6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE0E6DE);
  static const Color lineStrong = Color(0xFFC3CEC6);

  // Dark surfaces
  static const Color darkInk = Color(0xFFEAF2ED);
  static const Color darkMuted = Color(0xFF93A99D);
  static const Color darkPaper = Color(0xFF0B1712);
  static const Color darkSurface = Color(0xFF12241C);
  static const Color darkLine = Color(0xFF223A2F);
  static const Color darkLineStrong = Color(0xFF35564A);
}

/// `#RRGGBB` to [Color]. Falls back to [fallback] for malformed input.
Color hexToColor(String? hex, {Color fallback = AppColors.leaf}) {
  if (hex == null) return fallback;
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

/// [Color] to `#RRGGBB`.
String colorToHex(Color color) {
  int channel(double v) => (v * 255).round().clamp(0, 255);
  final rgb =
      (channel(color.r) << 16) | (channel(color.g) << 8) | channel(color.b);
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Readable text colour (ink or white) for content drawn on [background].
Color onColor(Color background) {
  return background.computeLuminance() > 0.55 ? AppColors.ink : Colors.white;
}
