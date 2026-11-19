import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until this Phase 1 screen is built.
class ItemListScreen extends StatelessWidget {
  const ItemListScreen({super.key, this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'Dishes',
      icon: Icons.restaurant_menu_rounded,
    );
  }
}
