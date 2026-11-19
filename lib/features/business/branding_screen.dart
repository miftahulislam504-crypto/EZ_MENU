import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/theme/menu_palette.dart';
import '../../core/utils/controllers.dart';
import '../../core/widgets/widgets.dart';
import 'business_options.dart';
import 'business_repository.dart';

/// Colour, theme, welcome message and policies of the customer menu.
class BrandingScreen extends ConsumerWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessesProvider);
    return business.when(
      skipLoadingOnReload: true,
      loading: () => const AppPage(
        title: 'Menu look and policies',
        scroll: false,
        body: LoadingView(),
      ),
      error: (error, _) => AppPage(
        title: 'Menu look and policies',
        scroll: false,
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(businessesProvider),
        ),
      ),
      data: (list) => list.isEmpty
          ? const AppPage(
              title: 'Menu look and policies',
              scroll: false,
              body: EmptyState(
                icon: Icons.palette_outlined,
                title: 'No restaurant yet',
                message: 'Finish setup first.',
              ),
            )
          : _BrandingForm(business: list.first),
    );
  }
}

class _BrandingForm extends ConsumerStatefulWidget {
  const _BrandingForm({required this.business});

  final Business business;

  @override
  ConsumerState<_BrandingForm> createState() => _BrandingFormState();
}

class _BrandingFormState extends ConsumerState<_BrandingForm> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  late Color _color;
  late String _theme;
  late String _layout;
  late String _soldOut;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _c.fill({
      'hex': b.brandColor,
      'welcome_en': b.welcomeMessageEn,
      'welcome_bn': b.welcomeMessageBn,
      'terms_en': b.termsEn,
      'terms_bn': b.termsBn,
      'refund_en': b.refundPolicyEn,
      'refund_bn': b.refundPolicyBn,
      'allergen_en': b.allergenNoticeEn,
      'allergen_bn': b.allergenNoticeBn,
    });
    _color = hexToColor(b.brandColor);
    _theme = b.menuTheme;
    _layout = b.menuLayout;
    _soldOut = b.soldOutDisplay;
    _c['hex'].addListener(_hexChanged);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _hexChanged() {
    final text = _c['hex'].text.trim();
    final normalized = text.startsWith('#') ? text : '#$text';
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      final next = hexToColor(normalized);
      if (next != _color) setState(() => _color = next);
    }
  }

  void _pick(Color color) {
    setState(() => _color = color);
    final hex = colorToHex(color);
    if (_c['hex'].text.toUpperCase() != hex) _c['hex'].text = hex;
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await runWithToast(
      context,
      () async {
        await ref.read(businessRepositoryProvider).update(widget.business.id, {
          'brand_color': colorToHex(_color),
          'menu_theme': _theme,
          'menu_layout': _layout,
          'sold_out_display': _soldOut,
          'welcome_message_en': _c.nullable('welcome_en'),
          'welcome_message_bn': _c.nullable('welcome_bn'),
          'terms_en': _c.nullable('terms_en'),
          'terms_bn': _c.nullable('terms_bn'),
          'refund_policy_en': _c.nullable('refund_en'),
          'refund_policy_bn': _c.nullable('refund_bn'),
          'allergen_notice_en': _c.nullable('allergen_en'),
          'allergen_notice_bn': _c.nullable('allergen_bn'),
        });
        ref.refreshBusiness();
      },
      onError: friendlyError,
      successMessage: 'Saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    return AppPage(
      title: 'Menu look and policies',
      subtitle: 'Colour, theme, welcome message and notices',
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
            _HeaderPreview(
              business: b,
              color: _color,
              theme: _theme,
              layout: _layout,
            ),
            FormSection(
              title: 'Brand colour',
              subtitle: 'Used for buttons, highlights and category chips.',
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final swatch in brandSwatches)
                      _Swatch(
                        color: swatch,
                        selected: swatch == _color,
                        onTap: () => _pick(swatch),
                      ),
                  ],
                ),
                AppTextField(
                  label: 'Colour code',
                  controller: _c['hex'],
                  helper: 'A six digit code, like #166A4C.',
                  prefixIcon: Icons.palette_outlined,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    final normalized = text.startsWith('#') ? text : '#$text';
                    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)
                        ? null
                        : 'Enter a six digit colour code, like #166A4C.';
                  },
                ),
              ],
            ),
            FormSection(
              title: 'Theme and layout',
              children: [
                SegmentedChoice<String>(
                  label: 'Menu theme',
                  value: _theme,
                  onChanged: (v) => setState(() => _theme = v),
                  options: const [
                    ChoiceOption(value: 'light', label: 'Light'),
                    ChoiceOption(value: 'warm', label: 'Warm'),
                    ChoiceOption(value: 'dark', label: 'Dark'),
                  ],
                ),
                SegmentedChoice<String>(
                  label: 'Item layout',
                  value: _layout,
                  onChanged: (v) => setState(() => _layout = v),
                  options: const [
                    ChoiceOption(
                      value: 'list',
                      label: 'List',
                      icon: Icons.view_list_rounded,
                    ),
                    ChoiceOption(
                      value: 'grid',
                      label: 'Grid',
                      icon: Icons.grid_view_rounded,
                    ),
                  ],
                ),
                SegmentedChoice<String>(
                  label: 'Sold out items',
                  value: _soldOut,
                  onChanged: (v) => setState(() => _soldOut = v),
                  options: const [
                    ChoiceOption(value: 'show', label: 'Show as sold out'),
                    ChoiceOption(value: 'hide', label: 'Hide'),
                  ],
                ),
                Text(
                  'Each branch can override the sold out setting in its own '
                  'settings.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ],
            ),
            FormSection(
              title: 'Welcome message',
              subtitle: 'A short greeting at the top of the menu.',
              children: [
                BilingualFields(
                  label: 'Welcome message',
                  englishController: _c['welcome_en'],
                  banglaController: _c['welcome_bn'],
                  optional: true,
                  maxLines: 3,
                  maxLength: 400,
                ),
              ],
            ),
            FormSection(
              title: 'Notices and policies',
              subtitle: 'Shown in the information panel of your menu.',
              children: [
                BilingualFields(
                  label: 'Allergen notice',
                  englishController: _c['allergen_en'],
                  banglaController: _c['allergen_bn'],
                  optional: true,
                  maxLines: 3,
                  maxLength: 1500,
                  hintEnglish: 'Tell us about allergies before you order.',
                ),
                BilingualFields(
                  label: 'Refund and cancellation policy',
                  englishController: _c['refund_en'],
                  banglaController: _c['refund_bn'],
                  optional: true,
                  maxLines: 4,
                  maxLength: 6000,
                ),
                BilingualFields(
                  label: 'Terms',
                  englishController: _c['terms_en'],
                  banglaController: _c['terms_bn'],
                  optional: true,
                  maxLines: 4,
                  maxLength: 6000,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Brand colour ${colorToHex(color)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.colors.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: onColor(color), size: 20)
              : null,
        ),
      ),
    );
  }
}

/// A small picture of how the top of the customer menu will look.
class _HeaderPreview extends StatelessWidget {
  const _HeaderPreview({
    required this.business,
    required this.color,
    required this.theme,
    required this.layout,
  });

  final Business business;
  final Color color;
  final String theme;
  final String layout;

  @override
  Widget build(BuildContext context) {
    final palette = MenuPalette.of(theme);
    final accent = palette.accentFor(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Preview'),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.paper,
              borderRadius: BorderRadius.circular(Rad.panel),
              border: Border.all(color: context.palette.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: NetworkImageBox(
                    url: business.coverUrl,
                    radius: 0,
                    placeholderIcon: Icons.image_outlined,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Sp.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NetworkImageBox(
                            url: business.logoUrl,
                            width: 44,
                            height: 44,
                            radius: 22,
                            placeholderIcon: Icons.storefront_outlined,
                          ),
                          const SizedBox(width: Sp.md),
                          Expanded(
                            child: Text(
                              business.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.titleMedium?.copyWith(
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                      Row(
                        children: [
                          _PreviewChip(
                            label: 'Starters',
                            fill: color,
                            text: onColor(color),
                          ),
                          const SizedBox(width: Sp.sm),
                          _PreviewChip(
                            label: 'Main course',
                            fill: palette.surface,
                            text: palette.ink,
                          ),
                          const SizedBox(width: Sp.sm),
                          _PreviewChip(
                            label: 'Drinks',
                            fill: palette.surface,
                            text: palette.ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                      Row(
                        children: [
                          Text(
                            'Chicken biryani',
                            style: context.textStyles.titleSmall?.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(height: 1, color: palette.line),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '320',
                            style: context.textStyles.titleSmall?.copyWith(
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.fill,
    required this.text,
  });

  final String label;
  final Color fill;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textStyles.labelMedium?.copyWith(color: text),
      ),
    );
  }
}
