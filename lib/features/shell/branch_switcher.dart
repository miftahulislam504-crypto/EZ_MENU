import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/widgets/widgets.dart';

/// Shows which branch the dashboard is working on and lets the person switch.
///
/// With a single branch it is a plain label. Menu, QR and table screens all
/// follow [selectedBranchProvider].
class BranchSwitcher extends ConsumerWidget {
  const BranchSwitcher({super.key, this.expand = false});

  /// Fills the available width (used in the navigation rail).
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(selectedBranchProvider);
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    if (branch == null) return const SizedBox.shrink();

    final canSwitch = branches.length > 1;
    final palette = context.palette;

    final label = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(Icons.storefront_outlined, size: 18, color: palette.muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            branch.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.labelLarge,
          ),
        ),
        if (canSwitch) ...[
          const SizedBox(width: 4),
          Icon(Icons.unfold_more_rounded, size: 18, color: palette.muted),
        ],
      ],
    );

    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.control),
        border: Border.all(color: palette.line),
      ),
      child: label,
    );

    if (!canSwitch) return chip;
    return Semantics(
      button: true,
      label: 'Switch branch, current ${branch.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.control),
        onTap: () => _openSheet(context, ref, branches, branch),
        child: chip,
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    List<Branch> branches,
    Branch current,
  ) {
    return showAppSheet<void>(
      context,
      title: 'Choose a branch',
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListGroup(
                children: [
                  for (final branch in branches)
                    ListRow(
                      title: branch.name,
                      subtitle: branch.area ?? branch.address,
                      leading: IconBadge(
                        branch.id == current.id
                            ? Icons.check_rounded
                            : Icons.storefront_outlined,
                      ),
                      trailing: branch.isActive
                          ? null
                          : const StatusPill('Inactive'),
                      onTap: branch.isActive
                          ? () {
                              ref
                                  .read(selectedBranchIdProvider.notifier)
                                  .select(branch.id);
                              Navigator.of(sheetContext).pop();
                            }
                          : null,
                    ),
                ],
              ),
              AppButton(
                label: 'Manage branches',
                kind: AppButtonKind.text,
                icon: Icons.tune_rounded,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.go(AppRoutes.branches);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
