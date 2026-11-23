import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/menu_search.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../menu_repository.dart';
import 'menu_ui.dart';

/// Lets the person pick another dish and returns that dish's option groups
/// (with their original ids; the caller makes copies with new ids). Returns
/// null when dismissed.
Future<List<OptionGroup>?> showCopyOptionsSheet(
  BuildContext context, {
  String? excludeItemId,
}) {
  return showModalBottomSheet<List<OptionGroup>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => _CopySheet(excludeItemId: excludeItemId),
  );
}

class _CopySheet extends ConsumerStatefulWidget {
  const _CopySheet({this.excludeItemId});

  final String? excludeItemId;

  @override
  ConsumerState<_CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends ConsumerState<_CopySheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _loadingId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(MenuItem item) async {
    if (_loadingId != null) return;
    setState(() => _loadingId = item.id);
    try {
      final groups = await ref.read(menuRepositoryProvider).optionGroups(item.id);
      if (!mounted) return;
      if (groups.isEmpty) {
        showToast(context, '${item.displayName} has no variants or add-ons to copy.');
        return;
      }
      Navigator.of(context).pop(groups);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(menuItemsProvider);
    final palette = context.palette;
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 2),
              child: Text('Copy from another dish', style: context.textStyles.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              child: Text(
                'All variants and add-ons of the chosen dish are added here as copies. Nothing changes on the other dish.',
                style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, Sp.sm),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search dishes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: AsyncValueView<List<MenuItem>>(
                value: items,
                loading: const SkeletonList(rows: 5),
                onRetry: () => ref.invalidate(menuItemsProvider),
                data: (all) {
                  final shown = [
                    for (final item in all)
                      if (item.id != widget.excludeItemId &&
                          !item.isDeleted &&
                          itemMatchesQuery(item, _query))
                        item,
                  ];
                  if (shown.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: _query.isEmpty ? 'No other dishes yet' : 'No dishes match',
                      message: _query.isEmpty
                          ? 'Add more dishes to copy their variants and add-ons.'
                          : 'Try another name.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: Sp.xl),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final item = shown[index];
                      final loading = _loadingId == item.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                        leading: MenuThumb(url: item.coverImage, size: 44),
                        title: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: item.nameBn != null && item.nameEn != null && item.nameBn!.trim().isNotEmpty
                            ? Text(item.nameBn!, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : Icon(Icons.copy_rounded, size: 18, color: palette.muted),
                        onTap: _loadingId == null ? () => _choose(item) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
