import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/storage_service.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/widgets.dart';
import 'category_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'widgets/category_form_parts.dart';
import 'widgets/menu_ui.dart';

/// Add or edit one category (or a subcategory when [parentId] is given).
class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({super.key, this.categoryId, this.parentId});

  final String? categoryId;
  final String? parentId;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final ControllerBag _c = ControllerBag();

  bool _initialized = false;
  String? _savedId;
  String? _imageUrl;
  String? _originalImageUrl;
  String? _icon;
  String? _parentId;
  bool _isActive = true;
  Map<String, bool> _branchActive = {};
  Map<String, bool> _branchInitial = {};
  final Set<String> _sessionUploads = {};
  Map<String, String> _errors = {};
  String _initialSnapshot = '';
  bool _saving = false;
  bool _allowPop = false;

  String? get _editingId => widget.categoryId ?? _savedId;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _snapshot() => [
    _c.text('nameEn'),
    _c.text('nameBn'),
    _c.text('descEn'),
    _c.text('descBn'),
    _imageUrl ?? '',
    _icon ?? '',
    _parentId ?? '',
    '$_isActive',
    _branchActive.entries.map((e) => '${e.key}:${e.value}').join(','),
  ].join('|');

  bool get _dirty => _initialized && _snapshot() != _initialSnapshot;

  Future<void> _initFrom(MenuCategory? category) async {
    _initialized = true;
    if (category != null) {
      _c.fill({
        'nameEn': category.nameEn,
        'nameBn': category.nameBn,
        'descEn': category.descriptionEn,
        'descBn': category.descriptionBn,
      });
      _imageUrl = category.imageUrl;
      _originalImageUrl = category.imageUrl;
      _icon = category.icon;
      _parentId = category.parentId;
      _isActive = category.isActive;
      try {
        final map = await ref
            .read(menuRepositoryProvider)
            .categorySettingsForCategory(category.id);
        _branchActive = Map<String, bool>.of(map);
        _branchInitial = Map<String, bool>.of(map);
      } catch (_) {
        // Branch switches stay at their default (on); saving will not touch them.
      }
    } else {
      _parentId = widget.parentId;
    }
    _initialSnapshot = _snapshot();
    if (mounted) setState(() {});
  }

  void _imageChanged(String? url) {
    setState(() {
      if (url != null) _sessionUploads.add(url);
      _imageUrl = url;
    });
  }

  Future<void> _deleteFiles(Iterable<String?> urls) async {
    final service = ref.read(imageUploadServiceProvider);
    for (final url in urls) {
      try {
        await service.deleteByUrl(url);
      } catch (_) {
        // Best effort: an orphaned file does no harm.
      }
    }
  }

  Future<void> _save(List<MenuCategory> all, List<Branch> branches) async {
    if (_saving) return;
    final formOk = _form.currentState?.validate() ?? false;
    final id = _editingId;
    final input = CategoryFormInput(
      nameEn: _c.text('nameEn'),
      nameBn: _c.text('nameBn'),
      descriptionEn: _c.text('descEn'),
      descriptionBn: _c.text('descBn'),
      parentId: _parentId,
      selfId: id,
      hasChildren: id != null && all.any((c) => c.parentId == id),
    );
    final errors = validateCategoryForm(input);
    setState(() => _errors = errors);
    if (!formOk || errors.isNotEmpty) {
      showToast(context, errors.values.isEmpty ? 'Check the highlighted fields.' : errors.values.first, isError: true);
      return;
    }
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;

    setState(() => _saving = true);
    try {
      final original = id == null ? null : all.where((c) => c.id == id).firstOrNull;
      final parentChanged = original != null && original.parentId != _parentId;
      int? sortOrder;
      if (original == null || parentChanged) {
        sortOrder = nextSortOrder(
          all.where((c) => c.parentId == _parentId && c.id != id),
        );
      }
      final repo = ref.read(menuRepositoryProvider);
      final saved = await repo.saveCategory(
        id: id,
        businessId: businessId,
        values: categoryValues(
          input,
          imageUrl: _imageUrl,
          icon: _icon,
          isActive: _isActive,
          sortOrder: sortOrder,
        ),
      );
      _savedId = saved.id;

      // Branch switches: write only what changed.
      for (final entry in _branchActive.entries) {
        final before = _branchInitial[entry.key] ?? true;
        if (entry.value != before) {
          await repo.setCategoryActiveAtBranch(
            branchId: entry.key,
            categoryId: saved.id,
            active: entry.value,
          );
        }
      }
      _branchInitial = Map<String, bool>.of(_branchActive);

      // Files that are no longer used.
      final unused = <String?>{
        if (_originalImageUrl != null && _originalImageUrl != _imageUrl) _originalImageUrl,
        ..._sessionUploads.where((u) => u != _imageUrl),
      };
      await _deleteFiles(unused);
      _originalImageUrl = _imageUrl;
      _sessionUploads.clear();

      ref.refreshMenu();
      if (!mounted) return;
      showToast(context, id == null ? 'Category added' : 'Category saved');
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) popOrGo(context, AppRoutes.categories);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, friendlyError(error), isError: true);
      }
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You have changes that are not saved yet.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!leave || !mounted) return;
    await _deleteFiles(_sessionUploads);
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrGo(context, AppRoutes.categories);
    });
  }

  Future<void> _delete(MenuCategory category) async {
    final confirmed = await confirmAction(
      context,
      title: 'Move "${category.displayName}" to trash?',
      message:
          'Its dishes and subcategories move to the trash too. You can '
          'restore everything from the trash.',
      confirmLabel: 'Move to trash',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final ok = await runWithToast(
      context,
      () => repo.softDeleteCategory(category.id),
      onError: friendlyError,
    );
    ref.refreshMenu();
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _allowPop = true);
    popOrGo(context, AppRoutes.categories);
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('Category moved to trash'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repo.restoreCategory(category.id);
              ref.refreshMenu();
            } catch (error) {
              messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
            }
          },
        ),
      ),
    );
  }

  Future<void> _duplicate(MenuCategory category) async {
    final withDishes = await showAppSheet<bool>(
      context,
      title: 'Duplicate this category',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const IconBadge(Icons.copy_all_rounded),
            title: const Text('Copy with its dishes'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          ListTile(
            leading: const IconBadge(Icons.folder_open_rounded),
            title: const Text('Copy as an empty category'),
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: Sp.md),
        ],
      ),
    );
    if (withDishes == null || !mounted) return;
    final ok = await runWithToast(
      context,
      () => ref.read(menuRepositoryProvider).duplicateCategory(category.id, includeItems: withDishes),
      onError: friendlyError,
      successMessage: 'Category duplicated',
    );
    if (ok) ref.refreshMenu();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final all = categoriesAsync.valueOrNull;
    final editing = widget.categoryId != null;

    if (all == null) {
      return AppPage(
        title: editing ? 'Edit category' : 'New category',
        scroll: false,
        body: categoriesAsync.hasError
            ? ErrorState(
                message: friendlyError(categoriesAsync.error),
                onRetry: () => ref.invalidate(menuCategoriesProvider),
              )
            : const SkeletonList(rows: 4),
      );
    }

    final existing = editing ? all.where((c) => c.id == widget.categoryId).firstOrNull : null;
    if (editing && existing == null) {
      return AppPage(
        title: 'Edit category',
        scroll: false,
        body: EmptyState(
          icon: Icons.category_outlined,
          title: 'Category not found',
          message: 'It may have been moved to the trash or deleted.',
          actionLabel: 'Back to categories',
          onAction: () => context.go(AppRoutes.categories),
        ),
      );
    }
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) _initFrom(existing);
      });
      return AppPage(
        title: editing ? 'Edit category' : 'New category',
        scroll: false,
        body: const SkeletonList(rows: 4),
      );
    }

    final id = _editingId;
    final hasChildren = id != null && all.any((c) => c.parentId == id);
    final parentOptions = [
      for (final c in all)
        if (c.parentId == null && c.id != id)
          SelectOption<String>(value: c.id, label: c.displayName),
    ];
    final parentValid = parentOptions.any((o) => o.value == _parentId);
    final multiBranch = branches.length > 1;
    final previewName = _c.text('nameEn').isNotEmpty ? _c.text('nameEn') : _c.text('nameBn');

    return PopScope(
      canPop: !_dirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: AppPage(
        title: editing ? 'Edit category' : (widget.parentId != null ? 'New subcategory' : 'New category'),
        subtitle: existing?.displayName,
        actions: [
          if (existing != null)
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (v) {
                if (v == 'dishes') context.push('${AppRoutes.items}?category=${existing.id}');
                if (v == 'duplicate') _duplicate(existing);
                if (v == 'delete') _delete(existing);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'dishes', child: Text('View dishes')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(value: 'delete', child: Text('Move to trash')),
              ],
            ),
        ],
        bottomBar: StickyActionBar(
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  kind: AppButtonKind.secondary,
                  onPressed: _saving ? null : () => _dirty ? _confirmLeave() : popOrGo(context, AppRoutes.categories),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: editing ? 'Save changes' : 'Add category',
                  loading: _saving,
                  onPressed: () => _save(all, branches),
                ),
              ),
            ],
          ),
        ),
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormSection(
                title: 'Name',
                subtitle: 'Fill in at least one language. Customers see the language they choose.',
                children: [
                  BilingualFields(
                    label: 'Name',
                    englishController: _c['nameEn'],
                    banglaController: _c['nameBn'],
                    requireOne: true,
                    maxLength: 120,
                    hintEnglish: 'Starters',
                    hintBangla: 'শুরুর খাবার',
                  ),
                  BilingualFields(
                    label: 'Description',
                    englishController: _c['descEn'],
                    banglaController: _c['descBn'],
                    optional: true,
                    maxLines: 3,
                    maxLength: 500,
                    hintBangla: 'ছোট একটি বর্ণনা',
                  ),
                ],
              ),
              FormSection(
                title: 'Picture and icon',
                subtitle: 'A picture is shown on the customer menu. Without one, the icon is used.',
                children: [
                  ImagePickerField(
                    label: 'Category picture',
                    imageUrl: _imageUrl,
                    businessId: business?.id ?? ref.read(currentBusinessIdProvider) ?? '',
                    bucket: AppBucket.menu,
                    folder: 'categories',
                    aspectRatio: 16 / 9,
                    onChanged: _imageChanged,
                    helper: 'JPG, PNG or WebP, up to 5 MB. If you set both a picture and an icon, the picture wins.',
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: FieldLabel('Icon', optional: true)),
                          if (_icon != null)
                            TextButton(
                              onPressed: () => setState(() => _icon = null),
                              child: const Text('Clear icon'),
                            ),
                        ],
                      ),
                      CategoryIconPicker(
                        selected: _icon,
                        onChanged: (v) => setState(() => _icon = v),
                      ),
                    ],
                  ),
                ],
              ),
              FormSection(
                title: 'Placement',
                children: [
                  SelectField<String>(
                    label: 'Parent category',
                    optional: true,
                    hint: 'None (top level)',
                    enabled: !hasChildren,
                    options: parentOptions,
                    value: parentValid ? _parentId : null,
                    errorText: _errors['parent'],
                    onChanged: (v) => setState(() => _parentId = v),
                  ),
                  if (hasChildren)
                    Text(
                      'This category has subcategories, so it stays at the top level.',
                      style: context.textStyles.bodySmall?.copyWith(color: context.palette.muted),
                    ),
                  SwitchRow(
                    title: 'Visible to customers',
                    subtitle: 'Turn off to hide this category and its dishes everywhere.',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
              if (multiBranch)
                FormSection(
                  title: 'Branches',
                  subtitle: 'Show this category only at the branches you choose.',
                  children: [
                    CategoryBranchSwitches(
                      branches: branches,
                      values: _branchActive,
                      onChanged: (branchId, active) =>
                          setState(() => _branchActive = {..._branchActive, branchId: active}),
                    ),
                  ],
                ),
              FormSection(
                title: 'Preview',
                subtitle: 'A rough look at how customers will see this category.',
                children: [
                  CategoryPreview(
                    name: previewName,
                    imageUrl: _imageUrl,
                    icon: _icon,
                    business: business,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
