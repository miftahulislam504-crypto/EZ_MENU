import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';
import 'branch_switcher.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Tab> _tabs = [
  _Tab('Home', Icons.home_outlined, Icons.home_rounded),
  _Tab('Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Tab('Menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
  _Tab('QR & Tables', Icons.qr_code_2_outlined, Icons.qr_code_2_rounded),
  _Tab('More', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

/// Navigation frame for the signed-in dashboard.
///
/// Phones get a bottom bar (hidden on nested screens so forms have room);
/// tablets and desktop get a side rail that stays visible.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Current path, used to hide the bottom bar on nested screens.
  final String location;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    if (wide) return _wideLayout(context);
    return _compactLayout(context);
  }

  Widget _compactLayout(BuildContext context) {
    final depth = Uri.tryParse(location)?.pathSegments.length ?? 1;
    final showBar = depth <= 1;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showBar
          ? NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            )
          : null,
    );
  }

  Widget _wideLayout(BuildContext context) {
    final extended = context.isWide;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 232,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _select,
            backgroundColor: context.colors.surface,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.lg, Sp.sm, Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(size: 36),
                      if (extended) ...[
                        const SizedBox(width: Sp.md),
                        Text('EZ Menu', style: context.textStyles.titleLarge),
                      ],
                    ],
                  ),
                  if (extended) ...[
                    const SizedBox(height: Sp.lg),
                    const SizedBox(
                      width: 200,
                      child: BranchSwitcher(expand: true),
                    ),
                  ],
                ],
              ),
            ),
            destinations: [
              for (final tab in _tabs)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: Text(tab.label),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: context.palette.line),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
