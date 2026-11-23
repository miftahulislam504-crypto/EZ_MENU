import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../availability_logic.dart';
import 'menu_ui.dart';

/// One dish on the availability screen: photo, name, a line saying whether it
/// can be ordered, and a large Sold out switch. With [onRestock] the switch is
/// replaced by a one-tap "Back in stock" button.
class AvailabilityRow extends StatelessWidget {
  const AvailabilityRow({
    super.key,
    required this.entry,
    required this.now,
    required this.showScope,
    required this.onToggle,
    this.busy = false,
    this.categoryName,
    this.onRestock,
  });

  final StockEntry entry;
  final DateTime now;

  /// Say "This branch only" or "All branches" under sold-out dishes.
  final bool showScope;

  /// Called with true to mark sold out and false to bring it back.
  final ValueChanged<bool> onToggle;

  /// A write for this dish is still in flight.
  final bool busy;

  /// Shown in front of the caption when the list is not grouped.
  final String? categoryName;

  final VoidCallback? onRestock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = entry.item;
    final status = entry.status;
    final soldOut = status.soldOut;
    final caption = stockCaption(status, now, showScope: showScope);
    final hasBoth = (item.nameEn ?? '').trim().isNotEmpty &&
        (item.nameBn ?? '').trim().isNotEmpty;

    Widget trailing;
    if (onRestock != null) {
      trailing = AppButton(
        label: 'Back in stock',
        kind: AppButtonKind.tonal,
        icon: Icons.replay_rounded,
        onPressed: busy ? null : onRestock,
      );
    } else {
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: soldOut,
            onChanged: busy ? null : onToggle,
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? palette.danger
                  : palette.line,
            ),
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : palette.lineStrong,
            ),
          ),
          Text(
            'Sold out',
            style: context.textStyles.labelSmall?.copyWith(
              color: soldOut ? palette.danger : palette.muted,
              fontWeight: soldOut ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Semantics(
      container: true,
      label: '${item.displayName}, ${soldOut ? 'sold out' : 'available'}',
      child: InkWell(
        onTap: busy || onRestock != null ? null : () => onToggle(!soldOut),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          color: soldOut
              ? palette.dangerSoft.withValues(alpha: 0.35)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.lg,
            vertical: Sp.md,
          ),
          child: Row(
            children: [
              MenuThumb(url: item.coverImage, size: 48, dimmed: soldOut),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall,
                    ),
                    if (hasBoth)
                      Text(
                        item.nameBn!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        categoryName == null ? caption : '$categoryName  -  $caption',
                        key: ValueKey(caption),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: soldOut ? palette.danger : palette.muted,
                          fontWeight: soldOut ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.md),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
