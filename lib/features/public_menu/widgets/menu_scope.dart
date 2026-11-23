import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/menu_palette.dart';
import '../public_menu_models.dart';

/// Everything the customer menu widgets need to look right: the restaurant's
/// theme and brand colour, the language and the currency. Read it with
/// `context.menu`.
class MenuLook {
  const MenuLook({
    required this.palette,
    required this.brand,
    required this.currency,
    required this.bangla,
    required this.isGrid,
    required this.baseText,
  });

  final MenuPalette palette;

  /// The restaurant's own colour (fills, buttons).
  final Color brand;
  final String currency;
  final bool bangla;
  final bool isGrid;
  final TextStyle baseText;

  /// Brand colour for text and icons, lightened on a dark menu.
  Color get accent => palette.accentFor(brand);

  /// Readable colour on a filled brand surface.
  Color get onBrand => MenuPalette.onBrand(brand);

  /// A text style in the menu's ink colour.
  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.35,
  }) {
    return baseText.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color ?? palette.ink,
      height: height,
    );
  }

  MenuLook copyWith({bool? bangla}) => MenuLook(
    palette: palette,
    brand: brand,
    currency: currency,
    bangla: bangla ?? this.bangla,
    isGrid: isGrid,
    baseText: baseText,
  );

  static MenuLook from(PublicBusiness business, {required bool bangla, required TextStyle baseText}) {
    return MenuLook(
      palette: MenuPalette.of(business.menuTheme),
      brand: hexToColor(business.brandColor),
      currency: business.currency,
      bangla: bangla,
      isGrid: business.isGrid,
      baseText: baseText,
    );
  }
}

class MenuScope extends InheritedWidget {
  const MenuScope({super.key, required this.style, required super.child});

  final MenuLook style;

  static MenuLook of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MenuScope>();
    assert(scope != null, 'MenuScope is missing above this widget.');
    return scope!.style;
  }

  @override
  bool updateShouldNotify(MenuScope oldWidget) =>
      oldWidget.style.bangla != style.bangla ||
      oldWidget.style.brand != style.brand ||
      oldWidget.style.palette != style.palette ||
      oldWidget.style.currency != style.currency ||
      oldWidget.style.isGrid != style.isGrid;
}

extension MenuContext on BuildContext {
  MenuLook get menu => MenuScope.of(this);
}
