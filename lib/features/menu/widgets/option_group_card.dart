import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/error_text.dart';
import '../../../core/supabase/storage_service.dart';
import '../../../core/widgets/widgets.dart';
import '../item_form_logic.dart';
import '../menu_models.dart';
import '../option_groups_logic.dart';
import 'editor_common.dart';
import 'option_group_preview.dart';
import 'option_row.dart';

/// One expandable variant or add-on group. Controlled by the parent: it shows
/// [group] and calls [onChanged] with the new group on every edit.
class OptionGroupCard extends ConsumerStatefulWidget {
  const OptionGroupCard({
    super.key,
    required this.index,
    required this.group,
    required this.basePrice,
    required this.currency,
    required this.businessId,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
    this.onImageUploaded,
  });

  final int index;
  final OptionGroup group;
  final double basePrice;
  final String currency;
  final String? businessId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<OptionGroup> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// Called with the address of every photo uploaded for an option, so the
  /// dish editor can clean up files that end up unused.
  final ValueChanged<String>? onImageUploaded;

  @override
  ConsumerState<OptionGroupCard> createState() => _OptionGroupCardState();
}

class _OptionGroupCardState extends ConsumerState<OptionGroupCard> {
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _nameBn = TextEditingController();
  final Map<String, OptionControllers> _rows = {};
  final List<OptionControllers> _graveyard = [];
  String? _uploadingId;
  String? _focusAfterBuild;

  OptionGroup get _group => widget.group;

  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _syncRows();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant OptionGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRows();
    _scheduleTextSync();
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameBn.dispose();
    for (final row in _rows.values) {
      row.dispose();
    }
    _rows.clear();
    for (final row in _graveyard) {
      row.dispose();
    }
    _graveyard.clear();
    super.dispose();
  }

  /// Creates controllers for new options and retires those of removed ones.
  /// Runs while building, so it never touches the text of existing fields.
  void _syncRows() {
    final ids = {for (final o in _group.options) o.id};
    final gone = [for (final id in _rows.keys) if (!ids.contains(id)) id];
    for (final id in gone) {
      _graveyard.add(_rows.remove(id)!);
    }
    if (_graveyard.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final row in _graveyard) {
          row.dispose();
        }
        _graveyard.clear();
      });
    }
    for (final option in _group.options) {
      _rows.putIfAbsent(option.id, () => OptionControllers(option));
    }
  }

  /// Changing the text of a field notifies the surrounding Form, which must
  /// not happen while building, so later syncs run after the frame.
  void _scheduleTextSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncText();
    });
  }

  /// Brings the text of the fields in line with the model without disturbing
  /// what the person is typing: a controller is touched only when what it
  /// holds no longer means the same value as the model.
  void _syncText() {
    setTextIfChanged(_nameEn, _group.nameEn ?? '');
    setTextIfChanged(_nameBn, _group.nameBn ?? '');
    for (final option in _group.options) {
      final row = _rows[option.id];
      if (row == null) continue;
      setTextIfChanged(row.nameEn, option.nameEn ?? '');
      setTextIfChanged(row.nameBn, option.nameBn ?? '');
      final typedPrice = parseMoneyText(row.price.text) ?? 0;
      if (typedPrice != option.price) {
        setTextIfChanged(row.price, option.price == 0 ? '' : plainNumber(option.price));
      }
      final typedDiscount = parseMoneyText(row.discount.text);
      if (typedDiscount != option.discountPrice) {
        setTextIfChanged(row.discount, plainNumber(option.discountPrice));
      }
    }
  }

  void _emit(OptionGroup next) => widget.onChanged(normalizeGroup(next));

  void _updateOption(String id, ItemOption Function(ItemOption) change) {
    _emit(
      _group.copyWith(
        options: [for (final o in _group.options) o.id == id ? change(o) : o],
      ),
    );
  }

  void _addOption() {
    final id = const Uuid().v4();
    _focusAfterBuild = id;
    _emit(_group.copyWith(options: [..._group.options, ItemOption(id: id)]));
  }

  void _removeOption(String id) {
    _emit(_group.copyWith(options: [for (final o in _group.options) if (o.id != id) o]));
  }

  void _advanceFrom(String id) {
    final options = _group.options;
    final at = options.indexWhere((o) => o.id == id);
    if (at < 0) return;
    if (at == options.length - 1) {
      _addOption();
      return;
    }
    _rows[options[at + 1].id]?.focus.requestFocus();
  }

  Future<void> _pickImage(String optionId) async {
    final businessId = widget.businessId;
    if (businessId == null || _uploadingId != null) return;
    setState(() => _uploadingId = optionId);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .pickAndUpload(
            businessId: businessId,
            bucket: AppBucket.menu,
            folder: 'options',
            maxDimension: 900,
          );
      if (url != null) {
        widget.onImageUploaded?.call(url);
        if (!mounted) return;
        _updateOption(optionId, (o) => o.copyWith(imageUrl: url));
      }
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingId = null);
    }
  }

  void _setSelectType(String type) {
    if (_group.selectType == type) return;
    _emit(_group.copyWith(selectType: type, clearMax: type == 'multiple'));
  }

  void _setRequired(bool value) {
    var next = _group.copyWith(isRequired: value);
    if (value && !next.isSingle && next.minSelect < 1) {
      next = next.copyWith(minSelect: 1);
    }
    _emit(next);
  }

  void _changeMin(int delta) {
    final available = availableOptionCount(_group);
    final limit = available < 1 ? 1 : available;
    final next = (_group.minSelect + delta).clamp(1, limit);
    _emit(_group.copyWith(minSelect: next));
  }

  void _toggleMaxLimit(bool limited) {
    if (!limited) {
      _emit(_group.copyWith(clearMax: true));
      return;
    }
    final count = _group.options.length;
    final base = _group.minSelect < 1 ? 1 : _group.minSelect;
    final initial = count < base ? base : count;
    _emit(_group.copyWith(maxSelect: initial));
  }

  void _changeMax(int delta) {
    final max = _group.maxSelect;
    if (max == null) return;
    final floor = _group.minSelect < 1 ? 1 : _group.minSelect;
    final ceiling = _group.options.length < floor ? floor : _group.options.length;
    _emit(_group.copyWith(maxSelect: (max + delta).clamp(floor, ceiling)));
  }

  Future<void> _confirmDelete() async {
    if (_group.options.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Delete "${_group.displayName}"?',
        message:
            'This removes the group and its ${_group.options.length} option${_group.options.length == 1 ? '' : 's'} from the dish. '
            'It is saved when you save the dish.',
        confirmLabel: 'Delete group',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    widget.onDelete();
  }

  Widget _header(BuildContext context, List<String> problems) {
    final palette = context.palette;
    final count = _group.options.length;
    final subtitle = [
      _group.isSingle ? 'Single choice' : 'Multiple choice',
      _group.isAbsolute ? 'Replaces price' : 'Adds to price',
      '$count option${count == 1 ? '' : 's'}',
    ].join('  |  ');
    return InkWell(
      borderRadius: BorderRadius.circular(Rad.panel),
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
        child: Row(
          children: [
            DragHandle(index: widget.index),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _group.nameEn?.trim().isNotEmpty == true ||
                                  _group.nameBn?.trim().isNotEmpty == true
                              ? _group.displayName
                              : 'Untitled group',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.titleSmall,
                        ),
                      ),
                      if (_group.isRequired) ...[
                        const SizedBox(width: Sp.sm),
                        const StatusPill('Required', tone: PillTone.warning),
                      ],
                      if (!widget.expanded && problems.isNotEmpty) ...[
                        const SizedBox(width: Sp.sm),
                        const StatusPill('Needs attention', tone: PillTone.danger),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Group actions',
              icon: Icon(Icons.more_vert_rounded, color: palette.muted),
              onSelected: (value) {
                if (value == 'duplicate') widget.onDuplicate();
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate group')),
                PopupMenuItem(value: 'delete', child: Text('Delete group')),
              ],
            ),
            AnimatedRotation(
              turns: widget.expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, color: palette.muted),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _rules(BuildContext context) {
    final group = _group;
    final available = availableOptionCount(group);
    final limited = group.maxSelect != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedChoice<String>(
          label: 'Customer can choose',
          value: group.selectType,
          onChanged: _setSelectType,
          options: const [
            ChoiceOption(value: 'single', label: 'Single choice', icon: Icons.radio_button_checked_rounded),
            ChoiceOption(value: 'multiple', label: 'Multiple choice', icon: Icons.checklist_rounded),
          ],
        ),
        const SizedBox(height: Sp.md),
        SegmentedChoice<String>(
          label: 'Option prices',
          value: group.priceMode,
          onChanged: (mode) => _emit(group.copyWith(priceMode: mode)),
          options: const [
            ChoiceOption(value: 'additional', label: 'Adds to the dish price'),
            ChoiceOption(value: 'absolute', label: 'Replaces the dish price'),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            group.isAbsolute
                ? 'Each option is the full price of the dish, for example Small 250, Large 400.'
                : 'Each option is an extra charge on top of the dish price, for example Extra cheese +40.',
            key: ValueKey(group.priceMode),
            style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
          ),
        ),
        const SizedBox(height: Sp.sm),
        SwitchRow(
          title: 'Required',
          subtitle: 'The customer must choose before ordering.',
          value: group.isRequired,
          onChanged: _setRequired,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: group.isSingle
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    if (group.isRequired) ...[
                      const SizedBox(height: Sp.sm),
                      EditorStepper(
                        label: 'Minimum choices',
                        valueText: '${group.minSelect}',
                        helper: available > 0 ? 'Out of $available available' : null,
                        onDecrease: group.minSelect > 1 ? () => _changeMin(-1) : null,
                        onIncrease: group.minSelect < (available < 1 ? 1 : available)
                            ? () => _changeMin(1)
                            : null,
                      ),
                    ],
                    const SizedBox(height: Sp.sm),
                    SwitchRow(
                      title: 'Limit how many can be chosen',
                      subtitle: limited ? null : 'No limit: the customer can pick any number.',
                      value: limited,
                      onChanged: _toggleMaxLimit,
                    ),
                    if (limited) ...[
                      const SizedBox(height: Sp.xs),
                      EditorStepper(
                        label: 'Maximum choices',
                        valueText: '${group.maxSelect}',
                        onDecrease: group.maxSelect! > (group.minSelect < 1 ? 1 : group.minSelect)
                            ? () => _changeMax(-1)
                            : null,
                        onIncrease: group.maxSelect! < group.options.length
                            ? () => _changeMax(1)
                            : null,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _options(BuildContext context) {
    final group = _group;
    final focusId = _focusAfterBuild;
    if (focusId != null) {
      _focusAfterBuild = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rows[focusId]?.focus.requestFocus();
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options', style: context.textStyles.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Press Enter in a name to add the next option.',
          style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: Sp.sm),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            _emit(group.copyWith(options: reorderList(group.options, oldIndex, newIndex)));
          },
          children: [
            for (var i = 0; i < group.options.length; i++)
              Padding(
                key: ValueKey(group.options[i].id),
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: OptionRow(
                  index: i,
                  group: group,
                  option: group.options[i],
                  controllers: _rows[group.options[i].id]!,
                  basePrice: widget.basePrice,
                  currency: widget.currency,
                  uploading: _uploadingId == group.options[i].id,
                  onNameEn: (text) {
                    final id = group.options[i].id;
                    _updateOption(id, (o) => o.copyWith(nameEn: text));
                  },
                  onNameBn: (text) {
                    final id = group.options[i].id;
                    _updateOption(id, (o) => o.copyWith(nameBn: text));
                  },
                  onPrice: (text) {
                    final id = group.options[i].id;
                    final value = parseMoneyText(text) ?? 0;
                    _updateOption(id, (o) => o.copyWith(price: value));
                  },
                  onDiscount: (text) {
                    final id = group.options[i].id;
                    final value = parseMoneyText(text);
                    _updateOption(
                      id,
                      (o) => value == null ? o.copyWith(clearDiscount: true) : o.copyWith(discountPrice: value),
                    );
                  },
                  onDefault: (value) => _emit(setDefaultOption(group, group.options[i].id, value)),
                  onAvailable: (value) {
                    final id = group.options[i].id;
                    _updateOption(id, (o) => o.copyWith(isAvailable: value));
                  },
                  onPickImage: () => _pickImage(group.options[i].id),
                  onRemoveImage: () {
                    final id = group.options[i].id;
                    _updateOption(id, (o) => o.copyWith(clearImage: true));
                  },
                  onDelete: () => _removeOption(group.options[i].id),
                  onSubmitted: () => _advanceFrom(group.options[i].id),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Add option',
            icon: Icons.add_rounded,
            kind: AppButtonKind.tonal,
            onPressed: _addOption,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final problems = validateOptionGroups([_group]);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(
          color: widget.expanded ? palette.lineStrong : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, problems),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: Sp.lg, color: palette.line),
                        AppTextField(
                          label: 'Group name in English',
                          controller: _nameEn,
                          hint: 'e.g. Size',
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (text) => _emit(_group.copyWith(nameEn: text)),
                        ),
                        const SizedBox(height: Sp.md),
                        AppTextField(
                          label: 'Group name in Bangla',
                          controller: _nameBn,
                          hint: 'যেমন: সাইজ',
                          onChanged: (text) => _emit(_group.copyWith(nameBn: text)),
                        ),
                        const SizedBox(height: Sp.lg),
                        _rules(context),
                        const SizedBox(height: Sp.lg),
                        _options(context),
                        if (problems.isNotEmpty) ...[
                          const SizedBox(height: Sp.md),
                          EditorProblems(problems),
                        ],
                        const SizedBox(height: Sp.lg),
                        OptionGroupPreview(
                          group: _group,
                          basePrice: widget.basePrice,
                          currency: widget.currency,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
