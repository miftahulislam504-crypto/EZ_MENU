import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/bd_phone.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/storage_service.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import 'business_options.dart';
import 'business_repository.dart';

/// Restaurant details shown to customers and used across the dashboard.
class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessesProvider);
    return business.when(
      skipLoadingOnReload: true,
      loading: () => const AppPage(
        title: 'Restaurant profile',
        scroll: false,
        body: LoadingView(),
      ),
      error: (error, _) => AppPage(
        title: 'Restaurant profile',
        scroll: false,
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(businessesProvider),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const AppPage(
            title: 'Restaurant profile',
            scroll: false,
            body: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No restaurant yet',
              message: 'Finish setup to create your restaurant profile.',
            ),
          );
        }
        return _ProfileForm(business: list.first);
      },
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.business});

  final Business business;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  late String _type;
  late String _currency;
  late String _language;
  late String _timezone;
  String? _logoUrl;
  String? _coverUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _c.fill({
      'name_en': b.nameEn,
      'name_bn': b.nameBn,
      'phone': b.phone,
      'email': b.email,
      'address': b.address,
      'map_url': b.mapUrl,
      'description_en': b.descriptionEn,
      'description_bn': b.descriptionBn,
      'website_url': b.websiteUrl,
      'facebook_url': b.facebookUrl,
      'instagram_url': b.instagramUrl,
      'tiktok_url': b.tiktokUrl,
      'youtube_url': b.youtubeUrl,
      'whatsapp_number': b.whatsappNumber,
    });
    _type = b.businessType;
    _currency = b.currency;
    _language = b.defaultLanguage;
    _timezone = b.timezone;
    _logoUrl = b.logoUrl;
    _coverUrl = b.coverUrl;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? _phone(String key) {
    final raw = _c.nullable(key);
    if (raw == null) return null;
    return BdPhone.normalize(raw) ?? raw;
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runWithToast(
      context,
      () async {
        await ref.read(businessRepositoryProvider).update(widget.business.id, {
          'name_en': _c.nullable('name_en'),
          'name_bn': _c.nullable('name_bn'),
          'business_type': _type,
          'logo_url': _logoUrl,
          'cover_url': _coverUrl,
          'phone': _phone('phone'),
          'email': _c.nullable('email'),
          'address': _c.nullable('address'),
          'map_url': _c.nullable('map_url'),
          'description_en': _c.nullable('description_en'),
          'description_bn': _c.nullable('description_bn'),
          'website_url': _c.nullable('website_url'),
          'facebook_url': _c.nullable('facebook_url'),
          'instagram_url': _c.nullable('instagram_url'),
          'tiktok_url': _c.nullable('tiktok_url'),
          'youtube_url': _c.nullable('youtube_url'),
          'whatsapp_number': _phone('whatsapp_number'),
          'currency': _currency,
          'default_language': _language,
          'timezone': _timezone,
        });
        ref.refreshBusiness();
      },
      onError: friendlyError,
      successMessage: 'Saved',
    );
    if (mounted) setState(() => _saving = false);
    if (ok) FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.business.id;
    return AppPage(
      title: 'Restaurant profile',
      subtitle: 'What customers see on your menu',
      bottomBar: StickyActionBar(
        child: AppButton(
          label: 'Save changes',
          expand: true,
          loading: _saving,
          onPressed: _save,
        ),
      ),
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormSection(
              title: 'Name and type',
              children: [
                BilingualFields(
                  label: 'Name',
                  englishController: _c['name_en'],
                  banglaController: _c['name_bn'],
                  requireOne: true,
                ),
                SelectField<String>(
                  label: 'Business type',
                  options: businessTypeOptions,
                  value: _type,
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ],
            ),
            FormSection(
              title: 'Logo and cover',
              subtitle:
                  'The cover is the wide picture at the top of your menu.',
              children: [
                ImagePickerField(
                  label: 'Logo',
                  imageUrl: _logoUrl,
                  businessId: businessId,
                  bucket: AppBucket.brand,
                  folder: 'logo',
                  circle: true,
                  maxDimension: 600,
                  helper: 'A square image works best.',
                  onChanged: (url) => setState(() => _logoUrl = url),
                ),
                ImagePickerField(
                  label: 'Cover image',
                  imageUrl: _coverUrl,
                  businessId: businessId,
                  bucket: AppBucket.brand,
                  folder: 'cover',
                  aspectRatio: 16 / 7,
                  helper: 'Wide photo of your food or place.',
                  onChanged: (url) => setState(() => _coverUrl = url),
                ),
              ],
            ),
            FormSection(
              title: 'Contact and location',
              children: [
                AppTextField(
                  label: 'Phone',
                  controller: _c['phone'],
                  keyboardType: TextInputType.phone,
                  optional: true,
                  validator: Validators.bdMobile(),
                ),
                AppTextField(
                  label: 'Email',
                  controller: _c['email'],
                  keyboardType: TextInputType.emailAddress,
                  optional: true,
                  validator: Validators.email(requiredField: false),
                ),
                AppTextField(
                  label: 'Address',
                  controller: _c['address'],
                  maxLines: 3,
                  minLines: 2,
                  optional: true,
                  maxLength: 400,
                ),
                AppTextField(
                  label: 'Google Maps link',
                  controller: _c['map_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  helper: 'Open your place in Google Maps, tap Share, copy the link.',
                  validator: Validators.url(),
                ),
              ],
            ),
            FormSection(
              title: 'About',
              children: [
                BilingualFields(
                  label: 'Short description',
                  englishController: _c['description_en'],
                  banglaController: _c['description_bn'],
                  optional: true,
                  maxLines: 4,
                  maxLength: 1500,
                ),
              ],
            ),
            FormSection(
              title: 'Online',
              children: [
                AppTextField(
                  label: 'Website',
                  controller: _c['website_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                AppTextField(
                  label: 'Facebook page',
                  controller: _c['facebook_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                AppTextField(
                  label: 'Instagram',
                  controller: _c['instagram_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                AppTextField(
                  label: 'TikTok',
                  controller: _c['tiktok_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                AppTextField(
                  label: 'YouTube',
                  controller: _c['youtube_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                AppTextField(
                  label: 'WhatsApp number',
                  controller: _c['whatsapp_number'],
                  keyboardType: TextInputType.phone,
                  optional: true,
                  helper: 'Customers can tap it to message you.',
                  validator: Validators.bdMobile(),
                ),
              ],
            ),
            FormSection(
              title: 'Language and currency',
              children: [
                SelectField<String>(
                  label: 'Default menu language',
                  options: languageOptions,
                  value: _language,
                  onChanged: (v) => setState(() => _language = v ?? _language),
                ),
                SelectField<String>(
                  label: 'Currency',
                  options: currencyOptions,
                  value: _currency,
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
                SelectField<String>(
                  label: 'Time zone',
                  options: timezoneOptions,
                  value: _timezone,
                  onChanged: (v) => setState(() => _timezone = v ?? _timezone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
