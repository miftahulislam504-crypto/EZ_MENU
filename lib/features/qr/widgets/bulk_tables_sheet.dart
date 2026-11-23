import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../qr_logic.dart';
import '../qr_models.dart';
import '../qr_repository.dart';

/// Adds many tables at once (T1 to T20). Pops with the number created, or
/// null when the person closes the sheet.
class BulkTablesSheet extends ConsumerStatefulWidget {
  const BulkTablesSheet({super.key, required this.branchId, required this.tables});

  final String branchId;
  final List<RestaurantTable> tables;

  @override
  ConsumerState<BulkTablesSheet> createState() => _BulkTablesSheetState();
}

class _BulkTablesSheetState extends ConsumerState<BulkTablesSheet> {
  final _prefix = TextEditingController(text: 'T');
  final _start = TextEditingController(text: '1');
  final _count = TextEditingController(text: '10');
  final _capacity = TextEditingController();
  final _zone = TextEditingController();
  bool _pad = false;
  bool _saving = false;

  @override
  void dispose() {
    _prefix.dispose();
    _start.dispose();
    _count.dispose();
    _capacity.dispose();
    _zone.dispose();
    super.dispose();
  }

  BulkTablePlan get _plan {
    final start = int.tryParse(_start.text.trim());
    final count = int.tryParse(_count.text.trim());
    if (start == null) return const BulkTablePlan(error: 'Enter the number to start from.');
    if (count == null) return const BulkTablePlan(error: 'Enter how many tables to add.');
    return planBulkTables(
      prefix: _prefix.text,
      start: start,
      count: count,
      existingNames: [for (final table in widget.tables) table.name],
      padTo: _pad ? 2 : 0,
    );
  }

  Future<void> _save(BulkTablePlan plan) async {
    final capacityError = validateCapacity(_capacity.text);
    final zoneError = validateZone(_zone.text);
    if (capacityError != null || zoneError != null) {
      showToast(context, capacityError ?? zoneError!, isError: true);
      return;
    }
    setState(() => _saving = true);
    var created = 0;
    final ok = await runWithToast(context, () async {
      final zone = _zone.text.trim();
      created = await ref.read(qrRepositoryProvider).createTables(
        widget.branchId,
        plan.toCreate,
        startOrder: nextSortOrder(widget.tables),
        capacity: parseCapacity(_capacity.text),
        zone: zone.isEmpty ? null : zone,
      );
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = _plan;
    final zones = zoneSuggestions(widget.tables);
    final count = plan.toCreate.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Each table gets its own QR code, so a customer who scans it opens the menu for that table.',
            style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Sp.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Name prefix',
                  controller: _prefix,
                  hint: 'T',
                  maxLength: 20,
                  optional: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppTextField(
                  label: 'Start at',
                  controller: _start,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppTextField(
                  label: 'How many',
                  controller: _count,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SwitchRow(
            title: 'Pad numbers with a zero',
            subtitle: 'T01, T02 instead of T1, T2, so they sort neatly.',
            value: _pad,
            onChanged: (value) => setState(() => _pad = value),
          ),
          const SizedBox(height: Sp.sm),
          AppTextField(
            label: 'Zone',
            controller: _zone,
            hint: 'Ground floor, Rooftop, AC zone',
            optional: true,
            maxLength: tableZoneMaxLength,
            onChanged: (_) => setState(() {}),
          ),
          if (zones.isNotEmpty) ...[
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.xs,
              children: [
                for (final zone in zones)
                  ActionChip(
                    label: Text(zone),
                    onPressed: () => setState(() => _zone.text = zone),
                  ),
              ],
            ),
            const SizedBox(height: Sp.md),
          ],
          AppTextField(
            label: 'Seats per table',
            controller: _capacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            optional: true,
            hint: '4',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Sp.lg),
          _PlanSummary(plan: plan),
          const SizedBox(height: Sp.lg),
          AppButton(
            label: count == 0 ? 'Add tables' : 'Add $count ${count == 1 ? 'table' : 'tables'}',
            icon: Icons.add_rounded,
            expand: true,
            loading: _saving,
            onPressed: plan.canCreate ? () => _save(plan) : null,
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final BulkTablePlan plan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final String text;
    final Color color;
    if (plan.error != null) {
      text = plan.error!;
      color = palette.danger;
    } else if (plan.toCreate.isEmpty) {
      text = 'Every one of these names is already used.';
      color = palette.warning;
    } else if (plan.conflicts.isNotEmpty) {
      text =
          'Will add ${plan.toCreate.first} to ${plan.toCreate.last}. '
          '${plan.conflicts.length} already exist and will be skipped: '
          '${_listNames(plan.conflicts)}.';
      color = palette.warning;
    } else {
      text = 'Will add ${plan.rangeText}.';
      color = palette.muted;
    }
    return Text(text, style: context.textStyles.bodyMedium?.copyWith(color: color));
  }

  String _listNames(List<String> names) {
    if (names.length <= 5) return names.join(', ');
    return '${names.take(5).join(', ')} and ${names.length - 5} more';
  }
}
