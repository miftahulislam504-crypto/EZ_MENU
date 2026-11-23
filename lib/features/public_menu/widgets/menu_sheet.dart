import 'package:flutter/material.dart';

import 'menu_scope.dart';

/// Lays a sheet over the menu inside the menu's own area, so it also works
/// inside the phone frame of the dashboard preview (a normal bottom sheet
/// would cover the whole screen). Set [sheet] to open it and to null to close
/// it; the sheet slides in and out.
class MenuSheetHost extends StatefulWidget {
  const MenuSheetHost({super.key, required this.child, required this.sheet, required this.onDismiss});

  final Widget child;

  /// The sheet to show, or null when none is open. Give each sheet its own key
  /// so a new one replaces the old one.
  final Widget? sheet;
  final VoidCallback onDismiss;

  @override
  State<MenuSheetHost> createState() => _MenuSheetHostState();
}

class _MenuSheetHostState extends State<MenuSheetHost> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Widget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.sheet;
    if (widget.sheet != null) _controller.value = 1;
  }

  @override
  void didUpdateWidget(MenuSheetHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.sheet;
    if (next != null) {
      _shown = next;
      _controller.forward();
    } else if (oldWidget.sheet != null) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final open = widget.sheet != null;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            if (_controller.isDismissed) return const SizedBox.shrink();
            final value = _curve.value;
            return Positioned.fill(
              child: IgnorePointer(
                ignoring: !open,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDismiss,
                        child: ColoredBox(color: Colors.black.withValues(alpha: 0.42 * value)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FractionalTranslation(
                            translation: Offset(0, 1 - value),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * 0.92,
                                maxWidth: 640,
                              ),
                              child: Material(
                                color: menu.palette.paper,
                                elevation: 0,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                clipBehavior: Clip.antiAlias,
                                child: _shown ?? const SizedBox.shrink(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Grip, title and close button above scrolling content, with an optional
/// bar that stays at the bottom. Dragging the top down closes the sheet.
class MenuSheetFrame extends StatelessWidget {
  const MenuSheetFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.body,
    this.footer,
  });

  final String title;
  final VoidCallback onClose;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 320) onClose();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: menu.palette.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: menu.text(17, weight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Semantics(
                      button: true,
                      label: menu.bangla ? 'বন্ধ করুন' : 'Close',
                      child: IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, color: menu.palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Flexible(child: body),
        if (footer != null) footer!,
      ],
    );
  }
}
