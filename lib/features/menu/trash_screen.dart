import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/storage_service.dart';
import '../../core/widgets/widgets.dart';
import 'category_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/menu_ui.dart';

/// Deleted dishes and categories. Restore them, or remove them for good.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final Set<String> _busy = {};

  DateTime _when(DateTime? value) => value ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _deleteFiles(Iterable<String?> urls) async {
    final service = ref.read(imageUploadServiceProvider);
    for (final url in urls) {
      try {
        await service.deleteByUrl(url);
      } catch (_) {
        // Best effort: a leftover file does no harm.
      }
    }
  }

  Future<void> _run(String key, Future<void> Function() action, {String? success}) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      ref.refreshMenu();
      if (mounted && success != null) showToast(context, success);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _restoreItem(MenuItem item, MenuTrash trash) async {
    final repo = ref.read(menuRepositoryProvider);
    final key = 'item:${item.id}';
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await repo.restoreItem(item.id);
      ref.refreshMenu();
      if (mounted) showToast(context, 'Dish restored');
    } catch (error) {
      final message = friendlyError(error);
      final category = trash.categories.where((c) => c.id == item.categoryId).firstOrNull;
      if (!mounted) return;
      if (category != null && message.toLowerCase().contains('restore the category')) {
        final go = await confirmAction(
          context,
          title: 'Restore the category first',
          message:
              '"${item.displayName}" belongs to "${category.displayName}", which is also in '
              'the trash. Restoring the category brings its dishes back too.',
          confirmLabel: 'Restore category',
        );
        if (go && mounted) {
          try {
            await repo.restoreCategory(category.id);
            ref.refreshMenu();
            if (mounted) showToast(context, 'Category and dishes restored');
          } catch (e2) {
            if (mounted) showToast(context, friendlyError(e2), isError: true);
          }
        }
      } else {
        showToast(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _deleteItemForever(MenuItem item) async {
    final ok = await confirmAction(
      context,
      title: 'Delete "${item.displayName}" for good?',
      message: 'This cannot be undone. Its photos are removed too.',
      confirmLabel: 'Delete forever',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run('item:${item.id}', () async {
      await ref.read(menuRepositoryProvider).deleteItemForever(item.id);
      await _deleteFiles([...item.imageUrls]);
    }, success: 'Dish deleted for good');
  }

  Future<void> _deleteCategoryForever(MenuCategory category, MenuTrash trash) async {
    final ok = await confirmAction(
      context,
      title: 'Delete "${category.displayName}" for good?',
      message:
          'This also removes every dish and subcategory inside it. This '
          'cannot be undone.',
      confirmLabel: 'Delete forever',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final urls = <String?>[
      category.imageUrl,
      for (final item in trash.items)
        if (item.categoryId == category.id) ...item.imageUrls,
    ];
    await _run('cat:${category.id}', () async {
      await ref.read(menuRepositoryProvider).deleteCategoryForever(category.id);
      await _deleteFiles(urls);
    }, success: 'Category deleted for good');
  }

  Future<void> _emptyTrash(MenuTrash trash) async {
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;
    final ok = await confirmAction(
      context,
      title: 'Empty the trash?',
      message:
          '${trash.items.length} dishes and ${trash.categories.length} categories will be '
          'deleted for good, with their photos. This cannot be undone.',
      confirmLabel: 'Empty trash',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final urls = <String?>[
      for (final c in trash.categories) c.imageUrl,
      for (final i in trash.items) ...i.imageUrls,
    ];
    await _run('all', () async {
      await ref.read(menuRepositoryProvider).emptyTrash(businessId);
      await _deleteFiles(urls);
    }, success: 'Trash emptied');
  }

  @override
  Widget build(BuildContext context) {
    final trashAsync = ref.watch(menuTrashProvider);
    final liveCategories = ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];
    final trash = trashAsync.valueOrNull;

    Widget body;
    if (trash == null) {
      body = trashAsync.hasError
          ? ErrorState(
              message: friendlyError(trashAsync.error),
              onRetry: () => ref.invalidate(menuTrashProvider),
            )
          : const SkeletonList(rows: 4);
    } else if (trash.isEmpty) {
      body = const EmptyState(
        icon: Icons.delete_outline_rounded,
        title: 'The trash is empty',
        message:
            'Dishes and categories you delete wait here until you remove them '
            'for good, so a mistake is easy to undo.',
      );
    } else {
      final now = DateTime.now();
      final items = [...trash.items]..sort((a, b) => _when(b.deletedAt).compareTo(_when(a.deletedAt)));
      final cats = [...trash.categories]..sort((a, b) => _when(b.deletedAt).compareTo(_when(a.deletedAt)));
      final nameOf = {
        for (final c in [...liveCategories, ...trash.categories]) c.id: c.displayName,
      };
      body = RefreshIndicator(
        onRefresh: () async => ref.invalidate(menuTrashProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
          children: [
            if (items.isNotEmpty) ...[
              SectionTitle('Dishes (${items.length})'),
              for (final item in items)
                _TrashRow(
                  key: ValueKey('item-${item.id}'),
                  title: item.displayName,
                  subtitle: [
                    if (nameOf[item.categoryId] != null) 'in ${nameOf[item.categoryId]}',
                    if (item.deletedAt != null) 'Deleted ${relativeTime(item.deletedAt!, now)}',
                  ].join('  -  '),
                  imageUrl: item.coverImage,
                  icon: Icons.restaurant_menu_rounded,
                  busy: _busy.contains('item:${item.id}') || _busy.contains('all'),
                  onRestore: () => _restoreItem(item, trash),
                  onDelete: () => _deleteItemForever(item),
                ),
              const SizedBox(height: Sp.lg),
            ],
            if (cats.isNotEmpty) ...[
              SectionTitle('Categories (${cats.length})'),
              for (final category in cats)
                _TrashRow(
                  key: ValueKey('cat-${category.id}'),
                  title: category.displayName,
                  subtitle: [
                    '${trash.items.where((i) => i.categoryId == category.id).length} dishes inside',
                    if (category.deletedAt != null) 'Deleted ${relativeTime(category.deletedAt!, now)}',
                  ].join('  -  '),
                  imageUrl: category.imageUrl,
                  icon: categoryIconFor(category.icon) ?? Icons.category_outlined,
                  busy: _busy.contains('cat:${category.id}') || _busy.contains('all'),
                  onRestore: () => _run(
                    'cat:${category.id}',
                    () => ref.read(menuRepositoryProvider).restoreCategory(category.id),
                    success: 'Category and its dishes restored',
                  ),
                  onDelete: () => _deleteCategoryForever(category, trash),
                ),
            ],
          ],
        ),
      );
    }

    return AppPage(
      title: 'Trash',
      subtitle: trash == null || trash.isEmpty
          ? 'Deleted items wait here'
          : '${trash.count} deleted ${trash.count == 1 ? 'item' : 'items'}',
      scroll: false,
      actions: [
        if (trash != null && !trash.isEmpty)
          TextButton.icon(
            onPressed: _busy.contains('all') ? null : () => _emptyTrash(trash),
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            label: const Text('Empty trash'),
          ),
      ],
      body: body,
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData icon;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.md),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MenuThumb(url: imageUrl, icon: icon, size: 48, dimmed: true),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                icon: Icon(Icons.delete_forever_outlined, size: 18, color: busy ? null : palette.danger),
                label: Text('Delete forever', style: TextStyle(color: busy ? null : palette.danger)),
              ),
              const SizedBox(width: Sp.xs),
              AppButton(
                label: 'Restore',
                icon: Icons.restore_rounded,
                kind: AppButtonKind.tonal,
                loading: busy,
                onPressed: onRestore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
