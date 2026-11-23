import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/logic/menu_catalog.dart';
import '../../core/logic/menu_search.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/storage_service.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/nav.dart';
import '../../core/widgets/widgets.dart';
import 'branch_override_logic.dart';
import 'item_form_logic.dart';
import 'menu_models.dart';
import 'menu_repository.dart';
import 'option_groups_logic.dart';
import 'schedule_logic.dart';
import 'widgets/branch_override_editor.dart';
import 'widgets/editor_common.dart';
import 'widgets/item_form_availability.dart';
import 'widgets/item_form_basics.dart';
import 'widgets/item_form_details.dart';
import 'widgets/item_form_photos.dart';
import 'widgets/item_form_preview.dart';
import 'widgets/item_form_pricing.dart';
import 'widgets/option_groups_editor.dart';

/// Add or edit one dish: basics, photos, pricing, details, variants and
/// add-ons, availability and per-branch overrides.
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.itemId, this.categoryId});

  final String? itemId;
  final String? categoryId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  static const List<String> _textKeys = [
    'nameEn', 'nameBn', 'shortEn', 'shortBn', 'descEn', 'descBn',
    'ingEn', 'ingBn', 'price', 'discount', 'prep', 'sku',
    'allergenNote', 'dietary', 'calories',
  ];

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final ScrollController _scroll = ScrollController();
  final ControllerBag _c = ControllerBag();

  bool _initialized = false;
  String? _savedId;

  // The form.
  String? _categoryId;
  List<String> _labels = [];
  List<String> _allergens = [];
  int? _spice;
  List<String> _images = [];
  bool _isActive = true;
  bool _isFeatured = false;
  bool _isSoldOut = false;
  DateTime? _soldOutUntil;
  List<OptionGroup> _groups = [];
  List<ItemSchedule> _schedules = [];
  List<BranchItemSetting> _branchSettings = [];

  // What is stored, to know what changed.
  String _savedFormSig = '';
  String _savedGroupsSig = '';
  String _savedSchedulesSig = '';
  String _savedBranchSig = '';
  String? _savedCategoryId;
  List<BranchItemSetting> _savedBranchSettings = [];
  Set<String> _savedItemImages = {};
  Set<String> _savedOptionImages = {};

  /// Photos uploaded during this visit, and saved photos that were removed.
  final Set<String> _sessionUploads = {};
  final Set<String> _removedSaved = {};

  bool _submitted = false;
  List<String> _problems = [];
  bool _saving = false;
  bool _savingAnother = false;
  bool _allowPop = false;

  String? get _editingId => widget.itemId ?? _savedId;
  bool get _isEditing => _editingId != null;

  @override
  void dispose() {
    _scroll.dispose();
    _c.dispose();
    super.dispose();
  }

  // ---- form <-> state ---------------------------------------------------------

  ItemFormInput _input() => ItemFormInput(
    nameEn: _c.text('nameEn'),
    nameBn: _c.text('nameBn'),
    shortEn: _c.text('shortEn'),
    shortBn: _c.text('shortBn'),
    descEn: _c.text('descEn'),
    descBn: _c.text('descBn'),
    ingredientsEn: _c.text('ingEn'),
    ingredientsBn: _c.text('ingBn'),
    price: _c.text('price'),
    discountPrice: _c.text('discount'),
    prepTime: _c.text('prep'),
    sku: _c.text('sku'),
    allergenNote: _c.text('allergenNote'),
    dietaryInfo: _c.text('dietary'),
    calories: _c.text('calories'),
    nutrition: {
      for (final f in nutritionFields) f.key: _c.text('nutrition.${f.key}'),
    },
    categoryId: _categoryId,
    labels: _labels,
    allergens: _allergens,
    spiceLevel: _spice,
    imageUrls: _images,
    isActive: _isActive,
    isFeatured: _isFeatured,
    isSoldOut: _isSoldOut,
    soldOutUntil: _soldOutUntil,
  );

  bool get _dirty {
    if (!_initialized) return false;
    return itemFormSignature(_input()) != _savedFormSig ||
        optionGroupsSignature(_groups) != _savedGroupsSig ||
        schedulesSignature(_schedules) != _savedSchedulesSig ||
        branchSettingsSignature(_branchSettings) != _savedBranchSig;
  }

  void _rememberAll() {
    _savedFormSig = itemFormSignature(_input());
    _savedGroupsSig = optionGroupsSignature(_groups);
    _savedSchedulesSig = schedulesSignature(_schedules);
    _savedBranchSig = branchSettingsSignature(_branchSettings);
    _savedCategoryId = _categoryId;
    _savedBranchSettings = List<BranchItemSetting>.of(_branchSettings);
    _savedItemImages = _images.toSet();
    _savedOptionImages = optionImageUrls(_groups);
  }

  void _applyBlank(String? categoryId) {
    for (final key in _textKeys) {
      _c[key].text = '';
    }
    for (final f in nutritionFields) {
      _c['nutrition.${f.key}'].text = '';
    }
    _categoryId = categoryId;
    _labels = [];
    _allergens = [];
    _spice = null;
    _images = [];
    _isActive = true;
    _isFeatured = false;
    _isSoldOut = false;
    _soldOutUntil = null;
    _groups = [];
    _schedules = [];
    _branchSettings = [];
    _savedId = null;
    _submitted = false;
    _problems = [];
    _sessionUploads.clear();
    _removedSaved.clear();
    _rememberAll();
  }

  void _applyDetail(ItemDetail detail) {
    final item = detail.item;
    _c.fill({
      'nameEn': item.nameEn,
      'nameBn': item.nameBn,
      'shortEn': item.shortDescriptionEn,
      'shortBn': item.shortDescriptionBn,
      'descEn': item.descriptionEn,
      'descBn': item.descriptionBn,
      'ingEn': item.ingredientsEn,
      'ingBn': item.ingredientsBn,
      'price': plainNumber(item.price),
      'discount': plainNumber(item.discountPrice),
      'prep': item.prepTimeMin?.toString(),
      'sku': item.sku,
      'allergenNote': item.allergenNote,
      'dietary': item.dietaryInfo,
      'calories': item.calories?.toString(),
    });
    for (final f in nutritionFields) {
      final value = item.nutrition[f.key];
      _c['nutrition.${f.key}'].text = value is num ? plainNumber(value) : '';
    }
    _categoryId = item.categoryId;
    _labels = List<String>.of(item.labels);
    _allergens = List<String>.of(item.allergens);
    _spice = item.spiceLevel;
    _images = List<String>.of(item.imageUrls);
    _isActive = item.isActive;
    _isFeatured = item.isFeatured;
    // A "back on sale" time that has already passed means the dish is on sale
    // again, so the form starts from that state.
    final expired =
        item.soldOutUntil != null && !item.soldOutUntil!.isAfter(DateTime.now());
    _isSoldOut = item.isSoldOut && !expired;
    _soldOutUntil = _isSoldOut ? item.soldOutUntil?.toLocal() : null;
    _groups = List<OptionGroup>.of(detail.groups);
    _schedules = List<ItemSchedule>.of(detail.schedules);
    _branchSettings = List<BranchItemSetting>.of(detail.branchSettings);
    _rememberAll();
  }

  String? _defaultCategory(List<MenuCategory> all) {
    final wanted = widget.categoryId;
    if (wanted != null && all.any((c) => c.id == wanted)) return wanted;
    for (final c in all) {
      if (c.parentId == null) return c.id;
    }
    return all.isEmpty ? null : all.first.id;
  }

  void _initialize(ItemDetail? detail, List<MenuCategory> categories) {
    _initialized = true;
    if (detail != null) {
      _applyDetail(detail);
    } else {
      _applyBlank(_defaultCategory(categories));
    }
    if (mounted) setState(() {});
  }

  // ---- photos ---------------------------------------------------------------

  Future<void> _deleteFiles(Iterable<String> urls) async {
    final service = ref.read(imageUploadServiceProvider);
    for (final url in urls) {
      try {
        await service.deleteByUrl(url);
      } catch (_) {
        // Best effort: an orphaned file does no harm.
      }
    }
  }

  /// Photos of other dishes (also those in the trash) that use these files:
  /// a duplicated dish shares its photos, so they must not be deleted.
  Future<Set<String>> _usedByOtherDishes(Set<String> candidates, String selfId) async {
    if (candidates.isEmpty) return {};
    try {
      final businessId = ref.read(currentBusinessIdProvider);
      if (businessId == null) return candidates;
      final repo = ref.read(menuRepositoryProvider);
      final active = await repo.items(businessId);
      final trashed = await repo.items(businessId, deleted: true);
      return {
        for (final item in [...active, ...trashed])
          if (item.id != selfId)
            for (final url in item.imageUrls)
              if (candidates.contains(url)) url,
      };
    } catch (_) {
      return candidates;
    }
  }

  void _rememberItemImages(List<String> now) {
    _removedSaved.addAll(_savedItemImages.where((u) => !now.contains(u)));
    _savedItemImages = now.toSet();
  }

  Future<void> _cleanupFiles(String itemId) async {
    final current = {..._images, ...optionImageUrls(_groups)};
    final abandoned = _sessionUploads.where((u) => !current.contains(u)).toSet();
    final removed = _removedSaved.where((u) => !current.contains(u)).toSet();
    final blocked = await _usedByOtherDishes(removed, itemId);
    await _deleteFiles({...abandoned, ...removed.difference(blocked)});
    _sessionUploads.clear();
    _removedSaved.clear();
  }

  // ---- save -------------------------------------------------------------------

  Future<void> _save({required bool addAnother}) async {
    if (_saving) return;
    final input = _input();
    final branches = ref.read(branchesProvider).valueOrNull ?? const <Branch>[];
    final basePrice = parseMoneyText(input.price) ?? 0;
    final errors = validateItemForm(input);
    final problems = <String>[
      ...errors.values,
      ...validateOptionGroups(_groups),
      ...validateSchedules(_schedules),
      ...validateBranchSettings(
        _branchSettings,
        basePrice: basePrice,
        branchNames: {for (final b in branches) b.id: b.name},
      ),
    ];
    setState(() {
      _submitted = true;
      _problems = problems;
    });
    _form.currentState?.validate();
    if (problems.isNotEmpty) {
      showToast(context, problems.first, isError: true);
      return;
    }
    final businessId = ref.read(currentBusinessIdProvider);
    if (businessId == null) return;

    setState(() {
      _saving = true;
      _savingAnother = addAnother;
    });
    final repo = ref.read(menuRepositoryProvider);
    try {
      var id = _editingId;
      final categoryChanged = _savedCategoryId != input.categoryId;
      int? sortOrder;
      if (id == null || categoryChanged) {
        final items = await ref.read(menuItemsProvider.future);
        sortOrder = nextItemSortOrder(
          items.where((i) => i.categoryId == input.categoryId && i.id != id),
        );
      }
      final values = itemValues(input, sortOrder: sortOrder);
      if (id == null) {
        final created = await repo.createItem(businessId, values);
        id = created.id;
        _savedId = id;
      } else {
        await repo.updateItem(id, values);
      }
      _savedCategoryId = input.categoryId;
      _savedFormSig = itemFormSignature(input);
      _rememberItemImages(input.imageUrls);

      final groupsSig = optionGroupsSignature(_groups);
      if (groupsSig != _savedGroupsSig) {
        await repo.saveOptionGroups(id, _groups);
        _savedGroupsSig = groupsSig;
        _savedOptionImages = optionImageUrls(_groups);
      }

      final schedulesSig = schedulesSignature(_schedules);
      if (schedulesSig != _savedSchedulesSig) {
        await repo.saveSchedules(id, _schedules);
        _savedSchedulesSig = schedulesSig;
      }

      final withId = withItemId(_branchSettings, id);
      final storedSig = {
        for (final s in _savedBranchSettings) s.branchId: branchSettingSignature(s),
      };
      for (final setting in withId) {
        if (storedSig[setting.branchId] != branchSettingSignature(setting)) {
          await repo.saveBranchSetting(setting);
        }
      }
      for (final branchId in removedBranchIds(_savedBranchSettings, withId)) {
        await repo.clearBranchSetting(branchId, id);
      }
      _branchSettings = withId;
      _savedBranchSettings = List<BranchItemSetting>.of(withId);
      _savedBranchSig = branchSettingsSignature(withId);

      await _cleanupFiles(id);
      ref.refreshMenu();
      if (!mounted) return;

      final wasNew = widget.itemId == null && addAnother;
      if (wasNew) {
        final keepCategory = _categoryId;
        setState(() {
          _applyBlank(keepCategory);
          _saving = false;
          _savingAnother = false;
        });
        showToast(context, 'Dish added. Add the next one.');
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      showToast(context, widget.itemId == null ? 'Dish added' : 'Dish saved');
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) popOrGo(context, AppRoutes.items);
      });
    } catch (error) {
      if (mounted) {
        // The dish may already exist now; a retry updates it instead of
        // creating a second one (see _editingId).
        showToast(
          context,
          _savedId != null && widget.itemId == null
              ? 'The dish was saved, but something else failed: ${friendlyError(error)}'
              : friendlyError(error),
          isError: true,
        );
      }
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _savingAnother = false;
      });
    }
  }

  // ---- leaving, deleting, duplicating ----------------------------------------

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrGo(context, AppRoutes.items);
    });
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
    final saved = {..._savedItemImages, ..._savedOptionImages};
    await _deleteFiles(_sessionUploads.where((u) => !saved.contains(u)));
    if (!mounted) return;
    _leave();
  }

  Future<void> _delete() async {
    final id = _editingId;
    if (id == null) return;
    final name = _c.text('nameEn').isNotEmpty ? _c.text('nameEn') : _c.text('nameBn');
    final confirmed = await confirmAction(
      context,
      title: 'Move "${name.isEmpty ? 'this dish' : name}" to trash?',
      message: 'You can restore it from the trash.',
      confirmLabel: 'Move to trash',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(menuRepositoryProvider);
    final ok = await runWithToast(
      context,
      () => repo.softDeleteItems([id]),
      onError: friendlyError,
    );
    ref.refreshMenu();
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _allowPop = true);
    popOrGo(context, AppRoutes.items);
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('Dish moved to trash'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repo.restoreItem(id);
              ref.refreshMenu();
            } catch (error) {
              messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
            }
          },
        ),
      ),
    );
  }

  Future<void> _duplicate() async {
    final id = _editingId;
    if (id == null) return;
    if (_dirty) {
      showToast(context, 'Save your changes first. A copy is made from the saved dish.');
      return;
    }
    String? newId;
    final ok = await runWithToast(
      context,
      () async {
        newId = await ref.read(menuRepositoryProvider).duplicateItem(id);
      },
      onError: friendlyError,
      successMessage: 'Dish duplicated',
    );
    ref.refreshMenu();
    if (ok && newId != null && mounted) {
      context.push(AppRoutes.itemEdit(newId!));
    }
  }

  // ---- build ------------------------------------------------------------------

  ItemPreviewData _previewData() {
    return ItemPreviewData(
      nameEn: _c.text('nameEn'),
      nameBn: _c.text('nameBn'),
      shortEn: _c.text('shortEn'),
      shortBn: _c.text('shortBn'),
      price: parseMoneyText(_c.text('price')),
      discountPrice: parseMoneyText(_c.text('discount')),
      imageUrl: _images.isEmpty ? null : _images.first,
      labels: _labels,
      spiceLevel: _spice,
      isSoldOut: _isSoldOut,
      isActive: _isActive,
      prepTime: parseWholeNumber(_c.text('prep')),
      optionGroupCount: _groups.length,
    );
  }

  Widget _problemSummary(BuildContext context) {
    if (!_submitted || _problems.isEmpty) return const SizedBox.shrink();
    final shown = _problems.take(6).toList();
    final more = _problems.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: EditorNote(
        'Fix these before saving:\n${shown.map((p) => '- $p').join('\n')}${more > 0 ? '\n- and $more more' : ''}',
        tone: PillTone.danger,
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context, {
    required List<MenuCategory> categories,
    required Business? business,
    required List<Branch> branches,
    required Map<String, String> errors,
    required bool includePreview,
  }) {
    final currency = business?.currency ?? 'BDT';
    final basePrice = parseMoneyText(_c.text('price')) ?? 0;
    final baseDiscount = parseMoneyText(_c.text('discount'));
    return [
      _problemSummary(context),
      ItemBasicsSection(
        controllers: _c,
        errors: errors,
        categories: categories,
        categoryId: _categoryId,
        onCategory: (id) => setState(() => _categoryId = id),
        isFeatured: _isFeatured,
        onFeatured: (v) => setState(() => _isFeatured = v),
        isActive: _isActive,
        onActive: (v) => setState(() => _isActive = v),
      ),
      ItemPhotosSection(
        urls: _images,
        businessId: business?.id ?? ref.read(currentBusinessIdProvider),
        errorText: errors['images'],
        onUploaded: _sessionUploads.add,
        onChanged: (urls) => setState(() => _images = urls),
      ),
      ItemPricingSection(controllers: _c, errors: errors, currency: currency),
      ItemDetailsSection(
        controllers: _c,
        errors: errors,
        labels: _labels,
        onLabels: (v) => setState(() => _labels = v),
        allergens: _allergens,
        onAllergens: (v) => setState(() => _allergens = v),
        spiceLevel: _spice,
        onSpice: (v) => setState(() => _spice = v),
      ),
      FormSection(
        title: 'Variants and add-ons',
        subtitle: 'Sizes, crusts, spice levels and extras that customers choose when ordering.',
        children: [
          OptionGroupsEditor(
            groups: _groups,
            basePrice: basePrice,
            excludeItemId: _editingId,
            onImageUploaded: _sessionUploads.add,
            onChanged: (groups) => setState(() => _groups = groups),
          ),
        ],
      ),
      ItemAvailabilitySection(
        isSoldOut: _isSoldOut,
        soldOutUntil: _soldOutUntil,
        errorText: errors['soldOutUntil'],
        onSoldOut: (on, until) => setState(() {
          _isSoldOut = on;
          _soldOutUntil = on ? until : null;
        }),
        schedules: _schedules,
        onSchedules: (v) => setState(() => _schedules = v),
      ),
      if (branches.isNotEmpty)
        FormSection(
          title: 'Branches',
          subtitle: 'Hide the dish, change its price or mark it sold out at one branch only.',
          children: [
            BranchOverrideEditor(
              branches: branches,
              settings: _branchSettings,
              itemId: _editingId ?? '',
              basePrice: basePrice,
              baseDiscountPrice: baseDiscount,
              onChanged: (v) => setState(() => _branchSettings = v),
            ),
          ],
        ),
      if (includePreview)
        FormSection(
          title: 'Customer card preview',
          subtitle: 'How this dish looks on the customer menu.',
          children: [ItemPreviewCard(data: _previewData(), business: business)],
        ),
    ];
  }

  Widget _saveBar() {
    final isNew = widget.itemId == null;
    final editing = _isEditing;
    return StickyActionBar(
      maxWidth: 1280,
      child: Row(
        children: [
          if (isNew)
            Expanded(
              child: AppButton(
                label: 'Save and add another',
                kind: AppButtonKind.secondary,
                loading: _saving && _savingAnother,
                onPressed: _saving ? null : () => _save(addAnother: true),
              ),
            )
          else
            Expanded(
              child: AppButton(
                label: 'Cancel',
                kind: AppButtonKind.secondary,
                onPressed: _saving
                    ? null
                    : () => _dirty ? _confirmLeave() : popOrGo(context, AppRoutes.items),
              ),
            ),
          const SizedBox(width: Sp.md),
          Expanded(
            flex: 2,
            child: AppButton(
              label: editing && !isNew ? 'Save changes' : (editing ? 'Save dish' : 'Add dish'),
              loading: _saving && !_savingAnother,
              onPressed: _saving ? null : () => _save(addAnother: false),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final detailAsync = widget.itemId == null
        ? null
        : ref.watch(menuItemDetailProvider(widget.itemId!));
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final editingExisting = widget.itemId != null;
    final pageTitle = editingExisting ? 'Edit dish' : 'New dish';

    final categories = categoriesAsync.valueOrNull;
    final detail = detailAsync?.valueOrNull;

    final failure = categoriesAsync.hasError && categories == null
        ? categoriesAsync.error
        : (detailAsync != null && detailAsync.hasError && detail == null ? detailAsync.error : null);
    if (failure != null) {
      return AppPage(
        title: pageTitle,
        scroll: false,
        body: ErrorState(
          message: friendlyError(failure),
          onRetry: () {
            ref.invalidate(menuCategoriesProvider);
            if (widget.itemId != null) ref.invalidate(menuItemDetailProvider(widget.itemId!));
          },
        ),
      );
    }
    if (categories == null || (editingExisting && detail == null)) {
      return AppPage(title: pageTitle, scroll: false, body: const SkeletonList(rows: 5));
    }
    if (detail != null && detail.item.isDeleted) {
      return AppPage(
        title: pageTitle,
        scroll: false,
        body: EmptyState(
          icon: Icons.delete_outline_rounded,
          title: 'This dish is in the trash',
          message: 'Restore it from the trash to edit it again.',
          actionLabel: 'Open trash',
          onAction: () => context.go(AppRoutes.trash),
        ),
      );
    }
    if (!editingExisting && categories.isEmpty) {
      return AppPage(
        title: pageTitle,
        scroll: false,
        body: EmptyState(
          icon: Icons.category_outlined,
          title: 'Add a category first',
          message: 'Every dish belongs to a category, such as Starters or Drinks.',
          actionLabel: 'Add category',
          onAction: () => context.push(AppRoutes.categoryNew),
        ),
      );
    }
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) _initialize(detail, categories);
      });
      return AppPage(title: pageTitle, scroll: false, body: const SkeletonList(rows: 5));
    }

    final errors = _submitted ? validateItemForm(_input()) : const <String, String>{};
    final liveName = _c.text('nameEn').isNotEmpty ? _c.text('nameEn') : _c.text('nameBn');
    final editing = _isEditing;

    return PopScope(
      canPop: !_dirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: AppPage(
        title: editing ? (liveName.isEmpty ? 'Edit dish' : liveName) : 'New dish',
        subtitle: editing ? 'Edit dish' : null,
        maxWidth: 1280,
        scroll: false,
        actions: [
          if (editing)
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (value) {
                if (value == 'preview') context.push(AppRoutes.preview);
                if (value == 'duplicate') _duplicate();
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'preview', child: Text('Open customer preview')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(value: 'delete', child: Text('Move to trash')),
              ],
            ),
        ],
        bottomBar: _saveBar(),
        body: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
          onChanged: () => setState(() {}),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 1000;
              final sections = _sections(
                context,
                categories: categories,
                business: business,
                branches: branches,
                errors: errors,
                includePreview: !twoColumns,
              );
              if (!twoColumns) {
                return SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
                  child: ResponsiveBody(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sections,
                    ),
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sections,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, Sp.sm, Sp.lg, Sp.xxl),
                      child: FormSection(
                        title: 'Customer card preview',
                        subtitle: 'Updates as you type.',
                        children: [
                          ItemPreviewCard(data: _previewData(), business: business),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
