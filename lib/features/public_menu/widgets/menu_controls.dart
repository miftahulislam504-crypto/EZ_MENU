import 'package:flutter/material.dart';

import '../../../core/logic/menu_catalog.dart';
import '../public_menu_logic.dart';
import 'menu_scope.dart';

/// Search box and category chips. Pinned to the top while the menu scrolls.
class MenuControlsDelegate extends SliverPersistentHeaderDelegate {
  MenuControlsDelegate({
    required this.style,
    required this.controller,
    required this.query,
    required this.onQuery,
    required this.roots,
    required this.selectedRoot,
    required this.onRoot,
  });

  final MenuLook style;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQuery;
  final List<MenuRoot> roots;
  final String? selectedRoot;
  final ValueChanged<String?> onRoot;

  bool get _showChips => roots.length > 1;

  @override
  double get minExtent => _showChips ? 112 : 66;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return MenuScope(
      style: style,
      child: Builder(
        builder: (context) {
          final menu = context.menu;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: menu.palette.paper,
              border: Border(
                bottom: BorderSide(color: overlapsContent ? menu.palette.line : Colors.transparent),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _SearchField(controller: controller, query: query, onChanged: onQuery),
                ),
                if (_showChips)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _CategoryChip(
                            label: menu.bangla ? 'সব' : 'All',
                            selected: selectedRoot == null,
                            onTap: () => onRoot(null),
                          ),
                          for (final root in roots)
                            _CategoryChip(
                              label: root.title,
                              selected: selectedRoot == root.id,
                              onTap: () => onRoot(selectedRoot == root.id ? null : root.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(MenuControlsDelegate oldDelegate) =>
      oldDelegate.query != query ||
      oldDelegate.selectedRoot != selectedRoot ||
      oldDelegate.roots != roots ||
      oldDelegate.style.bangla != style.bangla ||
      oldDelegate.style.brand != style.brand ||
      oldDelegate.style.palette != style.palette;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.query, required this.onChanged});

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: menu.text(14.5),
        cursorColor: menu.brand,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: menu.palette.surface,
          hintText: menu.bangla ? 'খাবার খুঁজুন' : 'Search dishes',
          hintStyle: menu.text(14.5, color: menu.palette.muted),
          prefixIcon: Icon(Icons.search_rounded, size: 21, color: menu.palette.muted),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: menu.bangla ? 'মুছুন' : 'Clear',
                  icon: Icon(Icons.close_rounded, size: 19, color: menu.palette.muted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: menu.brand, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? menu.brand : menu.palette.surface,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              label,
              style: menu.text(
                13.5,
                weight: FontWeight.w700,
                color: selected ? menu.onBrand : menu.palette.ink,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dietary filters and the "available now" switch, as a row of chips.
class DietaryFilterRow extends StatelessWidget {
  const DietaryFilterRow({
    super.key,
    required this.filters,
    required this.selected,
    required this.onToggle,
    required this.onlyAvailable,
    required this.onOnlyAvailable,
  });

  final List<String> filters;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool onlyAvailable;
  final ValueChanged<bool> onOnlyAvailable;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: bangla ? 'এখন পাওয়া যায়' : 'Available now',
            selected: onlyAvailable,
            onTap: () => onOnlyAvailable(!onlyAvailable),
          ),
          for (final id in filters)
            _FilterChip(
              label: menuTagName(menuLabels, id, bangla: bangla),
              selected: selected.contains(id),
              onTap: () => onToggle(id),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? menu.brand.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: selected ? menu.brand : menu.palette.line, width: selected ? 1.4 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 15, color: menu.accent),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: menu.text(
                    12.5,
                    weight: FontWeight.w700,
                    color: selected ? menu.accent : menu.palette.muted,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
