import 'package:flutter/material.dart';

import '../../../core/logic/sold_out.dart';
import '../../../core/widgets/widgets.dart';

/// What the person chose in the sold-out sheet.
class SoldOutChoice {
  const SoldOutChoice({this.until, this.branchOnly = false});

  /// When the dish returns by itself; null means "until I turn it back on".
  final DateTime? until;

  /// True to mark it sold out at the current branch only.
  final bool branchOnly;
}

/// Asks for how long a dish is sold out and, with several branches, where.
/// Returns null when dismissed.
Future<SoldOutChoice?> showSoldOutSheet(
  BuildContext context, {
  required String title,
  bool offerBranchScope = false,
  String? branchName,
}) {
  return showAppSheet<SoldOutChoice>(
    context,
    title: title,
    builder: (sheetContext) => _SoldOutBody(
      offerBranchScope: offerBranchScope,
      branchName: branchName,
    ),
  );
}

class _SoldOutBody extends StatefulWidget {
  const _SoldOutBody({required this.offerBranchScope, this.branchName});

  final bool offerBranchScope;
  final String? branchName;

  @override
  State<_SoldOutBody> createState() => _SoldOutBodyState();
}

class _SoldOutBodyState extends State<_SoldOutBody> {
  SoldOutPreset _preset = SoldOutPreset.manual;
  bool _branchOnly = false;
  DateTime? _custom;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _custom ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _custom == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(_custom!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _custom = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _preset = SoldOutPreset.custom;
    });
  }

  void _confirm() {
    final now = DateTime.now();
    final until = soldOutUntilFor(_preset, now, custom: _custom);
    if (_preset == SoldOutPreset.custom && (until == null || !until.isAfter(now))) {
      showToast(context, 'Pick a time in the future.', isError: true);
      return;
    }
    Navigator.of(context).pop(SoldOutChoice(until: until, branchOnly: _branchOnly));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final preset in SoldOutPreset.values)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
            title: Text(soldOutPresetLabels[preset]!),
            subtitle: preset == SoldOutPreset.custom && _custom != null
                ? Text(backAtText(_custom!, now))
                : (preset == SoldOutPreset.manual || preset == SoldOutPreset.custom
                      ? null
                      : Text(backAtText(soldOutUntilFor(preset, now)!, now))),
            trailing: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _preset == preset
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: context.colors.primary)
                  : Icon(Icons.circle_outlined, key: const ValueKey('off'), color: palette.lineStrong),
            ),
            onTap: () {
              if (preset == SoldOutPreset.custom) {
                _pickCustom();
              } else {
                setState(() => _preset = preset);
              }
            },
          ),
        if (widget.offerBranchScope) ...[
          const Divider(height: Sp.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
            child: SegmentedChoice<bool>(
              label: 'Where',
              value: _branchOnly,
              onChanged: (v) => setState(() => _branchOnly = v),
              options: [
                const ChoiceOption(value: false, label: 'All branches'),
                ChoiceOption(
                  value: true,
                  label: widget.branchName == null ? 'This branch' : 'Only ${widget.branchName}',
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, Sp.lg),
          child: AppButton(
            label: 'Mark as sold out',
            icon: Icons.block_rounded,
            expand: true,
            onPressed: _confirm,
          ),
        ),
      ],
    );
  }
}
