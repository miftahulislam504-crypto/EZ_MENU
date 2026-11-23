import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

/// Shows a snackbar with an Undo action. [onUndo] runs when it is tapped; a
/// failure is shown as an error toast.
void showUndoToast(
  BuildContext context,
  String message, {
  required Future<void> Function() onUndo,
  required String Function(Object error) onError,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await onUndo();
            } catch (error) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(onError(error)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
            }
          },
        ),
      ),
    );
}

/// Square picture of a category or dish with a quiet icon fallback.
class MenuThumb extends StatelessWidget {
  const MenuThumb({
    super.key,
    this.url,
    this.icon,
    this.size = 52,
    this.radius = 12,
    this.dimmed = false,
  });

  final String? url;
  final IconData? icon;
  final double size;
  final double radius;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (url != null && url!.isNotEmpty) {
      child = NetworkImageBox(
        url: url,
        width: size,
        height: size,
        radius: radius,
        cacheWidth: size.round(),
        placeholderIcon: icon ?? Icons.restaurant_menu_rounded,
      );
    } else {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          icon ?? Icons.restaurant_menu_rounded,
          size: size * 0.46,
          color: context.colors.onPrimaryContainer,
        ),
      );
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.45 : 1,
      child: child,
    );
  }
}

/// A small tappable count card used on the menu overview.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.tone = PillTone.neutral,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Color accent;
    Color soft;
    switch (tone) {
      case PillTone.danger:
        accent = palette.danger;
        soft = palette.dangerSoft;
      case PillTone.warning:
        accent = palette.warning;
        soft = palette.warningSoft;
      case PillTone.success:
        accent = palette.success;
        soft = palette.successSoft;
      default:
        accent = context.colors.onPrimaryContainer;
        soft = context.colors.primaryContainer;
    }
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(Rad.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.panel),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.panel),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: context.textStyles.titleLarge),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
