import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until this Phase 1 screen is built.
class CategoryEditScreen extends StatelessWidget {
  const CategoryEditScreen({super.key, this.categoryId, this.parentId});

  final String? categoryId;
  final String? parentId;

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'Category',
      icon: Icons.category_outlined,
    );
  }
}
