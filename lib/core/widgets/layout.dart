import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centres content and caps its width on large screens.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Standard screen: app bar, width-limited body, optional pinned bottom bar.
///
/// With [scroll] true (default) [body] is wrapped in a scroll view with
/// [padding]. Set [scroll] false when [body] is itself a list or manages its
/// own padding.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.scroll = true,
    this.maxWidth = 960,
    this.padding = const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
    this.floatingActionButton,
    this.bottomBar,
    this.onRefresh,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final bool scroll;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;

  /// Pinned below the content, usually a [StickyActionBar].
  final Widget? bottomBar;

  /// Enables pull to refresh (needs [scroll] true).
  final Future<void> Function()? onRefresh;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (scroll) {
      content = SingleChildScrollView(
        physics: onRefresh == null
            ? null
            : const AlwaysScrollableScrollPhysics(),
        padding: padding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: body,
      );
      if (onRefresh != null) {
        content = RefreshIndicator(onRefresh: onRefresh!, child: content);
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: leading,
        title: subtitle == null
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    subtitle!,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
        actions: [
          ...?actions,
          const SizedBox(width: Sp.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: content,
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// A heading above a white panel that holds related fields.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.gap = Sp.lg,
    this.padding = const EdgeInsets.all(Sp.lg),
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  /// Vertical space between [children].
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(SizedBox(height: gap));
      spaced.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: Sp.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title!, style: context.textStyles.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(Rad.panel),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: spaced,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white panel of rows separated by hairlines. Use with [ListRow].
class ListGroup extends StatelessWidget {
  const ListGroup({
    super.key,
    required this.children,
    this.title,
    this.trailing,
  });

  final List<Widget> children;
  final String? title;

  /// Shown at the right of the title, e.g. a small action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0)
        rows.add(Divider(height: 1, indent: Sp.lg, color: palette.line));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: Sp.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: context.textStyles.titleMedium),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(Rad.panel),
              border: Border.all(color: palette.line),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

/// One row inside a [ListGroup].
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.dense = false,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Adds a right chevron when there is no [trailing].
  final bool showChevron;
  final bool dense;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Sp.lg,
          vertical: dense ? Sp.sm : Sp.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: Sp.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Sp.sm),
              trailing!,
            ] else if (showChevron || onTap != null) ...[
              const SizedBox(width: Sp.sm),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round icon used as a [ListRow.leading].
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = 40,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(size / 3.2),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: color ?? context.colors.onPrimaryContainer,
      ),
    );
  }
}

/// A section heading with an optional action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(
        children: [
          Expanded(child: Text(text, style: context.textStyles.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bottom bar that holds the main buttons of a form.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.child, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
