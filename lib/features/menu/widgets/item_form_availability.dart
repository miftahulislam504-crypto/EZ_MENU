import 'package:flutter/material.dart';

import '../../../core/logic/sold_out.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import 'editor_common.dart';
import 'schedule_editor.dart';
import 'sold_out_sheet.dart';

/// Sold out switch (with an optional return time) and the availability
/// windows of a dish.
class ItemAvailabilitySection extends StatelessWidget {
  const ItemAvailabilitySection({
    super.key,
    required this.isSoldOut,
    required this.soldOutUntil,
    required this.onSoldOut,
    required this.schedules,
    required this.onSchedules,
    this.errorText,
  });

  final bool isSoldOut;
  final DateTime? soldOutUntil;

  /// Called with the new switch state and the return time (null = manual).
  final void Function(bool soldOut, DateTime? until) onSoldOut;
  final List<ItemSchedule> schedules;
  final ValueChanged<List<ItemSchedule>> onSchedules;
  final String? errorText;

  Future<void> _chooseUntil(BuildContext context) async {
    final choice = await showSoldOutSheet(context, title: 'Sold out until');
    if (choice == null) return;
    onSoldOut(true, choice.until);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FormSection(
      title: 'Availability',
      subtitle: 'Turn the dish off for a while, or limit it to certain days and times.',
      children: [
        SwitchRow(
          title: 'Sold out',
          subtitle: isSoldOut
              ? null
              : 'Customers see the dish as sold out. You can set when it returns.',
          value: isSoldOut,
          onChanged: (on) {
            if (on) {
              _chooseUntil(context);
            } else {
              onSoldOut(false, null);
            }
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isSoldOut
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            soldOutUntil == null
                                ? 'Sold out until you turn it back on.'
                                : 'Sold out, ${backAtText(soldOutUntil!, DateTime.now())}.',
                            style: context.textStyles.bodyMedium?.copyWith(color: palette.warning),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _chooseUntil(context),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    if (errorText != null)
                      EditorNote(errorText!, tone: PillTone.danger),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const Divider(height: 1),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available at certain times', style: context.textStyles.titleSmall),
            const SizedBox(height: 2),
            Text(
              'Outside its windows the dish is hidden or shown as unavailable on the customer menu, '
              'depending on your menu settings.',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: Sp.md),
            ScheduleEditor(windows: schedules, onChanged: onSchedules),
          ],
        ),
      ],
    );
  }
}
