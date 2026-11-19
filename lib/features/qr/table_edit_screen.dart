import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until this Phase 1 screen is built.
class TableEditScreen extends StatelessWidget {
  const TableEditScreen({super.key, this.tableId});

  final String? tableId;

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'Table',
      icon: Icons.table_restaurant_outlined,
    );
  }
}
