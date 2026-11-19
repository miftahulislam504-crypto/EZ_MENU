import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonKind { primary, secondary, tonal, danger, text }

/// The one button used across the app.
///
///  * primary   - the main action of a screen (filled green)
///  * secondary - an alternative action (outlined)
///  * tonal     - a gentle action (pale green)
///  * danger    - destructive actions (red)
///  * text      - low emphasis
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Stretches to the full available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final enabled = onPressed != null && !loading;

    Color foreground;
    switch (kind) {
      case AppButtonKind.primary:
        foreground = scheme.onPrimary;
      case AppButtonKind.danger:
        foreground = scheme.onError;
      case AppButtonKind.tonal:
        foreground = scheme.onPrimaryContainer;
      case AppButtonKind.secondary:
        foreground = scheme.onSurface;
      case AppButtonKind.text:
        foreground = scheme.primary;
    }

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final VoidCallback? handler = enabled ? onPressed : null;
    Widget button;
    switch (kind) {
      case AppButtonKind.primary:
        button = FilledButton(onPressed: handler, child: child);
      case AppButtonKind.secondary:
        button = OutlinedButton(onPressed: handler, child: child);
      case AppButtonKind.tonal:
        button = FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
          ),
          child: child,
        );
      case AppButtonKind.danger:
        button = FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: child,
        );
      case AppButtonKind.text:
        button = TextButton(onPressed: handler, child: child);
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
