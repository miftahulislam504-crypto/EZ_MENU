import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/bd_phone.dart';
import '../../../core/logic/slug.dart';
import '../../../core/session/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/supabase/storage_service.dart';
import '../../../core/utils/controllers.dart';
import '../../../core/utils/public_links.dart';
import '../../../core/utils/validators.dart';
import '../../business/business_options.dart';
import '../../business/business_repository.dart';
import '../../business/widgets/slug_field.dart';
import '../../../core/widgets/widgets.dart';
import '../onboarding_widgets.dart';

/// Step 1: create the restaurant, then add a logo, cover and colour.
class ProfileStep extends ConsumerStatefulWidget {
  const ProfileStep({super.key, required this.business, required this.onNext});

  /// Null until the restaurant is created.
  final Business? business;
  final VoidCallback onNext;

  @override
  ConsumerState<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<ProfileStep> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  String _type = 'restaurant';
  String _language = 'bn';
  SlugStatus _slugStatus = SlugStatus.idle;
  String _autoSlug = '';
  bool _saving = false;

  /// False while filling the basics, true once the restaurant exists and the
  /// person is choosing a logo and colour.
  bool _styling = false;
  String? _logoUrl;
  String? _coverUrl;
  Color _color = AppColors.leaf;

  Business? get _business => widget.business;

  @override
  void initState() {
    super.initState();
    final b = _business;
    _c.fill({
      'name_en': b?.nameEn,
      'name_bn': b?.nameBn,
      'phone': b?.phone,
      'slug': b?.slug,
    });
    if (b != null) {
      _type = b.businessType;
      _language = b.defaultLanguage;
      _logoUrl = b.logoUrl;
      _coverUrl = b.coverUrl;
      _color = hexToColor(b.brandColor);
      _slugStatus = SlugStatus.available;
    } else {
      _syncSlug();
      _c['name_en'].addListener(_syncSlug);
      _c['name_bn'].addListener(_syncSlug);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _syncSlug() {
    final current = _c['slug'].text.trim();
    if (current.isNotEmpty && current != _autoSlug) return;
    var next = slugify(_c.text('name_en'), maxLength: 40);
    if (next.length < 3) next = '';
    _autoSlug = next;
    if (_c['slug'].text != next) _c['slug'].text = next;
  }

  Future<void> _saveBasics() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    if (_business == null && _slugStatus != SlugStatus.available) {
      showToast(
        context,
        'Choose a menu link that is available.',
        isError: true,
      );
      return;
    }
    final phone = _c.nullable('phone');
    final values = <String, dynamic>{
      'name_en': _c.nullable('name_en'),
      'name_bn': _c.nullable('name_bn'),
      'business_type': _type,
      'default_language': _language,
      'phone': phone == null ? null : (BdPhone.normalize(phone) ?? phone),
    };
    setState(() => _saving = true);
    final repository = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      final existing = _business;
      if (existing == null) {
        await repository.create({
          ...values,
          'slug': _c.text('slug'),
          'onboarding_step': 1,
        });
      } else {
        await repository.update(existing.id, values);
      }
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _styling = true;
    });
  }

  Future<void> _saveStyle() async {
    final business = _business;
    if (business == null || _saving) return;
    setState(() => _saving = true);
    final ok = await runWithToast(context, () async {
      await ref.read(businessRepositoryProvider).update(business.id, {
        'logo_url': _logoUrl,
        'cover_url': _coverUrl,
        'brand_color': colorToHex(_color),
      });
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    if (_styling && _business != null) return _styleView(context, _business!);
    return _basicsView(context);
  }

  Widget _basicsView(BuildContext context) {
    final creating = _business == null;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeading(
            title: 'Tell us about your restaurant',
            subtitle:
                'This is what customers see at the top of your menu. You can '
                'change everything later.',
          ),
          FormSection(
            children: [
              BilingualFields(
                label: 'Restaurant name',
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
              AppTextField(
                label: 'Phone',
                controller: _c['phone'],
                keyboardType: TextInputType.phone,
                optional: true,
                validator: Validators.bdMobile(),
              ),
              SegmentedChoice<String>(
                label: 'Menu language customers see first',
                value: _language,
                onChanged: (v) => setState(() => _language = v),
                options: const [
                  ChoiceOption(value: 'bn', label: 'Bangla'),
                  ChoiceOption(value: 'en', label: 'English'),
                ],
              ),
            ],
          ),
          if (creating)
            FormSection(
              title: 'Your menu link',
              subtitle: 'Customers will open your menu at this address.',
              children: [
                SlugField(
                  controller: _c['slug'],
                  label: 'Link name',
                  linkPrefix: PublicLinks.businessMenu(''),
                  check: (slug) => ref
                      .read(businessRepositoryProvider)
                      .isSlugAvailable(slug),
                  onStatusChanged: (status) => _slugStatus = status,
                ),
              ],
            ),
          StepButtons(
            primaryLabel: creating ? 'Create restaurant' : 'Save and continue',
            loading: _saving,
            onPrimary: _saveBasics,
            onSkip: creating ? null : () => setState(() => _styling = true),
            skipLabel: 'Skip to logo and colour',
          ),
        ],
      ),
    );
  }

  Widget _styleView(BuildContext context, Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeading(
          title: 'Make it yours',
          subtitle:
              'Add your logo and pick a colour. Both are optional and can be '
              'changed any time.',
        ),
        FormSection(
          children: [
            ImagePickerField(
              label: 'Logo',
              imageUrl: _logoUrl,
              businessId: business.id,
              bucket: AppBucket.brand,
              folder: 'logo',
              circle: true,
              maxDimension: 600,
              onChanged: (url) => setState(() => _logoUrl = url),
            ),
            ImagePickerField(
              label: 'Cover image',
              imageUrl: _coverUrl,
              businessId: business.id,
              bucket: AppBucket.brand,
              folder: 'cover',
              aspectRatio: 16 / 7,
              onChanged: (url) => setState(() => _coverUrl = url),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Brand colour'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final swatch in brandSwatches)
                      Semantics(
                        button: true,
                        selected: swatch == _color,
                        label: 'Brand colour ${colorToHex(swatch)}',
                        child: GestureDetector(
                          onTap: () => setState(() => _color = swatch),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: swatch,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: swatch == _color
                                    ? context.colors.onSurface
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: swatch == _color
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: onColor(swatch),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StepButtons(
          primaryLabel: 'Continue',
          loading: _saving,
          onPrimary: _saveStyle,
          onBack: () => setState(() => _styling = false),
        ),
      ],
    );
  }
}
