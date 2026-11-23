import 'package:flutter/material.dart';

import '../../../core/theme/menu_palette.dart';

/// A phone-shaped frame for showing the customer menu in the dashboard.
/// Inside it, screen insets are zero so the menu lays out like it does on a
/// real phone of that width.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.width = 390, this.height = 720});

  final Widget child;
  final double width;
  final double height;

  static const double _bezel = 9;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_bezel),
      decoration: BoxDecoration(
        color: MenuPalette.dark.paper,
        borderRadius: BorderRadius.circular(44),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44 - _bezel),
        child: MediaQuery(
          data: media.copyWith(
            size: Size(width - _bezel * 2, height - _bezel * 2),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }
}
