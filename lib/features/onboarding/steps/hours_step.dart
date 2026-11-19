import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/branch_status.dart';
import '../../../core/session/models.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../../branches/branch_repository.dart';
import '../../branches/hours_editing.dart';
import '../../branches/widgets/weekly_hours_editor.dart';
import '../../business/business_repository.dart';
import '../onboarding_widgets.dart';

/// Step 3: weekly opening hours of the first branch. Can be skipped.
class HoursStep extends ConsumerStatefulWidget {
  const HoursStep({
    super.key,
    required this.business,
    required this.branch,
    required this.onNext,
    required this.onBack,
  });

  final Business business;
  final Branch branch;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<HoursStep> createState() => _HoursStepState();
}

class _HoursStepState extends ConsumerState<HoursStep> {
  WeekDraft? _week;
  bool _saving = false;

  Future<void> _advance() async {
    await ref
        .read(businessRepositoryProvider)
        .advanceOnboarding(widget.business.id, 3);
    ref.refreshBusiness();
  }

  Future<void> _save() async {
    final week = _week;
    if (week == null || _saving) return;
    final problem = validateWeek(week);
    if (problem != null) {
      showToast(context, problem, isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runWithToast(context, () async {
      await ref
          .read(branchRepositoryProvider)
          .saveWeekly(widget.branch.id, week);
      ref.invalidate(branchStatusProvider(widget.branch.id));
      ref.invalidate(branchHoursProvider(widget.branch.id));
      await _advance();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    final ok = await runWithToast(context, _advance, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(branchHoursProvider(widget.branch.id));
    if (_week == null && rows.hasValue) {
      final weekly = (rows.value ?? const <HoursRow>[]).where(
        (r) => r.isWeekly,
      );
      final existing = weekFromRows(weekly);
      _week = weekIsEmpty(existing) ? presetEveryDay() : existing;
    }
    final week = _week;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeading(
          title: 'When are you open?',
          subtitle:
              'Customers see whether you are open or closed. Start with a '
              'preset and adjust the days that differ.',
        ),
        if (week == null)
          const Padding(padding: EdgeInsets.all(Sp.xl), child: LoadingView())
        else
          WeeklyHoursEditor(
            value: week,
            onChanged: (next) => setState(() => _week = next),
          ),
        StepButtons(
          primaryLabel: 'Save and continue',
          loading: _saving,
          onPrimary: week == null ? null : _save,
          onBack: widget.onBack,
          onSkip: _skip,
        ),
      ],
    );
  }
}
