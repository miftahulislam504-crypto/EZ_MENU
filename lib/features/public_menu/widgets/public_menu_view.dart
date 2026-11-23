import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'highlights_rail.dart';
import 'info_sheets.dart';
import 'item_detail_sheet.dart';
import 'menu_controls.dart';
import 'menu_header.dart';
import 'menu_item_card.dart';
import 'menu_scope.dart';
import 'menu_sheet.dart';

enum _MenuSheet { none, info, branches }

/// What the menu works out from the data once per data or language change.
class _Derived {
  _Derived(PublicMenuData data, {required bool bangla})
    : roots = buildRoots(data, buildSections(data, bangla: bangla), bangla: bangla),
      rails = buildHighlights(data.items),
      filters = availableFilters(data.items),
      hasUnavailable = data.items.any((item) => !item.availability.canOrder);

  final List<MenuRoot> roots;
  final List<HighlightRail> rails;
  final List<String> filters;
  final bool hasUnavailable;
}

/// The customer menu: cover and restaurant name, search, categories, dish
/// lists and the dish and information sheets. Used full screen for customers
/// and inside the phone frame of the dashboard preview ([embedded]).
///
/// Taking an order is not part of this phase, so dishes open for viewing only.
class PublicMenuView extends StatefulWidget {
  const PublicMenuView({
    super.key,
    required this.data,
    this.embedded = false,
    this.onSelectBranch,
    this.initialBangla,
    this.onLanguageChanged,
  });

  final PublicMenuData data;

  /// True inside the preview frame: no device safe area padding.
  final bool embedded;

  /// Called when the customer picks another branch. Null hides the switcher.
  final ValueChanged<PublicBranchLink>? onSelectBranch;

  /// Language to start in. Defaults to the restaurant's default language.
  final bool? initialBangla;
  final ValueChanged<bool>? onLanguageChanged;

  @override
  State<PublicMenuView> createState() => _PublicMenuViewState();
}

class _PublicMenuViewState extends State<PublicMenuView> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  late bool _bangla = widget.initialBangla ?? widget.data.business.startsInBangla;
  String _query = '';
  final Set<String> _filters = {};
  bool _onlyAvailable = false;
  String? _root;
  PublicItem? _item;
  _MenuSheet _sheet = _MenuSheet.none;

  PublicMenuData? _derivedFor;
  bool? _derivedBangla;
  _Derived? _derived;

  bool get _hasSheet => _item != null || _sheet != _MenuSheet.none;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _Derived _derive() {
    final data = widget.data;
    if (_derived == null || !identical(_derivedFor, data) || _derivedBangla != _bangla) {
      _derived = _Derived(data, bangla: _bangla);
      _derivedFor = data;
      _derivedBangla = _bangla;
    }
    return _derived!;
  }

  void _setLanguage(bool bangla) {
    if (bangla == _bangla) return;
    setState(() => _bangla = bangla);
    widget.onLanguageChanged?.call(bangla);
  }

  void _selectRoot(String? id) {
    setState(() => _root = id);
    // Bring the list back up under the pinned bar so the new section is seen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _headerKey.currentContext?.findRenderObject();
      final target = box is RenderBox ? box.size.height : 0.0;
      if (_scroll.offset > target) {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
      }
    });
  }

  void _toggleFilter(String id) {
    setState(() {
      if (!_filters.remove(id)) _filters.add(id);
    });
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _filters.clear();
      _onlyAvailable = false;
      _root = null;
    });
  }

  void _closeSheet() {
    setState(() {
      _item = null;
      _sheet = _MenuSheet.none;
    });
  }

  Widget? _sheetWidget(PublicMenuData data) {
    final item = _item;
    if (item != null) {
      return ItemDetailSheet(key: ValueKey('item-${item.id}'), item: item, onClose: _closeSheet);
    }
    switch (_sheet) {
      case _MenuSheet.info:
        return InfoSheet(key: const ValueKey('info'), data: data, onClose: _closeSheet);
      case _MenuSheet.branches:
        return BranchSheet(
          key: const ValueKey('branches'),
          data: data,
          onClose: _closeSheet,
          onSelect: (branch) {
            _closeSheet();
            if (branch.slug != data.branch.slug) widget.onSelectBranch?.call(branch);
          },
        );
      case _MenuSheet.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final derived = _derive();
    final look = MenuLook.from(
      data.business,
      bangla: _bangla,
      baseText: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
    );
    final palette = look.palette;

    final activeRoot = derived.roots.any((root) => root.id == _root) ? _root : null;
    final sections = buildSections(
      data,
      bangla: _bangla,
      query: _query,
      filters: _filters,
      onlyAvailable: _onlyAvailable,
    );
    final visible = activeRoot == null ? sections : [for (final s in sections) if (s.rootId == activeRoot) s];
    final narrowed = _query.trim().isNotEmpty || _filters.isNotEmpty || _onlyAvailable;
    final showRails = !narrowed && activeRoot == null && derived.rails.isNotEmpty;
    final showFilters = derived.filters.isNotEmpty || derived.hasUnavailable;
    final bottomInset = widget.embedded ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final switchBranches = data.hasMultipleBranches && widget.onSelectBranch != null;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _headerKey,
          child: MenuHeader(
            data: data,
            onLanguage: _setLanguage,
            onInfo: () => setState(() => _sheet = _MenuSheet.info),
            onBranches: switchBranches ? () => setState(() => _sheet = _MenuSheet.branches) : null,
          ),
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: MenuControlsDelegate(
          style: look,
          controller: _search,
          query: _query,
          onQuery: (value) => setState(() => _query = value),
          roots: derived.roots,
          selectedRoot: activeRoot,
          onRoot: _selectRoot,
        ),
      ),
      if (showFilters)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DietaryFilterRow(
              filters: derived.filters,
              selected: _filters,
              onToggle: _toggleFilter,
              onlyAvailable: _onlyAvailable,
              onOnlyAvailable: (value) => setState(() => _onlyAvailable = value),
            ),
          ),
        ),
      if (showRails)
        SliverToBoxAdapter(
          child: HighlightsRails(rails: derived.rails, onOpen: (item) => setState(() => _item = item)),
        ),
      if (narrowed && visible.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              _resultCount(countItems(visible)),
              style: look.text(13, color: palette.muted),
            ),
          ),
        ),
      if (visible.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyResults(hasDishes: data.items.isNotEmpty, onClear: narrowed || activeRoot != null ? _clearFilters : null),
        ),
      for (final section in visible) ..._sectionSlivers(section, look),
      SliverToBoxAdapter(child: SizedBox(height: 40 + bottomInset)),
    ];

    return MenuScope(
      style: look,
      child: PopScope(
        canPop: !_hasSheet,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSheet();
        },
        child: Material(
          color: palette.paper,
          child: MenuSheetHost(
            sheet: _sheetWidget(data),
            onDismiss: _closeSheet,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: slivers,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resultCount(int count) {
    final n = _bangla ? toBanglaDigits('$count') : '$count';
    if (_bangla) return '$nটি খাবার পাওয়া গেছে';
    return count == 1 ? '1 dish found' : '$n dishes found';
  }

  List<Widget> _sectionSlivers(MenuSection section, MenuLook look) {
    final palette = look.palette;
    final grid = look.isGrid;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.parentTitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(section.parentTitle!, style: look.text(12.5, weight: FontWeight.w700, color: palette.muted)),
                ),
              Text(section.title, style: look.text(20, weight: FontWeight.w800, height: 1.25)),
              if (section.description != null) ...[
                const SizedBox(height: 4),
                Text(section.description!, style: look.text(13.5, color: palette.muted, height: 1.45)),
              ],
            ],
          ),
        ),
      ),
      if (grid)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final available = constraints.crossAxisExtent;
              final columns = available >= 640 ? 3 : 2;
              final column = (available - spacing * (columns - 1)) / columns;
              // Card padding, a 4:3 picture, then room for name, price and tags.
              final extent = 20 + (column - 20) * 3 / 4 + 10 + 124;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: extent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = section.items[index];
                    return MenuItemCard(item: item, grid: true, onTap: () => setState(() => _item = item));
                  },
                  childCount: section.items.length,
                ),
              );
            },
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = section.items[index];
              return MenuItemCard(item: item, onTap: () => setState(() => _item = item));
            },
          ),
        ),
    ];
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.hasDishes, required this.onClear});

  final bool hasDishes;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final title = hasDishes
        ? (bangla ? 'কোনো খাবার মেলেনি' : 'No dishes match')
        : (bangla ? 'মেনুতে এখনো খাবার নেই' : 'No dishes on the menu yet');
    final message = hasDishes
        ? (bangla ? 'অন্য শব্দে খুঁজুন বা ফিল্টার সরান।' : 'Try another word or remove a filter.')
        : (bangla ? 'রেস্টুরেন্ট শীঘ্রই খাবার যোগ করবে।' : 'The restaurant will add dishes soon.');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: menu.palette.muted),
          const SizedBox(height: 14),
          Text(title, style: menu.text(17, weight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: menu.text(14, color: menu.palette.muted), textAlign: TextAlign.center),
          if (onClear != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: menu.accent,
                side: BorderSide(color: menu.palette.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(bangla ? 'ফিল্টার মুছুন' : 'Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}
