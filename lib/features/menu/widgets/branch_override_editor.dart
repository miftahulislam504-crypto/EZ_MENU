import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../branch_override_logic.dart';
import '../menu_models.dart';
import 'branch_override_card.dart';
import 'editor_common.dart';

/// Per-branch price and availability of a dish (Feature Plan 4.2). A branch
/// with no override has no entry in [settings]. Controlled by the parent,
/// which supplies the section card and heading.
///
/// A Consumer, not a plain StatefulWidget, only to read the business currency;
/// the constructor is the agreed contract.
class BranchOverrideEditor extends ConsumerStatefulWidget {
  const BranchOverrideEditor({
    super.key,
    required this.branches,
    required this.settings,
    required this.onChanged,
    required this.itemId,
    required this.basePrice,
    this.baseDiscountPrice,
  });

  final List<Branch> branches;
  final List<BranchItemSetting> settings;

  /// The full new list; branches with no override at all are left out of it.
  final ValueChanged<List<BranchItemSetting>> onChanged;

  /// Empty while the dish is not saved yet.
  final String itemId;
  final double basePrice;
  final double? baseDiscountPrice;

  @override
  ConsumerState<BranchOverrideEditor> createState() => _BranchOverrideEditorState();
}

class _BranchOverrideEditorState extends ConsumerState<BranchOverrideEditor> {
  final Set<String> _expanded = {};

  void _toggle(String branchId) {
    setState(() {
      if (!_expanded.remove(branchId)) _expanded.add(branchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currency =
        ref.watch(currentBusinessProvider).valueOrNull?.currency ?? 'BDT';
    final branches = widget.branches;

    if (branches.isEmpty) {
      return Text(
        'Add a branch to set branch specific prices and availability.',
        style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (branches.length == 1) ...[
          const EditorNote(
            'Branch overrides are useful when you add more branches. You can still set them now.',
          ),
          const SizedBox(height: Sp.md),
        ] else ...[
          Text(
            'Every branch uses the dish price and availability above unless you change it here.',
            style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: Sp.md),
        ],
        for (final branch in branches)
          Padding(
            key: ValueKey(branch.id),
            padding: const EdgeInsets.only(bottom: Sp.sm),
            child: BranchOverrideCard(
              branch: branch,
              setting: settingOf(widget.settings, branch.id),
              itemId: widget.itemId,
              basePrice: widget.basePrice,
              baseDiscountPrice: widget.baseDiscountPrice,
              currency: currency,
              expanded: _expanded.contains(branch.id),
              onToggle: () => _toggle(branch.id),
              onChanged: (next) =>
                  widget.onChanged(upsertSetting(widget.settings, next)),
              onReset: () =>
                  widget.onChanged(removeSetting(widget.settings, branch.id)),
            ),
          ),
      ],
    );
  }
}
