import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/logic/hours.dart';
import '../../core/session/branch_status.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/controllers.dart';
import '../../core/widgets/widgets.dart';
import 'branch_repository.dart';
import 'hours_editing.dart';
import 'widgets/weekly_hours_editor.dart';

enum _Section { weekly, special, closure }

/// Weekly hours, special days and temporary closure of one branch.
class BranchHoursScreen extends ConsumerWidget {
  const BranchHoursScreen({super.key, required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final hours = ref.watch(branchHoursProvider(branchId));
    const title = 'Opening hours';

    Branch? branch;
    for (final b in branches.valueOrNull ?? const <Branch>[]) {
      if (b.id == branchId) branch = b;
    }

    if (branches.hasError && !branches.hasValue) {
      return AppPage(
        title: title,
        scroll: false,
        body: ErrorState(
          message: friendlyError(branches.error),
          onRetry: () => ref.invalidate(branchesProvider),
        ),
      );
    }
    if (hours.hasError && !hours.hasValue) {
      return AppPage(
        title: title,
        scroll: false,
        body: ErrorState(
          message: friendlyError(hours.error),
          onRetry: () => ref.invalidate(branchHoursProvider(branchId)),
        ),
      );
    }
    if (branch == null || !hours.hasValue) {
      if (branches.hasValue && branch == null) {
        return AppPage(
          title: title,
          scroll: false,
          body: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Branch not found',
            actionLabel: 'Back to branches',
            onAction: () => context.go(AppRoutes.branches),
          ),
        );
      }
      return const AppPage(title: title, scroll: false, body: LoadingView());
    }
    return _HoursBody(
      key: ValueKey(branchId),
      branch: branch,
      rows: hours.value ?? const <HoursRow>[],
    );
  }
}

class _HoursBody extends ConsumerStatefulWidget {
  const _HoursBody({super.key, required this.branch, required this.rows});

  final Branch branch;
  final List<HoursRow> rows;

  @override
  ConsumerState<_HoursBody> createState() => _HoursBodyState();
}

class _HoursBodyState extends ConsumerState<_HoursBody> {
  _Section _section = _Section.weekly;
  late WeekDraft _week;
  final _c = ControllerBag();
  bool _closed = false;
  DateTime? _until;
  String _outside = 'block_orders';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _week = weekFromRows(widget.rows.where((r) => r.isWeekly));
    _c.fill({
      'message_en': b.tempClosedMessageEn,
      'message_bn': b.tempClosedMessageBn,
    });
    _closed = b.tempClosed;
    _until = b.tempClosedUntil?.toLocal();
    _outside = b.outsideHoursBehavior;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _afterSave() {
    ref.invalidate(branchHoursProvider(widget.branch.id));
    ref.invalidate(branchStatusProvider(widget.branch.id));
    ref.refreshBranches();
  }

  Future<void> _saveWeekly() async {
    final problem = validateWeek(_week);
    if (problem != null) {
      showToast(context, problem, isError: true);
      return;
    }
    if (weekIsEmpty(_week)) {
      final ok = await confirmAction(
        context,
        title: 'Save with every day closed?',
        message:
            'Customers will see this branch as closed all week. Switch a day '
            'to open if that is a mistake.',
        confirmLabel: 'Save anyway',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    await runWithToast(
      context,
      () async {
        await ref
            .read(branchRepositoryProvider)
            .saveWeekly(widget.branch.id, _week);
        _afterSave();
      },
      onError: friendlyError,
      successMessage: 'Opening hours saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveClosure() async {
    setState(() => _saving = true);
    await runWithToast(
      context,
      () async {
        await ref
            .read(branchRepositoryProvider)
            .saveClosure(
              widget.branch.id,
              closed: _closed,
              messageEn: _c.nullable('message_en'),
              messageBn: _c.nullable('message_bn'),
              until: _until,
              outsideHoursBehavior: _outside,
            );
        _afterSave();
      },
      onError: friendlyError,
      successMessage: 'Saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _until ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Reopens on',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_until ?? now),
      helpText: 'Reopens at',
    );
    if (time == null || !mounted) return;
    setState(
      () => _until = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addSpecial() async {
    final added = await showAppSheet<bool>(
      context,
      title: 'Add a special day',
      builder: (sheetContext) => _SpecialDayForm(branchId: widget.branch.id),
    );
    if (added == true) _afterSave();
  }

  Future<void> _deleteSpecial(SpecialDay day) async {
    final ok = await confirmAction(
      context,
      title: 'Remove this special day?',
      message: formatDateRange(day.start, day.end),
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runWithToast(
      context,
      () async {
        await ref.read(branchRepositoryProvider).deleteHoursRows(day.rowIds);
        _afterSave();
      },
      onError: friendlyError,
      successMessage: 'Removed',
    );
  }

  Widget _weekly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set when this branch is open. Add a second period for a lunch and '
          'dinner break. A closing time earlier than the opening time means '
          'the branch closes after midnight.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Sp.lg),
        WeeklyHoursEditor(
          value: _week,
          onChanged: (week) => setState(() => _week = week),
        ),
      ],
    );
  }

  Widget _special() {
    final days = specialDaysFromRows(widget.rows.where((r) => !r.isWeekly));
    final today = DateTime.now();
    final upcoming = [
      for (final d in days)
        if (!specialDayIsPast(d, today)) d,
    ];
    final past = [
      for (final d in days)
        if (specialDayIsPast(d, today)) d,
    ];

    Widget row(SpecialDay day) {
      final note = day.noteEn ?? day.noteBn;
      final detail = day.isClosed
          ? 'Closed'
          : day.periods.map((p) => formatPeriod(p.open, p.close)).join(', ');
      return ListRow(
        leading: IconBadge(
          day.isClosed
              ? Icons.event_busy_outlined
              : Icons.event_available_outlined,
        ),
        title: formatDateRange(day.start, day.end),
        subtitle: note == null ? detail : '$detail. $note',
        trailing: IconButton(
          tooltip: 'Remove special day',
          onPressed: () => _deleteSpecial(day),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Holidays, festivals and one-off changes. A special day replaces the '
          'weekly hours for that date.',
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Sp.lg),
        AppButton(
          label: 'Add special day',
          icon: Icons.add_rounded,
          kind: AppButtonKind.tonal,
          onPressed: _addSpecial,
        ),
        const SizedBox(height: Sp.xl),
        if (days.isEmpty)
          const EmptyState(
            icon: Icons.event_outlined,
            title: 'No special days',
            message:
                'Add Eid, Pohela Boishakh or any day with different hours.',
          ),
        if (upcoming.isNotEmpty)
          ListGroup(
            title: 'Upcoming',
            children: [for (final d in upcoming) row(d)],
          ),
        if (past.isNotEmpty)
          ListGroup(title: 'Past', children: [for (final d in past) row(d)]),
      ],
    );
  }

  Widget _closure() {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSection(
          title: 'Temporary closure',
          subtitle:
              'Close the menu for a while without changing your hours. Use it '
              'for repairs, a private event or a short break.',
          children: [
            SwitchRow(
              title: 'Temporarily closed',
              subtitle: _closed
                  ? 'Customers see this branch as temporarily unavailable.'
                  : 'The branch follows its normal opening hours.',
              value: _closed,
              onChanged: (v) => setState(() => _closed = v),
            ),
            if (_closed) ...[
              BilingualFields(
                label: 'Message for customers',
                englishController: _c['message_en'],
                banglaController: _c['message_bn'],
                optional: true,
                maxLines: 2,
                maxLength: 300,
                hintEnglish: 'Closed for renovation. Back soon.',
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Reopens', optional: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickUntil,
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            _until == null
                                ? 'Set date and time'
                                : '${formatDate(_until!)}, '
                                      '${formatClock(clockToDb(ClockTime(_until!.hour, _until!.minute)))}',
                          ),
                        ),
                      ),
                      if (_until != null)
                        IconButton(
                          tooltip: 'Clear date',
                          onPressed: () => setState(() => _until = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Without a date the closure stays until you switch it '
                      'off.',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        FormSection(
          title: 'Outside opening hours',
          subtitle:
              'What happens to orders when the branch is closed. This takes '
              'effect when online ordering arrives; it is saved now.',
          children: [
            SegmentedChoice<String>(
              value: _outside,
              onChanged: (v) => setState(() => _outside = v),
              options: const [
                ChoiceOption(value: 'block_orders', label: 'Block orders'),
                ChoiceOption(
                  value: 'allow_scheduled',
                  label: 'Allow scheduled orders',
                ),
              ],
            ),
            Text(
              _outside == 'block_orders'
                  ? 'Customers can read the menu but cannot order until you '
                        'open.'
                  : 'Customers can order for a time when you are open.',
              style: context.textStyles.bodySmall?.copyWith(
                color: palette.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref
        .watch(branchStatusProvider(widget.branch.id))
        .valueOrNull;
    final showSave = _section != _Section.special;
    return AppPage(
      title: 'Opening hours',
      subtitle: widget.branch.name,
      bottomBar: showSave
          ? StickyActionBar(
              child: AppButton(
                label: _section == _Section.weekly
                    ? 'Save weekly hours'
                    : 'Save closure settings',
                expand: true,
                loading: _saving,
                onPressed: _section == _Section.weekly
                    ? _saveWeekly
                    : _saveClosure,
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.lg),
              child: Row(
                children: [
                  StatusPill(
                    status.isTemporarilyClosed
                        ? 'Temporarily closed'
                        : (status.isOpen ? 'Open now' : 'Closed now'),
                    tone: status.isTemporarilyClosed
                        ? PillTone.warning
                        : (status.isOpen ? PillTone.success : PillTone.neutral),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      status.summary,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SegmentedChoice<_Section>(
            value: _section,
            onChanged: (v) => setState(() => _section = v),
            options: const [
              ChoiceOption(value: _Section.weekly, label: 'Weekly'),
              ChoiceOption(value: _Section.special, label: 'Special days'),
              ChoiceOption(value: _Section.closure, label: 'Closure'),
            ],
          ),
          const SizedBox(height: Sp.xl),
          if (_section == _Section.weekly) _weekly(),
          if (_section == _Section.special) _special(),
          if (_section == _Section.closure) _closure(),
        ],
      ),
    );
  }
}

/// Bottom sheet form for one special day or range.
class _SpecialDayForm extends ConsumerStatefulWidget {
  const _SpecialDayForm({required this.branchId});

  final String branchId;

  @override
  ConsumerState<_SpecialDayForm> createState() => _SpecialDayFormState();
}

class _SpecialDayFormState extends ConsumerState<_SpecialDayForm> {
  final _c = ControllerBag();
  DateTime? _start;
  DateTime? _end;
  bool _range = false;
  bool _closed = true;
  List<DraftPeriod> _periods = [defaultPeriod];
  bool _saving = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final initial = isEnd ? (_end ?? _start ?? first) : (_start ?? first);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: isEnd ? (_start ?? first) : first,
      lastDate: now.add(const Duration(days: 730)),
      helpText: isEnd ? 'Last day' : 'Date',
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _end = picked;
      } else {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      }
    });
  }

  Future<void> _save() async {
    final start = _start;
    if (start == null) {
      showToast(context, 'Choose a date.', isError: true);
      return;
    }
    if (_range && _end == null) {
      showToast(context, 'Choose the last day of the range.', isError: true);
      return;
    }
    if (!_closed) {
      final problems = validateDay(_periods);
      if (_periods.isEmpty || problems.isNotEmpty) {
        showToast(
          context,
          _periods.isEmpty ? 'Add opening hours.' : problems.first,
          isError: true,
        );
        return;
      }
    }
    setState(() => _saving = true);
    final repository = ref.read(branchRepositoryProvider);
    final ok = await runWithToast(
      context,
      () => repository.addSpecialDay(
        widget.branchId,
        start: start,
        end: _range ? _end : null,
        closed: _closed,
        periods: _periods,
        noteEn: _c.nullable('note_en'),
        noteBn: _c.nullable('note_bn'),
      ),
      onError: friendlyError,
      successMessage: 'Special day added',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickDate(isEnd: false),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_start == null ? 'Choose date' : formatDate(_start!)),
          ),
          SwitchRow(
            title: 'Several days in a row',
            value: _range,
            onChanged: (v) => setState(() {
              _range = v;
              if (!v) _end = null;
            }),
          ),
          if (_range)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(isEnd: true),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _end == null ? 'Choose last day' : formatDate(_end!),
                ),
              ),
            ),
          const SizedBox(height: Sp.sm),
          SegmentedChoice<bool>(
            label: 'On this day',
            value: _closed,
            onChanged: (v) => setState(() => _closed = v),
            options: const [
              ChoiceOption(value: true, label: 'Closed'),
              ChoiceOption(value: false, label: 'Different hours'),
            ],
          ),
          if (!_closed) ...[
            const SizedBox(height: Sp.md),
            DayHoursCard(
              title: 'Opening hours',
              periods: _periods,
              showSwitch: false,
              onChanged: (periods) => setState(() => _periods = periods),
            ),
          ],
          const SizedBox(height: Sp.md),
          BilingualFields(
            label: 'Note',
            englishController: _c['note_en'],
            banglaController: _c['note_bn'],
            optional: true,
            hintEnglish: 'Eid holiday',
          ),
          const SizedBox(height: Sp.xl),
          AppButton(
            label: 'Add special day',
            expand: true,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
