import '../logic/localized.dart';
import '../utils/json_utils.dart';

/// A restaurant, cafe, bakery or other food business.
class Business {
  const Business({
    required this.id,
    required this.ownerId,
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
    this.welcomeMessageEn,
    this.welcomeMessageBn,
    this.termsEn,
    this.termsBn,
    this.refundPolicyEn,
    this.refundPolicyBn,
    this.allergenNoticeEn,
    this.allergenNoticeBn,
    this.soldOutDisplay = 'show',
    this.menuPublished = true,
    this.onboardingStep = 0,
    this.onboardingCompletedAt,
    this.createdAt,
  });

  final String id;
  final String ownerId;
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
  final String? welcomeMessageEn;
  final String? welcomeMessageBn;
  final String? termsEn;
  final String? termsBn;
  final String? refundPolicyEn;
  final String? refundPolicyBn;
  final String? allergenNoticeEn;
  final String? allergenNoticeBn;

  /// 'show' or 'hide' sold-out items on the customer menu.
  final String soldOutDisplay;
  final bool menuPublished;
  final int onboardingStep;
  final DateTime? onboardingCompletedAt;
  final DateTime? createdAt;

  factory Business.fromJson(Map<String, dynamic> j) {
    return Business(
      id: j.requireStr('id'),
      ownerId: j.requireStr('owner_id'),
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
      welcomeMessageEn: j.str('welcome_message_en'),
      welcomeMessageBn: j.str('welcome_message_bn'),
      termsEn: j.str('terms_en'),
      termsBn: j.str('terms_bn'),
      refundPolicyEn: j.str('refund_policy_en'),
      refundPolicyBn: j.str('refund_policy_bn'),
      allergenNoticeEn: j.str('allergen_notice_en'),
      allergenNoticeBn: j.str('allergen_notice_bn'),
      soldOutDisplay: j.str('sold_out_display') ?? 'show',
      menuPublished: j.boolean('menu_published', fallback: true),
      onboardingStep: j.integer('onboarding_step'),
      onboardingCompletedAt: j.date('onboarding_completed_at'),
      createdAt: j.date('created_at'),
    );
  }

  /// Name for the English dashboard.
  String get name => dashboardName(nameEn, nameBn, fallback: 'Your restaurant');

  bool get onboardingComplete => onboardingCompletedAt != null;

  bool get hidesSoldOut => soldOutDisplay == 'hide';
}

/// One location of a business.
class Branch {
  const Branch({
    required this.id,
    required this.businessId,
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
    this.isActive = true,
    this.sortOrder = 0,
    this.tempClosed = false,
    this.tempClosedMessageEn,
    this.tempClosedMessageBn,
    this.tempClosedUntil,
    this.outsideHoursBehavior = 'block_orders',
    this.soldOutDisplay,
    this.createdAt,
  });

  final String id;
  final String businessId;
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
  final bool isActive;
  final int sortOrder;
  final bool tempClosed;
  final String? tempClosedMessageEn;
  final String? tempClosedMessageBn;
  final DateTime? tempClosedUntil;

  /// 'block_orders' or 'allow_scheduled' outside opening hours.
  final String outsideHoursBehavior;

  /// 'show', 'hide' or null (inherit the business setting).
  final String? soldOutDisplay;
  final DateTime? createdAt;

  factory Branch.fromJson(Map<String, dynamic> j) {
    return Branch(
      id: j.requireStr('id'),
      businessId: j.requireStr('business_id'),
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
      isActive: j.boolean('is_active', fallback: true),
      sortOrder: j.integer('sort_order'),
      tempClosed: j.boolean('temp_closed'),
      tempClosedMessageEn: j.str('temp_closed_message_en'),
      tempClosedMessageBn: j.str('temp_closed_message_bn'),
      tempClosedUntil: j.date('temp_closed_until'),
      outsideHoursBehavior: j.str('outside_hours_behavior') ?? 'block_orders',
      soldOutDisplay: j.str('sold_out_display'),
      createdAt: j.date('created_at'),
    );
  }

  String get name => dashboardName(nameEn, nameBn, fallback: 'Branch');

  /// True while a temporary closure is in effect.
  bool get isTemporarilyClosed {
    if (!tempClosed) return false;
    final until = tempClosedUntil;
    return until == null || until.isAfter(DateTime.now());
  }
}
