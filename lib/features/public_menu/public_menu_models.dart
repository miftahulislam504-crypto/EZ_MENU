import '../../core/logic/pricing.dart';
import '../../core/utils/json_utils.dart';

/// The customer menu as the database function `get_public_menu` returns it.
/// Pure Dart (no Flutter imports) so parsing is unit tested.

/// Why a menu could not be shown. Matches the `error` values of the function.
enum PublicMenuProblem {
  notFound,
  qrInactive,
  tableInactive,
  branchInactive,
  unpublished,
  unknown;

  static PublicMenuProblem parse(String? code) {
    switch (code) {
      case 'not_found':
        return PublicMenuProblem.notFound;
      case 'qr_inactive':
        return PublicMenuProblem.qrInactive;
      case 'table_inactive':
        return PublicMenuProblem.tableInactive;
      case 'branch_inactive':
        return PublicMenuProblem.branchInactive;
      case 'unpublished':
        return PublicMenuProblem.unpublished;
      default:
        return PublicMenuProblem.unknown;
    }
  }
}

/// What the function returned: a menu, or the reason there is none.
class PublicMenuResult {
  const PublicMenuResult.menu(PublicMenuData this.data) : problem = null;
  const PublicMenuResult.failure(PublicMenuProblem this.problem) : data = null;

  final PublicMenuData? data;
  final PublicMenuProblem? problem;

  factory PublicMenuResult.fromJson(Object? json) {
    if (json is! Map) return const PublicMenuResult.failure(PublicMenuProblem.unknown);
    final map = Map<String, dynamic>.from(json);
    final error = map.str('error');
    if (error != null) return PublicMenuResult.failure(PublicMenuProblem.parse(error));
    try {
      return PublicMenuResult.menu(PublicMenuData.fromJson(map));
    } catch (_) {
      return const PublicMenuResult.failure(PublicMenuProblem.unknown);
    }
  }
}

class PublicBusiness {
  const PublicBusiness({
    required this.id,
    required this.slug,
    this.nameEn,
    this.nameBn,
    this.businessType = 'restaurant',
    this.logoUrl,
    this.coverUrl,
    this.phone,
    this.email,
    this.address,
    this.mapUrl,
    this.descriptionEn,
    this.descriptionBn,
    this.websiteUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.youtubeUrl,
    this.whatsappNumber,
    this.currency = 'BDT',
    this.defaultLanguage = 'bn',
    this.timezone = 'Asia/Dhaka',
    this.brandColor = '#166A4C',
    this.menuTheme = 'light',
    this.menuLayout = 'list',
    this.welcomeEn,
    this.welcomeBn,
    this.termsEn,
    this.termsBn,
    this.refundEn,
    this.refundBn,
    this.allergenNoticeEn,
    this.allergenNoticeBn,
  });

  final String id;
  final String slug;
  final String? nameEn;
  final String? nameBn;
  final String businessType;
  final String? logoUrl;
  final String? coverUrl;
  final String? phone;
  final String? email;
  final String? address;
  final String? mapUrl;
  final String? descriptionEn;
  final String? descriptionBn;
  final String? websiteUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;
  final String? whatsappNumber;
  final String currency;
  final String defaultLanguage;
  final String timezone;
  final String brandColor;
  final String menuTheme;
  final String menuLayout;
  final String? welcomeEn;
  final String? welcomeBn;
  final String? termsEn;
  final String? termsBn;
  final String? refundEn;
  final String? refundBn;
  final String? allergenNoticeEn;
  final String? allergenNoticeBn;

  bool get startsInBangla => defaultLanguage == 'bn';
  bool get isGrid => menuLayout == 'grid';

  factory PublicBusiness.fromJson(Map<String, dynamic> j) => PublicBusiness(
    id: j.requireStr('id'),
    slug: j.requireStr('slug'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    businessType: j.str('business_type') ?? 'restaurant',
    logoUrl: j.str('logo_url'),
    coverUrl: j.str('cover_url'),
    phone: j.str('phone'),
    email: j.str('email'),
    address: j.str('address'),
    mapUrl: j.str('map_url'),
    descriptionEn: j.str('description_en'),
    descriptionBn: j.str('description_bn'),
    websiteUrl: j.str('website_url'),
    facebookUrl: j.str('facebook_url'),
    instagramUrl: j.str('instagram_url'),
    tiktokUrl: j.str('tiktok_url'),
    youtubeUrl: j.str('youtube_url'),
    whatsappNumber: j.str('whatsapp_number'),
    currency: j.str('currency') ?? 'BDT',
    defaultLanguage: j.str('default_language') ?? 'bn',
    timezone: j.str('timezone') ?? 'Asia/Dhaka',
    brandColor: j.str('brand_color') ?? '#166A4C',
    menuTheme: j.str('menu_theme') ?? 'light',
    menuLayout: j.str('menu_layout') ?? 'list',
    welcomeEn: j.str('welcome_message_en'),
    welcomeBn: j.str('welcome_message_bn'),
    termsEn: j.str('terms_en'),
    termsBn: j.str('terms_bn'),
    refundEn: j.str('refund_policy_en'),
    refundBn: j.str('refund_policy_bn'),
    allergenNoticeEn: j.str('allergen_notice_en'),
    allergenNoticeBn: j.str('allergen_notice_bn'),
  );
}

class PublicBranch {
  const PublicBranch({
    required this.id,
    required this.slug,
    this.nameEn,
    this.nameBn,
    this.address,
    this.area,
    this.phone,
    this.email,
    this.mapUrl,
    this.latitude,
    this.longitude,
    this.tempClosedMessageEn,
    this.tempClosedMessageBn,
    this.outsideHoursBehavior = 'block_orders',
  });

  final String id;
  final String slug;
  final String? nameEn;
  final String? nameBn;
  final String? address;
  final String? area;
  final String? phone;
  final String? email;
  final String? mapUrl;
  final double? latitude;
  final double? longitude;
  final String? tempClosedMessageEn;
  final String? tempClosedMessageBn;
  final String outsideHoursBehavior;

  factory PublicBranch.fromJson(Map<String, dynamic> j) => PublicBranch(
    id: j.requireStr('id'),
    slug: j.requireStr('slug'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    address: j.str('address'),
    area: j.str('area'),
    phone: j.str('phone'),
    email: j.str('email'),
    mapUrl: j.str('map_url'),
    latitude: j.numberOrNull('latitude'),
    longitude: j.numberOrNull('longitude'),
    tempClosedMessageEn: j.str('temp_closed_message_en'),
    tempClosedMessageBn: j.str('temp_closed_message_bn'),
    outsideHoursBehavior: j.str('outside_hours_behavior') ?? 'block_orders',
  );
}

/// A sibling branch for the branch switcher.
class PublicBranchLink {
  const PublicBranchLink({required this.slug, this.nameEn, this.nameBn, this.area});

  final String slug;
  final String? nameEn;
  final String? nameBn;
  final String? area;

  factory PublicBranchLink.fromJson(Map<String, dynamic> j) => PublicBranchLink(
    slug: j.requireStr('slug'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    area: j.str('area'),
  );
}

/// Whether the branch is open right now, from `branch_status`.
class BranchStatus {
  const BranchStatus({
    this.status = 'closed',
    this.isOpen = false,
    this.closesAt,
    this.opensAt,
    this.until,
  });

  /// `open`, `closed` or `temporarily_closed`.
  final String status;
  final bool isOpen;

  /// `HH:mm:ss` when open.
  final String? closesAt;

  /// `HH:mm:ss` when closed and it opens later today.
  final String? opensAt;

  /// When a temporary closure ends, if known.
  final DateTime? until;

  bool get isTemporarilyClosed => status == 'temporarily_closed';

  factory BranchStatus.fromJson(Map<String, dynamic> j) => BranchStatus(
    status: j.str('status') ?? 'closed',
    isOpen: j.boolean('is_open'),
    closesAt: j.str('closes_at'),
    opensAt: j.str('opens_at'),
    until: j.date('until'),
  );
}

/// One weekly opening period.
class PublicHourRow {
  const PublicHourRow({
    required this.weekday,
    required this.open,
    required this.close,
    this.labelEn,
    this.labelBn,
  });

  final int weekday;
  final String open;
  final String close;
  final String? labelEn;
  final String? labelBn;

  factory PublicHourRow.fromJson(Map<String, dynamic> j) => PublicHourRow(
    weekday: j.integer('weekday', fallback: 1),
    open: j.requireStr('open_time'),
    close: j.requireStr('close_time'),
    labelEn: j.str('label_en'),
    labelBn: j.str('label_bn'),
  );
}

/// A holiday or special day, from today on.
class PublicSpecialHour {
  const PublicSpecialHour({
    required this.date,
    this.endDate,
    this.isClosed = false,
    this.open,
    this.close,
    this.labelEn,
    this.labelBn,
  });

  /// `yyyy-MM-dd`.
  final String date;
  final String? endDate;
  final bool isClosed;
  final String? open;
  final String? close;
  final String? labelEn;
  final String? labelBn;

  factory PublicSpecialHour.fromJson(Map<String, dynamic> j) => PublicSpecialHour(
    date: j.requireStr('date'),
    endDate: j.str('end_date'),
    isClosed: j.boolean('is_closed'),
    open: j.str('open_time'),
    close: j.str('close_time'),
    labelEn: j.str('label_en'),
    labelBn: j.str('label_bn'),
  );
}

/// How the customer arrived.
class PublicContext {
  const PublicContext({this.kind = 'menu', this.qrToken, this.tableId, this.tableName});

  /// `menu` (a link or the branch code), `takeaway` or `table`.
  final String kind;
  final String? qrToken;
  final String? tableId;
  final String? tableName;

  bool get isTable => tableName != null && tableName!.trim().isNotEmpty;
  bool get isTakeaway => kind == 'takeaway';

  factory PublicContext.fromJson(Map<String, dynamic> j) => PublicContext(
    kind: j.str('kind') ?? 'menu',
    qrToken: j.str('qr_token'),
    tableId: j.str('table_id'),
    tableName: j.str('table_name'),
  );
}

class PublicCategory {
  const PublicCategory({
    required this.id,
    this.parentId,
    this.nameEn,
    this.nameBn,
    this.descriptionEn,
    this.descriptionBn,
    this.imageUrl,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String? parentId;
  final String? nameEn;
  final String? nameBn;
  final String? descriptionEn;
  final String? descriptionBn;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;

  factory PublicCategory.fromJson(Map<String, dynamic> j) => PublicCategory(
    id: j.requireStr('id'),
    parentId: j.str('parent_id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    descriptionEn: j.str('description_en'),
    descriptionBn: j.str('description_bn'),
    imageUrl: j.str('image_url'),
    icon: j.str('icon'),
    sortOrder: j.integer('sort_order'),
  );
}

class PublicOption {
  const PublicOption({
    required this.id,
    this.nameEn,
    this.nameBn,
    this.price = 0,
    this.discountPrice,
    this.imageUrl,
    this.isDefault = false,
    this.isAvailable = true,
  });

  final String id;
  final String? nameEn;
  final String? nameBn;
  final double price;
  final double? discountPrice;
  final String? imageUrl;
  final bool isDefault;
  final bool isAvailable;

  factory PublicOption.fromJson(Map<String, dynamic> j) => PublicOption(
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

class PublicOptionGroup {
  const PublicOptionGroup({
    required this.id,
    this.nameEn,
    this.nameBn,
    this.multiple = false,
    this.mode = OptionPriceMode.additional,
    this.isRequired = false,
    this.minSelect = 0,
    this.maxSelect,
    this.options = const [],
  });

  final String id;
  final String? nameEn;
  final String? nameBn;
  final bool multiple;
  final OptionPriceMode mode;
  final bool isRequired;
  final int minSelect;
  final int? maxSelect;
  final List<PublicOption> options;

  /// The shape `computeItemPrice` works with.
  PricedGroup toPriced() => PricedGroup(
    id: id,
    multiple: multiple,
    mode: mode,
    isRequired: isRequired,
    minSelect: minSelect,
    maxSelect: maxSelect,
    options: [
      for (final option in options)
        PricedOption(
          id: option.id,
          price: option.price,
          discountPrice: option.discountPrice,
          isAvailable: option.isAvailable,
        ),
    ],
  );

  factory PublicOptionGroup.fromJson(Map<String, dynamic> j) => PublicOptionGroup(
    id: j.requireStr('id'),
    nameEn: j.str('name_en'),
    nameBn: j.str('name_bn'),
    multiple: j.str('select_type') == 'multiple',
    mode: j.str('price_mode') == 'absolute'
        ? OptionPriceMode.absolute
        : OptionPriceMode.additional,
    isRequired: j.boolean('is_required'),
    minSelect: j.integer('min_select'),
    maxSelect: j.intOrNull('max_select'),
    options: [for (final row in j.mapList('options')) PublicOption.fromJson(row)],
  );
}

class PublicSchedule {
  const PublicSchedule({
    this.weekdays = const [],
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
  });

  final List<int> weekdays;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;

  factory PublicSchedule.fromJson(Map<String, dynamic> j) {
    final days = j['weekdays'];
    return PublicSchedule(
      weekdays: days is List
          ? [
              for (final day in days)
                if (day is num) day.toInt() else if (int.tryParse('$day') != null) int.parse('$day'),
            ]
          : const [],
      startTime: j.str('start_time'),
      endTime: j.str('end_time'),
      startDate: j.str('start_date'),
      endDate: j.str('end_date'),
    );
  }
}

enum ItemAvailability {
  available,
  soldOut,

  /// Not offered at this time of day or on this day.
  scheduled;

  static ItemAvailability parse(String? value) {
    switch (value) {
      case 'sold_out':
        return ItemAvailability.soldOut;
      case 'scheduled':
        return ItemAvailability.scheduled;
      default:
        return ItemAvailability.available;
    }
  }

  bool get canOrder => this == ItemAvailability.available;
}

class PublicItem {
  const PublicItem({
    required this.id,
    required this.categoryId,
    this.nameEn,
    this.nameBn,
    this.shortEn,
    this.shortBn,
    this.descriptionEn,
    this.descriptionBn,
    this.ingredientsEn,
    this.ingredientsBn,
    this.price = 0,
    this.discountPrice,
    this.prepTimeMin,
    this.labels = const [],
    this.allergens = const [],
    this.allergenNote,
    this.dietaryInfo,
    this.spiceLevel,
    this.calories,
    this.nutrition = const {},
    this.imageUrls = const [],
    this.isFeatured = false,
    this.sortOrder = 0,
    this.availability = ItemAvailability.available,
    this.schedules = const [],
    this.optionGroups = const [],
  });

  final String id;
  final String categoryId;
  final String? nameEn;
  final String? nameBn;
  final String? shortEn;
  final String? shortBn;
  final String? descriptionEn;
  final String? descriptionBn;
  final String? ingredientsEn;
  final String? ingredientsBn;

  /// Price for this branch (a branch price replaces the main price).
  final double price;
  final double? discountPrice;
  final int? prepTimeMin;
  final List<String> labels;
  final List<String> allergens;
  final String? allergenNote;
  final String? dietaryInfo;
  final int? spiceLevel;
  final int? calories;

  /// Nutrition values by key (`protein_g`...).
  final Map<String, double> nutrition;
  final List<String> imageUrls;
  final bool isFeatured;
  final int sortOrder;
  final ItemAvailability availability;
  final List<PublicSchedule> schedules;
  final List<PublicOptionGroup> optionGroups;

  String? get firstImage => imageUrls.isEmpty ? null : imageUrls.first;
  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  bool hasLabel(String id) => labels.contains(id);

  factory PublicItem.fromJson(Map<String, dynamic> j) {
    final nutritionRaw = j['nutrition'];
    final nutrition = <String, double>{};
    if (nutritionRaw is Map) {
      nutritionRaw.forEach((key, value) {
        final number = value is num ? value.toDouble() : double.tryParse('$value');
        if (number != null) nutrition['$key'] = number;
      });
    }
    return PublicItem(
      id: j.requireStr('id'),
      categoryId: j.requireStr('category_id'),
      nameEn: j.str('name_en'),
      nameBn: j.str('name_bn'),
      shortEn: j.str('short_description_en'),
      shortBn: j.str('short_description_bn'),
      descriptionEn: j.str('description_en'),
      descriptionBn: j.str('description_bn'),
      ingredientsEn: j.str('ingredients_en'),
      ingredientsBn: j.str('ingredients_bn'),
      price: j.number('price'),
      discountPrice: j.numberOrNull('discount_price'),
      prepTimeMin: j.intOrNull('prep_time_min'),
      labels: j.stringList('labels'),
      allergens: j.stringList('allergens'),
      allergenNote: j.str('allergen_note'),
      dietaryInfo: j.str('dietary_info'),
      spiceLevel: j.intOrNull('spice_level'),
      calories: j.intOrNull('calories'),
      nutrition: nutrition,
      imageUrls: j.stringList('image_urls'),
      isFeatured: j.boolean('is_featured'),
      sortOrder: j.integer('sort_order'),
      availability: ItemAvailability.parse(j.str('availability')),
      schedules: [for (final row in j.mapList('schedules')) PublicSchedule.fromJson(row)],
      optionGroups: [
        for (final row in j.mapList('option_groups')) PublicOptionGroup.fromJson(row),
      ],
    );
  }
}

/// The whole payload.
class PublicMenuData {
  const PublicMenuData({
    required this.business,
    required this.branch,
    this.branches = const [],
    this.status = const BranchStatus(),
    this.weeklyHours = const [],
    this.specialHours = const [],
    this.context = const PublicContext(),
    this.categories = const [],
    this.items = const [],
    this.isPreview = false,
    this.generatedAt,
  });

  final PublicBusiness business;
  final PublicBranch branch;
  final List<PublicBranchLink> branches;
  final BranchStatus status;
  final List<PublicHourRow> weeklyHours;
  final List<PublicSpecialHour> specialHours;
  final PublicContext context;
  final List<PublicCategory> categories;
  final List<PublicItem> items;

  /// True when an owner or staff member looks at it (scans are not counted).
  final bool isPreview;
  final DateTime? generatedAt;

  bool get hasMultipleBranches => branches.length > 1;

  factory PublicMenuData.fromJson(Map<String, dynamic> j) {
    final hours = j.jsonMap('hours');
    return PublicMenuData(
      business: PublicBusiness.fromJson(j.jsonMap('business')),
      branch: PublicBranch.fromJson(j.jsonMap('branch')),
      branches: [for (final row in j.mapList('branches')) PublicBranchLink.fromJson(row)],
      status: BranchStatus.fromJson(j.jsonMap('status')),
      weeklyHours: [for (final row in hours.mapList('weekly')) PublicHourRow.fromJson(row)],
      specialHours: [for (final row in hours.mapList('special')) PublicSpecialHour.fromJson(row)],
      context: PublicContext.fromJson(j.jsonMap('context')),
      categories: [for (final row in j.mapList('categories')) PublicCategory.fromJson(row)],
      items: [for (final row in j.mapList('items')) PublicItem.fromJson(row)],
      isPreview: j.boolean('is_preview'),
      generatedAt: j.date('generated_at'),
    );
  }
}
