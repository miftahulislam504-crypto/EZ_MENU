import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../qr_logic.dart';
import '../qr_models.dart';

/// How the tables are chosen on the print screen.
enum PrintTableMode { none, all, pick }

/// "What to print": the branch code, the takeaway code and the tables.
class PrintWhatSection extends StatelessWidget {
  const PrintWhatSection({
    super.key,
    required this.overview,
    required this.selection,
    required this.mode,
    required this.missingCodes,
    required this.onSelection,
    required this.onMode,
  });

  final QrOverview overview;
  final PrintSelection selection;
  final PrintTableMode mode;

  /// Tables that have no active code and so cannot be printed.
  final int missingCodes;
  final ValueChanged<PrintSelection> onSelection;
  final ValueChanged<PrintTableMode> onMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tables = [
      for (final table in overview.tables)
        if (overview.tableCodes.containsKey(table.id)) table,
    ]..sort(compareTables);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          title: 'What to print',
          children: [
            SwitchRow(
              title: 'Branch menu code',
              subtitle: overview.branchCode == null
                  ? 'This branch has no active menu code. Create one on the QR and tables tab.'
                  : 'One card for the door, a poster or a flyer.',
              value: selection.includeBranch && overview.branchCode != null,
              enabled: overview.branchCode != null,
              onChanged: (value) => onSelection(selection.copyWith(includeBranch: value)),
            ),
            SwitchRow(
              title: 'Takeaway counter code',
              subtitle: overview.takeawayCode == null
                  ? 'No takeaway code yet. Create one on the QR and tables tab.'
                  : 'One card for the pickup counter.',
              value: selection.includeTakeaway && overview.takeawayCode != null,
              enabled: overview.takeawayCode != null,
              onChanged: (value) => onSelection(selection.copyWith(includeTakeaway: value)),
            ),
            SegmentedChoice<PrintTableMode>(
              label: 'Table codes',
              value: mode,
              onChanged: onMode,
              options: const [
                ChoiceOption(value: PrintTableMode.none, label: 'None'),
                ChoiceOption(value: PrintTableMode.all, label: 'All tables'),
                ChoiceOption(value: PrintTableMode.pick, label: 'Choose'),
              ],
            ),
            if (missingCodes > 0)
              Text(
                missingCodes == 1
                    ? '1 table has no active code and is left out.'
                    : '$missingCodes tables have no active code and are left out.',
                style: context.textStyles.bodySmall?.copyWith(color: palette.warning),
              ),
          ],
        ),
        if (mode == PrintTableMode.pick) ...[
          const SizedBox(height: Sp.lg),
          if (tables.isEmpty)
            Text(
              'There are no tables with a QR code yet.',
              style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
            )
          else
            ListGroup(
              title: 'Choose tables',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => onSelection(
                      selection.copyWith(pickedTableIds: {for (final t in tables) t.id}),
                    ),
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () => onSelection(selection.copyWith(pickedTableIds: const {})),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              children: [
                for (final table in tables)
                  _PickRow(
                    table: table,
                    picked: selection.pickedTableIds.contains(table.id),
                    onChanged: (value) {
                      final next = {...selection.pickedTableIds};
                      value ? next.add(table.id) : next.remove(table.id);
                      onSelection(selection.copyWith(pickedTableIds: next));
                    },
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.table, required this.picked, required this.onChanged});

  final RestaurantTable table;
  final bool picked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final zone = table.zone?.trim();
    return ListRow(
      dense: true,
      title: 'Table ${table.name}',
      subtitle: (zone == null || zone.isEmpty) ? null : zone,
      onTap: () => onChanged(!picked),
      trailing: Checkbox(value: picked, onChanged: (value) => onChanged(value ?? false)),
    );
  }
}

/// Cards per page: 1, 2, 4 or 6.
class PrintPerPageChoice extends StatelessWidget {
  const PrintPerPageChoice({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedChoice<int>(
      label: 'Cards per page',
      value: value,
      onChanged: onChanged,
      options: [
        for (final count in printCardsPerPage)
          ChoiceOption(value: count, label: '$count'),
      ],
    );
  }
}
