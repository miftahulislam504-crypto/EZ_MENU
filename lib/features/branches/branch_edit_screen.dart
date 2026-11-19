import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/logic/bd_phone.dart';
import '../../core/logic/slug.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/nav.dart';
import '../../core/utils/public_links.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../business/widgets/slug_field.dart';
import 'branch_repository.dart';

/// Add a branch, or edit one when [branchId] is set.
class BranchEditScreen extends ConsumerWidget {
  const BranchEditScreen({super.key, this.branchId});

  final String? branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final business = ref.watch(currentBusinessProvider).valueOrNull;
    final title = branchId == null ? 'Add branch' : 'Edit branch';

    if (business == null || (branches.isLoading && !branches.hasValue)) {
      return AppPage(title: title, scroll: false, body: const LoadingView());
    }
    if (branches.hasError && !branches.hasValue) {
      return AppPage(
        title: title,
        scroll: false,
        body: ErrorState(
          message: friendlyError(branches.error),
          onRetry: () => ref.invalidate(branchesProvider),
        ),
      );
    }
    final all = branches.valueOrNull ?? const <Branch>[];
    Branch? existing;
    if (branchId != null) {
      for (final b in all) {
        if (b.id == branchId) existing = b;
      }
      if (existing == null) {
        return AppPage(
          title: title,
          scroll: false,
          body: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Branch not found',
            message: 'It may have been deleted.',
            actionLabel: 'Back to branches',
            onAction: () => context.go(AppRoutes.branches),
          ),
        );
      }
    }
    return _BranchForm(
      key: ValueKey(branchId ?? 'new'),
      business: business,
      branch: existing,
      branchCount: all.length,
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({
    super.key,
    required this.business,
    required this.branch,
    required this.branchCount,
  });

  final Business business;
  final Branch? branch;
  final int branchCount;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  bool _active = true;
  String _soldOut = 'inherit';
  SlugStatus _slugStatus = SlugStatus.idle;
  String _autoSlug = '';
  bool _saving = false;

  bool get _isNew => widget.branch == null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _c.fill({
      'name_en': b?.nameEn,
      'name_bn': b?.nameBn,
      'slug': b?.slug,
      'address': b?.address,
      'area': b?.area,
      'phone': b?.phone,
      'email': b?.email,
      'map_url': b?.mapUrl,
      'latitude': b?.latitude?.toString(),
      'longitude': b?.longitude?.toString(),
    });
    _active = b?.isActive ?? true;
    _soldOut = b?.soldOutDisplay ?? 'inherit';
    if (_isNew) {
      if (widget.branchCount == 0) _c['name_en'].text = 'Main branch';
      _syncSlug();
      _c['name_en'].addListener(_syncSlug);
    } else {
      _slugStatus = SlugStatus.available;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// While the person has not edited the link name, it follows the branch name.
  void _syncSlug() {
    final current = _c['slug'].text.trim();
    if (current.isNotEmpty && current != _autoSlug) return;
    var next = slugify(_c.text('name_en'), maxLength: 40);
    if (next.length < 2) next = '';
    _autoSlug = next;
    if (_c['slug'].text != next) _c['slug'].text = next;
  }

  double? _number(String key) => double.tryParse(_c.text(key));

  Future<void> _save() async {
    if (_saving) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_slugStatus != SlugStatus.available) {
      showToast(
        context,
        'Choose a link name that is available.',
        isError: true,
      );
      return;
    }
    final phone = _c.nullable('phone');
    final values = <String, dynamic>{
      'name_en': _c.nullable('name_en'),
      'name_bn': _c.nullable('name_bn'),
      'slug': _c.text('slug'),
      'address': _c.nullable('address'),
      'area': _c.nullable('area'),
      'phone': phone == null ? null : (BdPhone.normalize(phone) ?? phone),
      'email': _c.nullable('email'),
      'map_url': _c.nullable('map_url'),
      'latitude': _number('latitude'),
      'longitude': _number('longitude'),
      'is_active': _active,
      'sold_out_display': _soldOut == 'inherit' ? null : _soldOut,
    };
    setState(() => _saving = true);
    final repository = ref.read(branchRepositoryProvider);
    final ok = await runWithToast(
      context,
      () async {
        if (_isNew) {
          await repository.create(widget.business.id, {
            ...values,
            'sort_order': widget.branchCount,
          });
        } else {
          await repository.update(widget.branch!.id, values);
        }
        ref.refreshBranches();
      },
      onError: friendlyError,
      successMessage: _isNew ? 'Branch added' : 'Saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && _isNew) popOrGo(context, AppRoutes.branches);
  }

  Future<void> _delete() async {
    final branch = widget.branch;
    if (branch == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${branch.name}?',
      message:
          'Its tables, QR codes and branch prices are deleted too. Printed QR '
          'codes for this branch will stop working. This cannot be undone.',
      confirmLabel: 'Delete branch',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithToast(
      context,
      () async {
        await ref.read(branchRepositoryProvider).delete(branch.id);
        if (ref.read(selectedBranchIdProvider) == branch.id) {
          await ref.read(selectedBranchIdProvider.notifier).select(null);
        }
        ref.refreshBranches();
      },
      onError: friendlyError,
      successMessage: 'Branch deleted',
    );
    if (ok && mounted) context.go(AppRoutes.branches);
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final branch = widget.branch;
    final canDelete = !_isNew && widget.branchCount > 1;
    return AppPage(
      title: _isNew ? 'Add branch' : 'Edit branch',
      subtitle: business.name,
      bottomBar: StickyActionBar(
        child: AppButton(
          label: _isNew ? 'Add branch' : 'Save changes',
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
              title: 'Branch name',
              children: [
                BilingualFields(
                  label: 'Name',
                  englishController: _c['name_en'],
                  banglaController: _c['name_bn'],
                  requireOne: true,
                  hintEnglish: 'Gulshan branch',
                ),
                SlugField(
                  controller: _c['slug'],
                  label: 'Link name',
                  minLength: 2,
                  linkPrefix: PublicLinks.businessMenu('${business.slug}/'),
                  helper: 'Part of this branch\'s menu link.',
                  check: (slug) => ref
                      .read(branchRepositoryProvider)
                      .isSlugAvailable(
                        business.id,
                        slug,
                        excludeBranchId: branch?.id,
                      ),
                  onStatusChanged: (status) => _slugStatus = status,
                ),
              ],
            ),
            FormSection(
              title: 'Address and contact',
              children: [
                AppTextField(
                  label: 'Area',
                  controller: _c['area'],
                  optional: true,
                  hint: 'Gulshan 2, Dhaka',
                ),
                AppTextField(
                  label: 'Address',
                  controller: _c['address'],
                  optional: true,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 400,
                ),
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
                  label: 'Google Maps link',
                  controller: _c['map_url'],
                  keyboardType: TextInputType.url,
                  optional: true,
                  validator: Validators.url(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Latitude',
                        controller: _c['latitude'],
                        optional: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final n = double.tryParse(text);
                          return (n == null || n < -90 || n > 90)
                              ? 'Between -90 and 90.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Longitude',
                        controller: _c['longitude'],
                        optional: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final n = double.tryParse(text);
                          return (n == null || n < -180 || n > 180)
                              ? 'Between -180 and 180.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            FormSection(
              title: 'Settings',
              children: [
                SwitchRow(
                  title: 'Branch is active',
                  subtitle: _active
                      ? 'Customers can open this branch menu.'
                      : 'Hidden from customers. Its QR codes stop working.',
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                SegmentedChoice<String>(
                  label: 'Sold out items in this branch',
                  value: _soldOut,
                  onChanged: (v) => setState(() => _soldOut = v),
                  options: const [
                    ChoiceOption(value: 'inherit', label: 'Same as menu'),
                    ChoiceOption(value: 'show', label: 'Show'),
                    ChoiceOption(value: 'hide', label: 'Hide'),
                  ],
                ),
              ],
            ),
            if (!_isNew)
              ListGroup(
                children: [
                  ListRow(
                    leading: const IconBadge(Icons.schedule_rounded),
                    title: 'Opening hours',
                    subtitle:
                        'Weekly hours, special days and temporary closure',
                    onTap: () =>
                        context.push(AppRoutes.branchHours(branch!.id)),
                  ),
                ],
              ),
            if (!_isNew)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xl),
                child: AppButton(
                  label: canDelete
                      ? 'Delete branch'
                      : 'The last branch cannot be deleted',
                  kind: AppButtonKind.danger,
                  icon: Icons.delete_outline_rounded,
                  expand: true,
                  onPressed: canDelete ? _delete : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
