import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/branch_status.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'branch_repository.dart';

class BranchListScreen extends ConsumerStatefulWidget {
  const BranchListScreen({super.key});

  @override
  ConsumerState<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends ConsumerState<BranchListScreen> {
  List<Branch>? _local;
  List<Branch>? _source;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = _local;
    if (list == null) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(target, moved);
    setState(() {});
    await runWithToast(context, () async {
      await ref.read(branchRepositoryProvider).reorder([
        for (final b in list) b.id,
      ]);
      ref.refreshBranches();
    }, onError: friendlyError);
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchesProvider);
    final data = branches.valueOrNull;
    if (data != null && !identical(data, _source)) {
      _source = data;
      _local = List<Branch>.of(data);
    }
    final list = _local ?? const <Branch>[];

    Widget body;
    if (branches.isLoading && data == null) {
      body = const SkeletonList(rows: 3);
    } else if (branches.hasError && data == null) {
      body = ErrorState(
        message: friendlyError(branches.error),
        onRetry: () => ref.invalidate(branchesProvider),
      );
    } else if (list.isEmpty) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No branches yet',
        message: 'Add your first branch to get a menu link and QR code.',
        actionLabel: 'Add branch',
        onAction: () => context.push(AppRoutes.branchNew),
      );
    } else {
      body = ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, 96),
        buildDefaultDragHandles: false,
        itemCount: list.length,
        onReorder: _reorder,
        itemBuilder: (context, index) {
          final branch = list[index];
          return _BranchRow(
            key: ValueKey(branch.id),
            branch: branch,
            index: index,
            canReorder: list.length > 1,
          );
        },
      );
    }

    return AppPage(
      title: 'Branches',
      subtitle: 'Locations that share one menu',
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.branchNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add branch'),
      ),
      body: body,
    );
  }
}

class _BranchRow extends ConsumerWidget {
  const _BranchRow({
    super.key,
    required this.branch,
    required this.index,
    required this.canReorder,
  });

  final Branch branch;
  final int index;
  final bool canReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(branchStatusProvider(branch.id)).valueOrNull;
    final palette = context.palette;

    Widget pill;
    if (!branch.isActive) {
      pill = const StatusPill('Inactive');
    } else if (status == null) {
      pill = const StatusPill('Checking hours');
    } else if (status.isTemporarilyClosed) {
      pill = const StatusPill('Temporarily closed', tone: PillTone.warning);
    } else if (status.isOpen) {
      pill = const StatusPill('Open now', tone: PillTone.success);
    } else {
      pill = const StatusPill('Closed now');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Sp.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Rad.panel),
            ),
            onTap: () => context.push(AppRoutes.branchEdit(branch.id)),
            child: Padding(
              padding: const EdgeInsets.all(Sp.lg),
              child: Row(
                children: [
                  const IconBadge(Icons.storefront_outlined),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: context.textStyles.titleMedium,
                        ),
                        if ((branch.area ?? branch.address) != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              branch.area ?? branch.address ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.bodySmall?.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ),
                        const SizedBox(height: Sp.sm),
                        pill,
                      ],
                    ),
                  ),
                  if (canReorder)
                    ReorderableDragStartListener(
                      index: index,
                      child: Tooltip(
                        message: 'Drag to change order',
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.sm),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: palette.line),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.branchHours(branch.id)),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text('Opening hours'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.branchEdit(branch.id)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
