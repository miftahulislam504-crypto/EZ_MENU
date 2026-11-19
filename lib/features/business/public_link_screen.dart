import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/launch.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';
import 'business_repository.dart';
import 'widgets/slug_field.dart';

/// The address customers can open, plus publish and unpublish.
class PublicLinkScreen extends ConsumerWidget {
  const PublicLinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessesProvider);
    return businesses.when(
      skipLoadingOnReload: true,
      loading: () => const AppPage(
        title: 'Public menu link',
        scroll: false,
        body: LoadingView(),
      ),
      error: (error, _) => AppPage(
        title: 'Public menu link',
        scroll: false,
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(businessesProvider),
        ),
      ),
      data: (list) => list.isEmpty
          ? const AppPage(
              title: 'Public menu link',
              scroll: false,
              body: EmptyState(
                icon: Icons.link_rounded,
                title: 'No restaurant yet',
                message: 'Finish setup first.',
              ),
            )
          : _LinkBody(business: list.first),
    );
  }
}

class _LinkBody extends ConsumerStatefulWidget {
  const _LinkBody({required this.business});

  final Business business;

  @override
  ConsumerState<_LinkBody> createState() => _LinkBodyState();
}

class _LinkBodyState extends ConsumerState<_LinkBody> {
  late final TextEditingController _slug;
  SlugStatus _status = SlugStatus.available;
  bool _editing = false;
  bool _saving = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _slug = TextEditingController(text: widget.business.slug);
  }

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showToast(context, 'Link copied');
  }

  Future<void> _saveSlug() async {
    final slug = _slug.text.trim();
    if (_saving || slug == widget.business.slug) {
      setState(() => _editing = false);
      return;
    }
    if (_status != SlugStatus.available) {
      showToast(
        context,
        'Choose a link name that is available.',
        isError: true,
      );
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Change your menu link?',
      message:
          'Links and short links you shared before will stop working. QR '
          'codes keep working because they use their own code.',
      confirmLabel: 'Change link',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final ok = await runWithToast(
      context,
      () async {
        await ref.read(businessRepositoryProvider).update(widget.business.id, {
          'slug': slug,
        });
        ref.refreshBusiness();
      },
      onError: friendlyError,
      successMessage: 'Link changed',
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) _editing = false;
      });
    }
  }

  Future<void> _setPublished(bool value) async {
    setState(() => _publishing = true);
    await runWithToast(
      context,
      () async {
        await ref.read(businessRepositoryProvider).update(widget.business.id, {
          'menu_published': value,
        });
        ref.refreshBusiness();
      },
      onError: friendlyError,
      successMessage: value ? 'Published' : 'Unpublished',
    );
    if (mounted) setState(() => _publishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final link = PublicLinks.businessMenu(business.slug);
    final palette = context.palette;

    return AppPage(
      title: 'Public menu link',
      subtitle: 'Share this address on social media and messages',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Your menu link',
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Rad.control),
                  border: Border.all(color: palette.line),
                ),
                child: SelectableText(
                  link,
                  style: context.textStyles.titleSmall,
                ),
              ),
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  AppButton(
                    label: 'Copy link',
                    icon: Icons.copy_rounded,
                    kind: AppButtonKind.tonal,
                    onPressed: () => _copy(link),
                  ),
                  AppButton(
                    label: 'Share',
                    icon: Icons.ios_share_rounded,
                    kind: AppButtonKind.secondary,
                    onPressed: () => Share.share(
                      'See our menu: $link',
                      subject: business.name,
                    ),
                  ),
                  AppButton(
                    label: 'Open',
                    icon: Icons.open_in_new_rounded,
                    kind: AppButtonKind.secondary,
                    onPressed: () => openUrl(link),
                  ),
                ],
              ),
              if (!PublicLinks.isConfigured)
                Text(
                  'The web address of your menu site is not set, so this link '
                  'may be incomplete. Set PUBLIC_BASE_URL when building the '
                  'app.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: palette.warning,
                  ),
                ),
              if (branches.length > 1)
                Text(
                  'With several branches, customers choose a branch from this '
                  'link. Each branch also has its own link and QR code.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
            ],
          ),
          FormSection(
            title: 'Link name',
            children: [
              if (!_editing) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        business.slug,
                        style: context.textStyles.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ] else ...[
                SlugField(
                  controller: _slug,
                  label: 'Link name',
                  linkPrefix: '${PublicLinks.businessMenu('')}',
                  check: (slug) => ref
                      .read(businessRepositoryProvider)
                      .isSlugAvailable(slug, excludeBusinessId: business.id),
                  onStatusChanged: (status) => _status = status,
                ),
                Row(
                  children: [
                    AppButton(
                      label: 'Save link name',
                      loading: _saving,
                      onPressed: _saveSlug,
                    ),
                    const SizedBox(width: Sp.sm),
                    AppButton(
                      label: 'Cancel',
                      kind: AppButtonKind.text,
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _slug.text = business.slug;
                              _editing = false;
                            }),
                    ),
                  ],
                ),
              ],
            ],
          ),
          FormSection(
            title: 'Visibility',
            children: [
              SwitchRow(
                title: 'Menu is published',
                subtitle: business.menuPublished
                    ? 'Anyone with the link or a QR code can see your menu.'
                    : 'Customers see a message that the menu is not available. '
                          'You can still preview it.',
                value: business.menuPublished,
                onChanged: _publishing ? null : _setPublished,
              ),
            ],
          ),
          ListGroup(
            children: [
              ListRow(
                leading: const IconBadge(Icons.qr_code_2_rounded),
                title: 'QR codes',
                subtitle: 'Print codes for tables, the counter and your door',
                onTap: () => context.go(AppRoutes.qr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
