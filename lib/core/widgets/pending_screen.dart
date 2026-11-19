import 'package:flutter/material.dart';

import 'feedback.dart';
import 'layout.dart';

/// Shown in place of a Phase 1 screen that is not built yet. It says so
/// plainly and offers no fake controls.
class PendingFeatureScreen extends StatelessWidget {
  const PendingFeatureScreen({
    super.key,
    required this.title,
    this.message =
        'This screen is still being built in Phase 1 and is not available '
        'in this build yet.',
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: title,
      scroll: false,
      body: EmptyState(icon: icon, title: 'Not built yet', message: message),
    );
  }
}
