import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder for Phase 2. Orders need the cart, checkout and payment work
/// that comes next, so this screen says so instead of showing empty tools.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Orders',
      scroll: false,
      body: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Live orders arrive in the next release',
        message:
            'Your digital menu is live. Customers can browse it today. '
            'Cart, checkout, order tracking and payments are added in Phase 2, '
            'and orders will appear here.',
      ),
    );
  }
}
