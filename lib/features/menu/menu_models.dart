import '../../core/logic/hours.dart';
import '../../core/logic/localized.dart';
import '../../core/utils/json_utils.dart';

/// A menu section such as Starters or Drinks. A category can hold one level of
/// subcategories (`parentId` points at the top level category).
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.businessId,
    this.parentId,
    this.nameEn,
    this.nameBn,
    this.descriptionEn,
    this.descriptionBn,
    this.imageUrl,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.deletedAt,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String? parentId;
  final String? nameEn;
  final String? nameBn;
  final String? descriptionEn;
  final String? descriptionBn;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  bool get isSub => parentId != null;
  bool get isDeleted => deletedAt != null;

  /// Name for the English dashboard (falls back to Bangla).
  String get displayName =>
      dashboardName(nameEn, nameBn, fallback: 'Untitled category');

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
    id: j.requireStr('id'),
    businessId: j.requireStr('business_id'),
    parentId: j.str('parent_id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    descriptionEn: j.str('description_en'),
    descriptionBn: j.str('description_bn'),
    imageUrl: j.str('image_url'),
    icon: j.str('icon'),
    sortOrder: j.integer('sort_order'),
    isActive: j.boolean('is_active', fallback: true),
    deletedAt: j.date('deleted_at'),
    createdAt: j.date('created_at'),
  );
}

/// A dish or drink.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.businessId,
    required this.categoryId,
    this.nameEn,
    this.nameBn,
    this.shortDescriptionEn,
    this.shortDescriptionBn,
    this.descriptionEn,
    this.descriptionBn,
    this.ingredientsEn,
    this.ingredientsBn,
    this.price = 0,
    this.discountPrice,
    this.prepTimeMin,
    this.sku,
    this.labels = const [],
    this.allergens = const [],
    this.allergenNote,
    this.dietaryInfo,
    this.spiceLevel,
    this.calories,
    this.nutrition = const {},
    this.imageUrls = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.isSoldOut = false,
    this.soldOutUntil,
    this.sortOrder = 0,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String categoryId;
  final String? nameEn;
  final String? nameBn;
  final String? shortDescriptionEn;
  final String? shortDescriptionBn;
  final String? descriptionEn;
  final String? descriptionBn;
  final String? ingredientsEn;
  final String? ingredientsBn;
  final double price;
  final double? discountPrice;
  final int? prepTimeMin;
  final String? sku;
  final List<String> labels;
  final List<String> allergens;
  final String? allergenNote;
  final String? dietaryInfo;
  final int? spiceLevel;
  final int? calories;

  /// Values keyed by the ids in `nutritionFields` (numbers).
  final Map<String, dynamic> nutrition;
  final List<String> imageUrls;
  final bool isActive;
  final bool isFeatured;
  final bool isSoldOut;
  final DateTime? soldOutUntil;
  final int sortOrder;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDeleted => deletedAt != null;
  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  double get effectivePrice => hasDiscount ? discountPrice! : price;
  String? get coverImage => imageUrls.isEmpty ? null : imageUrls.first;

  String get displayName =>
      dashboardName(nameEn, nameBn, fallback: 'Untitled dish');

  /// Sold out right now: the master switch is on and any "back at" time has
  /// not passed yet.
  bool isSoldOutAt(DateTime now) =>
      isSoldOut && (soldOutUntil == null || soldOutUntil!.isAfter(now));

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j.requireStr('id'),
    businessId: j.requireStr('business_id'),
    categoryId: j.requireStr('category_id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    shortDescriptionEn: j.str('short_description_en'),
    shortDescriptionBn: j.str('short_description_bn'),
    descriptionEn: j.str('description_en'),
    descriptionBn: j.str('description_bn'),
    ingredientsEn: j.str('ingredients_en'),
    ingredientsBn: j.str('ingredients_bn'),
    price: j.number('price'),
    discountPrice: j.numberOrNull('discount_price'),
    prepTimeMin: j.intOrNull('prep_time_min'),
    sku: j.str('sku'),
    labels: j.stringList('labels'),
    allergens: j.stringList('allergens'),
    allergenNote: j.str('allergen_note'),
    dietaryInfo: j.str('dietary_info'),
    spiceLevel: j.intOrNull('spice_level'),
    calories: j.intOrNull('calories'),
    nutrition: j.jsonMap('nutrition'),
    imageUrls: j.stringList('image_urls'),
    isActive: j.boolean('is_active', fallback: true),
    isFeatured: j.boolean('is_featured'),
    isSoldOut: j.boolean('is_sold_out'),
    soldOutUntil: j.date('sold_out_until'),
    sortOrder: j.integer('sort_order'),
    deletedAt: j.date('deleted_at'),
    createdAt: j.date('created_at'),
    updatedAt: j.date('updated_at'),
  );
}

/// One choice inside an option group, for example "Large" or "Extra cheese".
class ItemOption {
  const ItemOption({
    required this.id,
    this.nameEn,
    this.nameBn,
    this.price = 0,
    this.discountPrice,
    this.imageUrl,
    this.isDefault = false,
    this.isAvailable = true,
  });

  /// Client generated uuid for new options, so saving can tell new from old.
  final String id;
  final String? nameEn;
  final String? nameBn;
  final double price;
  final double? discountPrice;
  final String? imageUrl;
  final bool isDefault;
  final bool isAvailable;

  String get displayName => dashboardName(nameEn, nameBn, fallback: 'Option');

  ItemOption copyWith({
    String? nameEn,
    String? nameBn,
    double? price,
    double? discountPrice,
    bool clearDiscount = false,
    String? imageUrl,
    bool clearImage = false,
    bool? isDefault,
    bool? isAvailable,
  }) => ItemOption(
    id: id,
    nameEn: nameEn ?? this.nameEn,
    nameBn: nameBn ?? this.nameBn,
    price: price ?? this.price,
    discountPrice: clearDiscount ? null : (discountPrice ?? this.discountPrice),
    imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    isDefault: isDefault ?? this.isDefault,
    isAvailable: isAvailable ?? this.isAvailable,
  );

  factory ItemOption.fromJson(Map<String, dynamic> j) => ItemOption(
    id: j.requireStr('id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    price: j.number('price'),
    discountPrice: j.numberOrNull('discount_price'),
    imageUrl: j.str('image_url'),
    isDefault: j.boolean('is_default'),
    isAvailable: j.boolean('is_available', fallback: true),
  );
}

/// A group of choices such as "Size" (single, price replaces the item price)
/// or "Extras" (multiple, price is added).
class OptionGroup {
  const OptionGroup({
    required this.id,
    this.nameEn,
    this.nameBn,
    this.selectType = 'single',
    this.priceMode = 'additional',
    this.isRequired = false,
    this.minSelect = 0,
    this.maxSelect,
    this.options = const [],
  });

  final String id;
  final String? nameEn;
  final String? nameBn;

  /// `single` or `multiple`.
  final String selectType;

  /// `additional` adds the option price; `absolute` replaces the item price.
  final String priceMode;
  final bool isRequired;
  final int minSelect;
  final int? maxSelect;
  final List<ItemOption> options;

  bool get isSingle => selectType == 'single';
  bool get isAbsolute => priceMode == 'absolute';

  String get displayName => dashboardName(nameEn, nameBn, fallback: 'Group');

  OptionGroup copyWith({
    String? nameEn,
    String? nameBn,
    String? selectType,
    String? priceMode,
    bool? isRequired,
    int? minSelect,
    int? maxSelect,
    bool clearMax = false,
    List<ItemOption>? options,
  }) => OptionGroup(
    id: id,
    nameEn: nameEn ?? this.nameEn,
    nameBn: nameBn ?? this.nameBn,
    selectType: selectType ?? this.selectType,
    priceMode: priceMode ?? this.priceMode,
    isRequired: isRequired ?? this.isRequired,
    minSelect: minSelect ?? this.minSelect,
    maxSelect: clearMax ? null : (maxSelect ?? this.maxSelect),
    options: options ?? this.options,
  );

  factory OptionGroup.fromJson(
    Map<String, dynamic> j, {
    List<ItemOption> options = const [],
  }) => OptionGroup(
    id: j.requireStr('id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    selectType: j.str('select_type') ?? 'single',
    priceMode: j.str('price_mode') ?? 'additional',
    isRequired: j.boolean('is_required'),
    minSelect: j.integer('min_select'),
    maxSelect: j.intOrNull('max_select'),
    options: options,
  );
}

/// A window when an item can be ordered. An item with no windows is always
/// available; several windows are alternatives.
class ItemSchedule {
  const ItemSchedule({
    this.id,
    this.weekdays = const [],
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.label,
  });

  final String? id;

  /// ISO weekdays, 1 = Monday ... 7 = Sunday. Empty means every day.
  final List<int> weekdays;

  /// `HH:mm`, both null for all day.
  final String? startTime;
  final String? endTime;

  /// `yyyy-MM-dd`.
  final String? startDate;
  final String? endDate;
  final String? label;

  ItemSchedule copyWith({
    List<int>? weekdays,
    String? startTime,
    String? endTime,
    bool clearTimes = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? label,
  }) => ItemSchedule(
    id: id,
    weekdays: weekdays ?? this.weekdays,
    startTime: clearTimes ? null : (startTime ?? this.startTime),
    endTime: clearTimes ? null : (endTime ?? this.endTime),
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    label: label ?? this.label,
  );

  Map<String, dynamic> toRow(String itemId) => {
    'item_id': itemId,
    'weekdays': weekdays,
    'start_time': startTime,
    'end_time': endTime,
    'start_date': startDate,
    'end_date': endDate,
    'label': emptyToNull(label),
  };

  factory ItemSchedule.fromJson(Map<String, dynamic> j) {
    String? clock(String key) {
      final parsed = parseClock(j.str(key));
      return parsed == null ? null : clockToDb(parsed);
    }

    final days = j['weekdays'];
    return ItemSchedule(
      id: j.str('id'),
      weekdays: days is List
          ? [for (final d in days) if (d is num) d.toInt()]
          : const <int>[],
      startTime: clock('start_time'),
      endTime: clock('end_time'),
      startDate: j.str('start_date'),
      endDate: j.str('end_date'),
      label: j.str('label'),
    );
  }
}

/// What one branch changes for one item: hide it, give it another price, or
/// mark it sold out there only.
class BranchItemSetting {
  const BranchItemSetting({
    required this.branchId,
    required this.itemId,
    this.isOffered = true,
    this.price,
    this.discountPrice,
    this.isSoldOut = false,
    this.soldOutUntil,
  });

  final String branchId;
  final String itemId;
  final bool isOffered;

  /// When set, replaces BOTH the regular and the discounted price here.
  final double? price;
  final double? discountPrice;
  final bool isSoldOut;
  final DateTime? soldOutUntil;

  bool get hasPriceOverride => price != null;

  bool isSoldOutAt(DateTime now) =>
      isSoldOut && (soldOutUntil == null || soldOutUntil!.isAfter(now));

  BranchItemSetting copyWith({
    bool? isOffered,
    double? price,
    bool clearPrice = false,
    double? discountPrice,
    bool clearDiscount = false,
    bool? isSoldOut,
    DateTime? soldOutUntil,
    bool clearSoldOutUntil = false,
  }) => BranchItemSetting(
    branchId: branchId,
    itemId: itemId,
    isOffered: isOffered ?? this.isOffered,
    price: clearPrice ? null : (price ?? this.price),
    discountPrice: (clearPrice || clearDiscount)
        ? null
        : (discountPrice ?? this.discountPrice),
    isSoldOut: isSoldOut ?? this.isSoldOut,
    soldOutUntil: clearSoldOutUntil ? null : (soldOutUntil ?? this.soldOutUntil),
  );

  Map<String, dynamic> toRow() => {
    'branch_id': branchId,
    'item_id': itemId,
    'is_offered': isOffered,
    'price': price,
    'discount_price': price == null ? null : discountPrice,
    'is_sold_out': isSoldOut,
    'sold_out_until': soldOutUntil?.toUtc().toIso8601String(),
  };

  factory BranchItemSetting.fromJson(Map<String, dynamic> j) =>
      BranchItemSetting(
        branchId: j.requireStr('branch_id'),
        itemId: j.requireStr('item_id'),
        isOffered: j.boolean('is_offered', fallback: true),
        price: j.numberOrNull('price'),
        discountPrice: j.numberOrNull('discount_price'),
        isSoldOut: j.boolean('is_sold_out'),
        soldOutUntil: j.date('sold_out_until'),
      );
}

/// An item with everything the editor needs.
class ItemDetail {
  const ItemDetail({
    required this.item,
    this.groups = const [],
    this.schedules = const [],
    this.branchSettings = const [],
  });

  final MenuItem item;
  final List<OptionGroup> groups;
  final List<ItemSchedule> schedules;
  final List<BranchItemSetting> branchSettings;
}

/// Items and categories in the trash.
class MenuTrash {
  const MenuTrash({this.categories = const [], this.items = const []});

  final List<MenuCategory> categories;
  final List<MenuItem> items;

  bool get isEmpty => categories.isEmpty && items.isEmpty;
  int get count => categories.length + items.length;
}

/// Result of `import_menu_items`.
class ImportResult {
  const ImportResult({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int created;
  final int updated;
  final int skipped;

  /// `{row, message}` pairs; `row` counts from 1 in the order sent.
  final List<({int row, String message})> errors;

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
    created: j.integer('created'),
    updated: j.integer('updated'),
    skipped: j.integer('skipped'),
    errors: [
      for (final e in j.mapList('errors'))
        (row: e.integer('row'), message: e.str('message') ?? 'Invalid row'),
    ],
  );
}
