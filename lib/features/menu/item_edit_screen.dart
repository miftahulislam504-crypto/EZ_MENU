import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until this Phase 1 screen is built.
class ItemEditScreen extends StatelessWidget {
  const ItemEditScreen({super.key, this.itemId, this.categoryId});

  final String? itemId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'Dish',
      icon: Icons.restaurant_menu_rounded,
    );
  }
}
