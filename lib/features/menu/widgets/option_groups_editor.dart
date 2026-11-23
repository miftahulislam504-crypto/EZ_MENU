import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../option_groups_logic.dart';
import 'editor_common.dart';
import 'option_copy_sheet.dart';
import 'option_group_card.dart';

/// Variants and add-ons of a dish (Feature Plan 4.3). Controlled by the
/// parent: it shows [groups] and calls [onChanged] with a new list on every
/// edit. The parent supplies the section card and heading.
class OptionGroupsEditor extends ConsumerStatefulWidget {
  const OptionGroupsEditor({
    super.key,
    required this.groups,
    required this.onChanged,
    required this.basePrice,
    this.excludeItemId,
    this.onImageUploaded,
  });

  final List<OptionGroup> groups;
  final ValueChanged<List<OptionGroup>> onChanged;

  /// The dish price, to show the price a customer pays for each option.
  final double basePrice;

  /// This dish, hidden from the "copy from another dish" list.
  final String? excludeItemId;

  /// Called with the address of every option photo uploaded here.
  final ValueChanged<String>? onImageUploaded;

  @override
  ConsumerState<OptionGroupsEditor> createState() => _OptionGroupsEditorState();
}

class _OptionGroupsEditorState extends ConsumerState<OptionGroupsEditor> {
  final Set<String> _expanded = {};

  static String _newId() => const Uuid().v4();

  List<OptionGroup> get _groups => widget.groups;

  void _set(List<OptionGroup> next) => widget.onChanged(next);

  void _addPreset(OptionPreset preset) {
    final group = presetGroup(preset, basePrice: widget.basePrice, newId: _newId);
    setState(() => _expanded.add(group.id));
    _set([..._groups, group]);
  }

  void _replace(int index, OptionGroup group) {
    _set([
      for (var i = 0; i < _groups.length; i++) i == index ? group : _groups[i],
    ]);
  }

  void _duplicate(int index) {
    final copy = cloneGroup(_groups[index], _newId);
    final name = copy.nameEn?.trim() ?? '';
    final renamed = name.isEmpty ? copy : copy.copyWith(nameEn: '$name copy');
    setState(() => _expanded.add(renamed.id));
    _set([
      ..._groups.sublist(0, index + 1),
      renamed,
      ..._groups.sublist(index + 1),
    ]);
  }

  void _delete(int index) {
    final id = _groups[index].id;
    setState(() => _expanded.remove(id));
    _set([
      for (var i = 0; i < _groups.length; i++)
        if (i != index) _groups[i],
    ]);
  }

  Future<void> _copyFromDish() async {
    final source = await showCopyOptionsSheet(
      context,
      excludeItemId: widget.excludeItemId,
    );
    if (source == null || !mounted) return;
    final merged = appendClones(_groups, source, _newId);
    setState(() {
      for (final group in merged.skip(_groups.length)) {
        _expanded.add(group.id);
      }
    });
    _set(merged);
    showToast(
      context,
      source.length == 1
          ? 'Copied 1 group.'
          : 'Copied ${source.length} groups.',
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  Widget _presetChips() {
    return Wrap(
      spacing: Sp.sm,
      runSpacing: Sp.sm,
      children: [
        for (final preset in OptionPreset.values)
          ActionChip(
            avatar: Icon(
              preset == OptionPreset.blank
                  ? Icons.add_rounded
                  : Icons.auto_awesome_rounded,
              size: 16,
            ),
            label: Text(optionPresetLabels[preset]!),
            onPressed: () => _addPreset(preset),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final palette = context.palette;
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
              const IconBadge(Icons.tune_rounded, size: 40),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No variants or add-ons', style: context.textStyles.titleSmall),
                    Text(
                      'Add sizes, crusts, spice levels or extras that customers choose when ordering.',
                      style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Text('Start from an example', style: context.textStyles.labelLarge),
          const SizedBox(height: Sp.sm),
          _presetChips(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(currentBusinessIdProvider);
    final currency =
        ref.watch(currentBusinessProvider).valueOrNull?.currency ?? 'BDT';
    final groups = _groups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: groups.isEmpty
              ? KeyedSubtree(key: const ValueKey('empty'), child: _empty(context))
              : KeyedSubtree(
                  key: const ValueKey('groups'),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) =>
                        _set(reorderList(groups, oldIndex, newIndex)),
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        Padding(
                          key: ValueKey(groups[i].id),
                          padding: const EdgeInsets.only(bottom: Sp.md),
                          child: OptionGroupCard(
                            index: i,
                            group: groups[i],
                            basePrice: widget.basePrice,
                            currency: currency,
                            businessId: businessId,
                            expanded: _expanded.contains(groups[i].id),
                            onToggle: () => _toggle(groups[i].id),
                            onChanged: (group) => _replace(i, group),
                            onDuplicate: () => _duplicate(i),
                            onDelete: () => _delete(i),
                            onImageUploaded: widget.onImageUploaded,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: Sp.xs),
          Text('Add another group', style: context.textStyles.labelLarge),
          const SizedBox(height: Sp.sm),
          _presetChips(),
        ],
        const SizedBox(height: Sp.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Copy from another dish',
            icon: Icons.copy_all_rounded,
            kind: AppButtonKind.secondary,
            onPressed: _copyFromDish,
          ),
        ),
      ],
    );
  }
}
