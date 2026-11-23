import 'package:flutter/material.dart';

import '../../../core/logic/hours.dart';
import '../../../core/logic/menu_catalog.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../schedule_logic.dart';
import 'editor_common.dart';

/// One availability window: weekdays, times, an optional date range and a
/// label. Controlled by the parent.
class ScheduleWindowCard extends StatefulWidget {
  const ScheduleWindowCard({
    super.key,
    required this.number,
    required this.window,
    required this.activeNow,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
  });

  /// Position shown in the title, starting at 1.
  final int number;
  final ItemSchedule window;

  /// This window alone lets customers order right now.
  final bool activeNow;
  final ValueChanged<ItemSchedule> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  State<ScheduleWindowCard> createState() => _ScheduleWindowCardState();
}

class _ScheduleWindowCardState extends State<ScheduleWindowCard> {
  final TextEditingController _label = TextEditingController();

  ItemSchedule get _w => widget.window;

  @override
  void initState() {
    super.initState();
    _label.text = _w.label ?? '';
  }

  @override
  void didUpdateWidget(covariant ScheduleWindowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing the text notifies the surrounding Form, which must not happen
    // while building, so it runs after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setTextIfChanged(_label, _w.label ?? '');
    });
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _toggleDay(int day) {
    final effective = _w.weekdays.isEmpty
        ? [for (final d in weekOrderBangladesh) d]
        : _w.weekdays;
    var next = toggleWeekday(effective, day);
    if (next.isEmpty) {
      showToast(context, 'Keep at least one day selected.');
      return;
    }
    if (next.length == 7) next = const [];
    widget.onChanged(_w.copyWith(weekdays: next));
  }

  void _setAllDay(bool allDay) {
    if (allDay) {
      widget.onChanged(_w.copyWith(clearTimes: true));
    } else {
      widget.onChanged(_w.copyWith(startTime: '10:00', endTime: '22:00'));
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final current = parseClock(start ? _w.startTime : _w.endTime) ??
        ClockTime(start ? 10 : 22, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? 'Available from' : 'Available until',
    );
    if (picked == null || !mounted) return;
    final text = clockToDb(ClockTime(picked.hour, picked.minute));
    widget.onChanged(
      start ? _w.copyWith(startTime: text) : _w.copyWith(endTime: text),
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.tryParse(_w.startDate ?? '');
    final end = DateTime.tryParse(_w.endDate ?? '');
    DateTimeRange? initial;
    if (start != null && end != null && !end.isBefore(start)) {
      initial = DateTimeRange(start: start, end: end);
    }
    final first = (start != null && start.isBefore(today)) ? start : today;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDateRange: initial,
      helpText: 'Dates when this window applies',
    );
    if (range == null || !mounted) return;
    widget.onChanged(
      _w.copyWith(startDate: dateToDb(range.start), endDate: dateToDb(range.end)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final w = _w;
    final hasTimes = hasTimeRange(w);
    final everyDay = isEveryDay(w.weekdays);
    final selectedDays = w.weekdays.isEmpty
        ? {for (final d in weekOrderBangladesh) d}
        : w.weekdays.toSet();
    final hasDates = w.startDate != null || w.endDate != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(
          color: widget.activeNow
              ? context.colors.primary.withValues(alpha: 0.5)
              : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (w.label ?? '').trim().isEmpty
                                ? 'Window ${widget.number}'
                                : w.label!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.titleSmall,
                          ),
                        ),
                        if (widget.activeNow) ...[
                          const SizedBox(width: Sp.sm),
                          const StatusPill('Active now', tone: PillTone.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        windowSummary(w),
                        key: ValueKey(windowSummary(w)),
                        style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Duplicate window',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDuplicate,
                icon: Icon(Icons.copy_rounded, size: 19, color: palette.muted),
              ),
              IconButton(
                tooltip: 'Delete window',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDelete,
                icon: Icon(Icons.delete_outline_rounded, size: 21, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Text('Days', style: context.textStyles.labelLarge),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in weekOrderBangladesh)
                FilterChip(
                  label: Text(weekdayName(day, short: true)),
                  selected: selectedDays.contains(day),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _toggleDay(day),
                ),
              ActionChip(
                avatar: Icon(
                  everyDay ? Icons.check_rounded : Icons.event_repeat_rounded,
                  size: 16,
                ),
                label: const Text('Every day'),
                visualDensity: VisualDensity.compact,
                onPressed: everyDay ? null : () => widget.onChanged(w.copyWith(weekdays: const [])),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          SwitchRow(
            title: 'All day',
            subtitle: hasTimes ? 'Turn on to ignore the times below.' : 'Available from opening to closing.',
            value: !hasTimes,
            onChanged: _setAllDay,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: hasTimes
                ? Padding(
                    padding: const EdgeInsets.only(top: Sp.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TimeButton(
                                label: 'From',
                                value: formatClock(w.startTime),
                                onTap: () => _pickTime(start: true),
                              ),
                            ),
                            const SizedBox(width: Sp.md),
                            Expanded(
                              child: _TimeButton(
                                label: 'Until',
                                value: formatClock(w.endTime),
                                onTap: () => _pickTime(start: false),
                              ),
                            ),
                          ],
                        ),
                        if (isOvernight(w)) ...[
                          const SizedBox(height: Sp.sm),
                          EditorNote(
                            'This window runs past midnight and ends at ${formatClock(w.endTime)} the next day.',
                          ),
                        ] else if (isAllDayByEqualTimes(w)) ...[
                          const SizedBox(height: Sp.sm),
                          const EditorNote(
                            'The same start and end time means all day.',
                            tone: PillTone.warning,
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    hasDates
                        ? _dateText(w.startDate, w.endDate)
                        : 'Limit to a date range',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (hasDates)
                IconButton(
                  tooltip: 'Remove date range',
                  onPressed: () => widget.onChanged(
                    _w.copyWith(clearStartDate: true, clearEndDate: true),
                  ),
                  icon: Icon(Icons.close_rounded, color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: Sp.md),
          AppTextField(
            label: 'Label',
            optional: true,
            controller: _label,
            hint: 'e.g. Lunch menu',
            maxLength: scheduleLabelMaxLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) => widget.onChanged(_w.copyWith(label: text)),
          ),
        ],
      ),
    );
  }
}

String _dateText(String? start, String? end) {
  if (start != null && end != null) return '$start to $end';
  if (start != null) return 'From $start';
  return 'Until ${end ?? ''}';
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(Rad.control),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.control),
          border: Border.all(color: palette.lineStrong),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, size: 18, color: palette.muted),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textStyles.labelSmall?.copyWith(color: palette.muted),
                  ),
                  Text(value, style: context.textStyles.titleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
