import 'package:flutter/material.dart';

import '../../../core/logic/hours.dart';
import '../../../core/widgets/widgets.dart';
import '../hours_editing.dart';

/// Edits a whole week of opening hours. Controlled: it shows [value] and
/// reports every change through [onChanged].
class WeeklyHoursEditor extends StatelessWidget {
  const WeeklyHoursEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WeekDraft value;
  final ValueChanged<WeekDraft> onChanged;

  void _setDay(int day, List<DraftPeriod> periods) {
    final next = copyWeek(value);
    next[day] = sortPeriods(periods);
    onChanged(next);
  }

  Future<void> _copyDay(BuildContext context, int from) async {
    final targets = await showAppSheet<Set<int>>(
      context,
      title: 'Copy ${weekdayName(from)} hours to',
      builder: (sheetContext) => _CopyTargets(from: from),
    );
    if (targets == null || targets.isEmpty) return;
    onChanged(copyDayTo(value, from, targets));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [
            ActionChip(
              label: const Text('Same every day'),
              avatar: const Icon(Icons.today_outlined, size: 18),
              onPressed: () => onChanged(presetEveryDay()),
            ),
            ActionChip(
              label: const Text('Closed on Friday'),
              avatar: const Icon(Icons.event_busy_outlined, size: 18),
              onPressed: () => onChanged(presetClosedOn({5})),
            ),
            ActionChip(
              label: const Text('Closed on Sunday'),
              avatar: const Icon(Icons.event_busy_outlined, size: 18),
              onPressed: () => onChanged(presetClosedOn({7})),
            ),
          ],
        ),
        const SizedBox(height: Sp.lg),
        for (final day in weekOrderBangladesh)
          DayHoursCard(
            title: weekdayName(day),
            periods: value[day] ?? const <DraftPeriod>[],
            onChanged: (periods) => _setDay(day, periods),
            onCopy: () => _copyDay(context, day),
          ),
      ],
    );
  }
}

/// One day's opening switch and its service periods. Also used for the hours
/// of a special day.
class DayHoursCard extends StatelessWidget {
  const DayHoursCard({
    super.key,
    required this.title,
    required this.periods,
    required this.onChanged,
    this.onCopy,
    this.showSwitch = true,
  });

  final String title;
  final List<DraftPeriod> periods;
  final ValueChanged<List<DraftPeriod>> onChanged;

  /// Adds a "Copy to other days" button when set.
  final VoidCallback? onCopy;

  /// Hide the open and closed switch when the day is always open.
  final bool showSwitch;

  bool get _open => periods.isNotEmpty;

  Future<void> _pickTime(
    BuildContext context,
    int index, {
    required bool opening,
  }) async {
    final period = periods[index];
    final current = parseClock(opening ? period.open : period.close);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? 10,
        minute: current?.minute ?? 0,
      ),
      helpText: opening ? 'Opening time' : 'Closing time',
    );
    if (picked == null) return;
    final text = clockToDb(ClockTime(picked.hour, picked.minute));
    final next = List<DraftPeriod>.of(periods);
    next[index] = opening
        ? period.copyWith(open: text)
        : period.copyWith(close: text);
    onChanged(next);
  }

  Future<void> _editLabel(BuildContext context, int index) async {
    final period = periods[index];
    final en = TextEditingController(text: period.labelEn);
    final bn = TextEditingController(text: period.labelBn);
    final saved = await showAppSheet<bool>(
      context,
      title: 'Name this period',
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
        child: Column(
          children: [
            AppTextField(
              label: 'Name in English',
              controller: en,
              hint: 'Lunch',
              optional: true,
            ),
            const SizedBox(height: Sp.md),
            AppTextField(
              label: 'Name in Bangla',
              controller: bn,
              optional: true,
            ),
            const SizedBox(height: Sp.lg),
            AppButton(
              label: 'Save name',
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final next = List<DraftPeriod>.of(periods);
      next[index] = period.copyWith(
        labelEn: en.text.trim(),
        labelBn: bn.text.trim(),
      );
      onChanged(next);
    }
    en.dispose();
    bn.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final problems = validateDay(periods);
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.md),
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(
          color: problems.isEmpty ? palette.line : palette.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.textStyles.titleMedium),
              ),
              if (showSwitch) ...[
                Text(
                  _open ? 'Open' : 'Closed',
                  style: context.textStyles.labelMedium?.copyWith(
                    color: _open ? palette.success : palette.muted,
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Switch(
                  value: _open,
                  onChanged: (value) => onChanged(
                    value ? [defaultPeriod] : const <DraftPeriod>[],
                  ),
                ),
              ],
            ],
          ),
          for (var i = 0; i < periods.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Row(
                children: [
                  _TimeButton(
                    text: formatClock(periods[i].open),
                    onTap: () => _pickTime(context, i, opening: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'to',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                  _TimeButton(
                    text: formatClock(periods[i].close),
                    onTap: () => _pickTime(context, i, opening: false),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: InkWell(
                      onTap: () => _editLabel(context, i),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          periods[i].labelEn.isNotEmpty
                              ? periods[i].labelEn
                              : (periods[i].labelBn.isNotEmpty
                                    ? periods[i].labelBn
                                    : (periods[i].isOvernight
                                          ? 'Past midnight'
                                          : 'Add name')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove period',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final next = List<DraftPeriod>.of(periods)..removeAt(i);
                      onChanged(next);
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          if (problems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(
                problems.first,
                style: context.textStyles.bodySmall?.copyWith(
                  color: palette.danger,
                ),
              ),
            ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final last = periods.last;
                      final start = parseClock(last.close);
                      final hour = ((start?.hour ?? 18) + 1) % 24;
                      onChanged([
                        ...periods,
                        DraftPeriod(
                          open: clockToDb(ClockTime(hour, 0)),
                          close: clockToDb(ClockTime((hour + 3) % 24, 0)),
                        ),
                      ]);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add period'),
                  ),
                  if (onCopy != null)
                    TextButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Copy to other days'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rad.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Rad.control),
          border: Border.all(color: context.palette.line),
        ),
        child: Text(text, style: context.textStyles.titleSmall),
      ),
    );
  }
}

class _CopyTargets extends StatefulWidget {
  const _CopyTargets({required this.from});

  final int from;

  @override
  State<_CopyTargets> createState() => _CopyTargetsState();
}

class _CopyTargetsState extends State<_CopyTargets> {
  final Set<int> _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final day in weekOrderBangladesh)
                if (day != widget.from)
                  FilterChip(
                    label: Text(weekdayName(day)),
                    selected: _selected.contains(day),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _selected.add(day);
                      } else {
                        _selected.remove(day);
                      }
                    }),
                  ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          AppButton(
            label: 'Copy hours',
            expand: true,
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(Set<int>.of(_selected)),
          ),
        ],
      ),
    );
  }
}
