import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/widgets.dart';

/// A number as plain input text: 250, 99.5. Nothing for null.
String plainNumber(num? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Lets only digits (ASCII or Bangla), a dot and commas through.
final List<TextInputFormatter> moneyInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.,]')),
];

const TextInputType moneyKeyboard = TextInputType.numberWithOptions(decimal: true);

/// A calm boxed message with an icon.
class EditorNote extends StatelessWidget {
  const EditorNote(this.text, {super.key, this.tone = PillTone.info, this.icon});

  final String text;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    Color background;
    Color foreground;
    IconData defaultIcon;
    switch (tone) {
      case PillTone.danger:
        background = palette.dangerSoft;
        foreground = palette.danger;
        defaultIcon = Icons.error_outline_rounded;
      case PillTone.warning:
        background = palette.warningSoft;
        foreground = palette.warning;
        defaultIcon = Icons.info_outline_rounded;
      case PillTone.success:
        background = palette.successSoft;
        foreground = palette.success;
        defaultIcon = Icons.check_circle_outline_rounded;
      default:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        defaultIcon = Icons.info_outline_rounded;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Rad.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? defaultIcon, size: 17, color: foreground),
          ),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Several problems in one box, one per line.
class EditorProblems extends StatelessWidget {
  const EditorProblems(this.problems, {super.key});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) return const SizedBox.shrink();
    return EditorNote(
      problems.join('\n'),
      tone: PillTone.warning,
      icon: Icons.warning_amber_rounded,
    );
  }
}

/// A label with a minus button, the current value and a plus button.
class EditorStepper extends StatelessWidget {
  const EditorStepper({
    super.key,
    required this.label,
    required this.valueText,
    required this.onDecrease,
    required this.onIncrease,
    this.helper,
  });

  final String label;
  final String valueText;
  final String? helper;

  /// Null disables the button.
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.textStyles.titleSmall),
              if (helper != null)
                Text(
                  helper!,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: 'Decrease',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 64,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              valueText,
              key: ValueKey(valueText),
              textAlign: TextAlign.center,
              style: context.textStyles.titleSmall,
            ),
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: 'Increase',
          onPressed: onIncrease,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

/// Small round handle used to drag list rows.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index, this.size = 22});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.drag_indicator_rounded,
            size: size,
            color: context.palette.muted,
          ),
        ),
      ),
    );
  }
}

/// Moves one entry using the `onReorder` convention of ReorderableListView.
List<T> reorderList<T>(List<T> items, int oldIndex, int newIndex) {
  final next = List<T>.of(items);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final moved = next.removeAt(oldIndex);
  next.insert(target.clamp(0, next.length), moved);
  return next;
}

/// Sets controller text only when it differs, keeping the cursor otherwise.
void setTextIfChanged(TextEditingController controller, String text) {
  if (controller.text == text) return;
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
