import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../schedule_logic.dart';
import 'editor_common.dart';
import 'schedule_window_card.dart';

/// Availability windows of a dish (Feature Plan 4.4). An empty list means the
/// dish is always available; several windows are alternatives. Controlled by
/// the parent, which supplies the section card and heading.
class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({
    super.key,
    required this.windows,
    required this.onChanged,
  });

  final List<ItemSchedule> windows;
  final ValueChanged<List<ItemSchedule>> onChanged;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  /// One stable key per window, so a card keeps its state while others change.
  final List<int> _keys = [];
  int _seq = 0;

  List<ItemSchedule> get _windows => widget.windows;

  @override
  void initState() {
    super.initState();
    _fitKeys();
  }

  @override
  void didUpdateWidget(covariant ScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitKeys();
  }

  void _fitKeys() {
    while (_keys.length < _windows.length) {
      _keys.add(_seq++);
    }
    while (_keys.length > _windows.length) {
      _keys.removeLast();
    }
  }

  void _set(List<ItemSchedule> next) => widget.onChanged(next);

  void _add(ItemSchedule window) {
    _keys.add(_seq++);
    _set([..._windows, window]);
  }

  void _replace(int index, ItemSchedule window) {
    _set([
      for (var i = 0; i < _windows.length; i++) i == index ? window : _windows[i],
    ]);
  }

  void _duplicate(int index) {
    final source = _windows[index];
    final copy = ItemSchedule(
      weekdays: source.weekdays,
      startTime: source.startTime,
      endTime: source.endTime,
      startDate: source.startDate,
      endDate: source.endDate,
      label: source.label,
    );
    _keys.insert(index + 1, _seq++);
    _set([
      ..._windows.sublist(0, index + 1),
      copy,
      ..._windows.sublist(index + 1),
    ]);
  }

  void _delete(int index) {
    _keys.removeAt(index);
    _set([
      for (var i = 0; i < _windows.length; i++)
        if (i != index) _windows[i],
    ]);
  }

  Widget _presets() {
    return Wrap(
      spacing: Sp.sm,
      runSpacing: Sp.sm,
      children: [
        for (final preset in SchedulePreset.values)
          ActionChip(
            avatar: const Icon(Icons.bolt_rounded, size: 16),
            label: Text(schedulePresetLabels[preset]!),
            onPressed: () => _add(presetWindow(preset)),
          ),
      ],
    );
  }

  Widget _statusLine(BuildContext context, bool now) {
    final palette = context.palette;
    return Row(
      children: [
        StatusPill(
          now ? 'Available now' : 'Not available now',
          tone: now ? PillTone.success : PillTone.warning,
          icon: now ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
        ),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Text(
            'Based on this device time.',
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final windows = _windows;
    final now = DateTime.now();
    final problems = validateSchedules(windows);

    if (windows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(Rad.panel),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.schedule_rounded, size: 40),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Always available', style: context.textStyles.titleSmall),
                      Text(
                        'Add a window to offer this dish only at certain times, for example breakfast or weekends.',
                        style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.lg),
            Text('Quick add', style: context.textStyles.labelLarge),
            const SizedBox(height: Sp.sm),
            _presets(),
            const SizedBox(height: Sp.md),
            AppButton(
              label: 'Add availability window',
              icon: Icons.add_rounded,
              kind: AppButtonKind.tonal,
              onPressed: () => _add(const ItemSchedule(startTime: '10:00', endTime: '22:00')),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusLine(context, availableByScheduleNow(windows, now)),
        const SizedBox(height: Sp.sm),
        Text(
          windows.length > 1
              ? 'Customers can order the dish when any one of these windows is open.'
              : 'Customers can order the dish only while this window is open.',
          style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Sp.md),
        for (var i = 0; i < windows.length; i++)
          Padding(
            key: ValueKey(_keys[i]),
            padding: const EdgeInsets.only(bottom: Sp.md),
            child: ScheduleWindowCard(
              number: i + 1,
              window: windows[i],
              activeNow: availableByScheduleNow([windows[i]], now),
              onChanged: (window) => _replace(i, window),
              onDuplicate: () => _duplicate(i),
              onDelete: () => _delete(i),
            ),
          ),
        if (problems.isNotEmpty) ...[
          EditorProblems(problems),
          const SizedBox(height: Sp.md),
        ],
        Text('Add another window', style: context.textStyles.labelLarge),
        const SizedBox(height: Sp.sm),
        _presets(),
        const SizedBox(height: Sp.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Add availability window',
            icon: Icons.add_rounded,
            kind: AppButtonKind.tonal,
            onPressed: () => _add(const ItemSchedule(startTime: '10:00', endTime: '22:00')),
          ),
        ),
        const SizedBox(height: Sp.sm),
        TextButton.icon(
          onPressed: () => _set(const []),
          icon: const Icon(Icons.all_inclusive_rounded, size: 18),
          label: const Text('Make always available'),
        ),
      ],
    );
  }
}
