import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until the customer menu is built. The router already passes the
/// business slug, branch slug or QR token to this screen.
class PublicMenuScreen extends StatelessWidget {
  const PublicMenuScreen({
    super.key,
    this.businessSlug,
    this.branchSlug,
    this.qrToken,
  });

  final String? businessSlug;
  final String? branchSlug;
  final String? qrToken;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.restaurant_menu_rounded,
          title: 'Menu not available yet',
          message:
              'The customer menu screen is still being built in Phase 1 and '
              'is not available in this build yet.',
        ),
      ),
    );
  }
}
