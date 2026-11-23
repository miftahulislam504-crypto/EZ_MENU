import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colours of the customer menu for each `menu_theme` a restaurant can pick.
/// Shared by the customer menu and the live preview in branding settings.
class MenuPalette {
  const MenuPalette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.isDark,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final bool isDark;

  static const MenuPalette light = MenuPalette(
    paper: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7F5),
    ink: Color(0xFF16201B),
    muted: Color(0xFF68766E),
    line: Color(0xFFE3E8E4),
    isDark: false,
  );

  static const MenuPalette warm = MenuPalette(
    paper: Color(0xFFFBF5EA),
    surface: Color(0xFFF4EBDA),
    ink: Color(0xFF2A2118),
    muted: Color(0xFF7A6A55),
    line: Color(0xFFE6D9C2),
    isDark: false,
  );

  static const MenuPalette dark = MenuPalette(
    paper: Color(0xFF111714),
    surface: Color(0xFF1A231E),
    ink: Color(0xFFEEF3EF),
    muted: Color(0xFF9AAAA1),
    line: Color(0xFF2A3730),
    isDark: true,
  );

  static MenuPalette of(String? theme) {
    switch (theme) {
      case 'warm':
        return warm;
      case 'dark':
        return dark;
      default:
        return light;
    }
  }

  /// Status colours for the customer menu: open, closed and a caution tone.
  /// Lighter on the dark theme so they stay readable.
  Color get open => isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
  Color get closed => isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
  Color get caution => isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  /// Accent for text and icons on this palette: the brand colour, lightened
  /// on dark backgrounds so it stays readable.
  Color accentFor(Color brand) {
    if (!isDark) return brand;
    final hsl = HSLColor.fromColor(brand);
    return hsl.withLightness(hsl.lightness.clamp(0.62, 0.8)).toColor();
  }

  /// Readable colour for content on a filled brand-colour surface.
  static Color onBrand(Color brand) => onColor(brand);
}
