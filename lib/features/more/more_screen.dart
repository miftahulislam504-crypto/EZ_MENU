import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_repository.dart';

/// Restaurant settings, menu tools, account, and a plain list of what comes
/// in later releases.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Sign out',
      message: 'You will need to sign in again to manage your menu.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(String path) => context.push(path);

    return AppPage(
      title: 'More',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListGroup(
            title: 'Restaurant',
            children: [
              ListRow(
                title: 'Restaurant profile',
                subtitle: 'Name, contact, description and social links',
                leading: const IconBadge(Icons.storefront_outlined),
                onTap: () => open(AppRoutes.profile),
              ),
              ListRow(
                title: 'Branches and hours',
                subtitle: 'Locations, opening hours and closures',
                leading: const IconBadge(Icons.schedule_rounded),
                onTap: () => open(AppRoutes.branches),
              ),
              ListRow(
                title: 'Branding',
                subtitle: 'Logo, cover, colours and menu style',
                leading: const IconBadge(Icons.palette_outlined),
                onTap: () => open(AppRoutes.branding),
              ),
              ListRow(
                title: 'Public menu link',
                subtitle: 'Your address and publish settings',
                leading: const IconBadge(Icons.link_rounded),
                onTap: () => open(AppRoutes.publicLink),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          ListGroup(
            title: 'Menu tools',
            children: [
              ListRow(
                title: 'Availability',
                subtitle: 'Mark dishes sold out or available',
                leading: const IconBadge(Icons.block_rounded),
                onTap: () => open(AppRoutes.availability),
              ),
              ListRow(
                title: 'Bulk price update',
                subtitle: 'Raise or lower many prices at once',
                leading: const IconBadge(Icons.price_change_outlined),
                onTap: () => open(AppRoutes.bulkPrices),
              ),
              ListRow(
                title: 'Import and export',
                subtitle: 'Move your menu in and out with a CSV file',
                leading: const IconBadge(Icons.swap_vert_rounded),
                onTap: () => open(AppRoutes.importExport),
              ),
              ListRow(
                title: 'Customer preview',
                subtitle: 'See your menu the way customers do',
                leading: const IconBadge(Icons.visibility_outlined),
                onTap: () => open(AppRoutes.preview),
              ),
              ListRow(
                title: 'Trash',
                subtitle: 'Restore deleted dishes and categories',
                leading: const IconBadge(Icons.delete_outline_rounded),
                onTap: () => open(AppRoutes.trash),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          ListGroup(
            title: 'Account',
            children: [
              ListRow(
                title: 'Account and security',
                subtitle: 'Your details and password',
                leading: const IconBadge(Icons.person_outline_rounded),
                onTap: () => open(AppRoutes.account),
              ),
              ListRow(
                title: 'Help',
                subtitle: 'Guides and answers',
                leading: const IconBadge(Icons.help_outline_rounded),
                onTap: () => open(AppRoutes.help),
              ),
              ListRow(
                title: 'Terms and privacy',
                leading: const IconBadge(Icons.description_outlined),
                onTap: () => open(AppRoutes.legal),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          const _ComingLater(),
          const SizedBox(height: Sp.xl),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            kind: AppButtonKind.secondary,
            expand: true,
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _ComingLater extends StatelessWidget {
  const _ComingLater();

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    Widget row(String title, String phase, IconData icon) => ListRow(
      title: title,
      titleColor: muted,
      leading: IconBadge(icon),
      trailing: StatusPill(phase),
    );

    return ListGroup(
      title: 'Coming later',
      children: [
        row('Orders and payments', 'Phase 2', Icons.receipt_long_outlined),
        row('Reports', 'Phase 2', Icons.insights_outlined),
        row('Notifications', 'Phase 2', Icons.notifications_none_rounded),
        row('Staff and roles', 'Phase 3', Icons.badge_outlined),
        row('Kitchen display', 'Phase 3', Icons.soup_kitchen_outlined),
        row('Delivery settings', 'Phase 3', Icons.delivery_dining_outlined),
        row('Promotions and offers', 'Phase 4', Icons.local_offer_outlined),
        row('Reservations', 'Phase 4', Icons.event_seat_outlined),
        row('Customers', 'Phase 4', Icons.groups_outlined),
      ],
    );
  }
}
