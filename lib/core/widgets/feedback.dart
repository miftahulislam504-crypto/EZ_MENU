import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'buttons.dart';

/// Brief message at the bottom of the screen.
void showToast(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.colors.error : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
}

/// Asks the person to confirm. Returns true only when they confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        AppButton(
          label: confirmLabel,
          kind: destructive ? AppButtonKind.danger : AppButtonKind.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Modal bottom sheet with a title and keyboard-safe padding.
///
/// [builder] must return a non-scrolling widget (for example a Column with
/// mainAxisSize.min); the sheet scrolls it when it is too tall.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.sm),
                  child: Text(title, style: sheetContext.textStyles.titleLarge),
                ),
              builder(sheetContext),
            ],
          ),
        ),
      );
    },
  );
}

/// Centred spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (message != null) ...[
            const SizedBox(height: Sp.md),
            Text(
              message!,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nothing here yet: say why, and offer the next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: context.colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text(
                title,
                style: context.textStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Sp.xl),
                AppButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Something failed: say what, and offer a retry.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Could not load this',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.dangerSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 30,
                  color: palette.danger,
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text(
                title,
                style: context.textStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: Sp.xl),
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  kind: AppButtonKind.secondary,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum PillTone { neutral, success, warning, danger, info }

/// Small coloured label such as Sold out, Hidden or Open now.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    Color background;
    Color foreground;
    switch (tone) {
      case PillTone.success:
        background = palette.successSoft;
        foreground = palette.success;
      case PillTone.warning:
        background = palette.warningSoft;
        foreground = palette.warning;
      case PillTone.danger:
        background = palette.dangerSoft;
        foreground = palette.danger;
      case PillTone.info:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
      case PillTone.neutral:
        background = scheme.surfaceContainerHigh;
        foreground = palette.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey pulsing block shown while content loads. Stays still when the system
/// asks for reduced motion.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = context.palette.line;
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (reduced) return box;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: box,
    );
  }
}

/// Placeholder rows for a list that is still loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Sp.lg),
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: Sp.md),
      itemBuilder: (_, __) => const Row(
        children: [
          SkeletonBox(width: 52, height: 52, radius: 12),
          SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs [action], shows an error toast on failure. Returns true on success.
Future<bool> runWithToast(
  BuildContext context,
  Future<void> Function() action, {
  required String Function(Object error) onError,
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted)
      showToast(context, successMessage);
    return true;
  } catch (error) {
    if (context.mounted) showToast(context, onError(error), isError: true);
    return false;
  }
}
