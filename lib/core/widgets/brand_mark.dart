import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The EZ Menu mark: a leaf-green tile with the monogram and a turmeric dot.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.inverted = false});

  final double size;

  /// White tile with a green monogram, for use on the green brand panel.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: inverted ? Colors.white : AppColors.leaf,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            alignment: Alignment.center,
            child: Text(
              'EZ',
              style: TextStyle(
                color: inverted ? AppColors.leaf : Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: -size * 0.04,
            top: -size * 0.04,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: AppColors.haldi,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: size * 0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
