import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/bd_phone.dart';
import '../../../core/logic/slug.dart';
import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/utils/controllers.dart';
import '../../../core/utils/public_links.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../branches/branch_repository.dart';
import '../../business/business_repository.dart';
import '../../business/widgets/slug_field.dart';
import '../onboarding_widgets.dart';

/// Step 2: the first branch (location). Every restaurant has at least one.
class BranchStep extends ConsumerStatefulWidget {
  const BranchStep({
    super.key,
    required this.business,
    required this.existing,
    required this.onNext,
    required this.onBack,
  });

  final Business business;

  /// The branch created earlier, when the person comes back to this step.
  final Branch? existing;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<BranchStep> createState() => _BranchStepState();
}

class _BranchStepState extends ConsumerState<BranchStep> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  SlugStatus _slugStatus = SlugStatus.idle;
  String _autoSlug = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _c.fill({
      'name_en': b?.nameEn ?? 'Main branch',
      'name_bn': b?.nameBn,
      'address': b?.address,
      'area': b?.area,
      'phone': b?.phone,
      'slug': b?.slug,
    });
    if (b == null) {
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

  void _syncSlug() {
    final current = _c['slug'].text.trim();
    if (current.isNotEmpty && current != _autoSlug) return;
    var next = slugify(_c.text('name_en'), maxLength: 40);
    if (next.length < 2) next = '';
    _autoSlug = next;
    if (_c['slug'].text != next) _c['slug'].text = next;
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
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
    };
    setState(() => _saving = true);
    final branches = ref.read(branchRepositoryProvider);
    final business = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      final existing = widget.existing;
      if (existing == null) {
        await branches.create(widget.business.id, {...values, 'sort_order': 0});
      } else {
        await branches.update(existing.id, values);
      }
      await business.advanceOnboarding(widget.business.id, 2);
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeading(
            title: 'Add your first branch',
            subtitle:
                'A branch is one place customers can eat or order from. If you '
                'have only one, keep it simple. You can add more later.',
          ),
          FormSection(
            children: [
              BilingualFields(
                label: 'Branch name',
                englishController: _c['name_en'],
                banglaController: _c['name_bn'],
                requireOne: true,
              ),
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
                label: 'Branch phone',
                controller: _c['phone'],
                keyboardType: TextInputType.phone,
                optional: true,
                validator: Validators.bdMobile(),
              ),
              SlugField(
                controller: _c['slug'],
                label: 'Link name',
                minLength: 2,
                linkPrefix: PublicLinks.businessMenu('${business.slug}/'),
                check: (slug) => ref
                    .read(branchRepositoryProvider)
                    .isSlugAvailable(
                      business.id,
                      slug,
                      excludeBranchId: widget.existing?.id,
                    ),
                onStatusChanged: (status) => _slugStatus = status,
              ),
            ],
          ),
          StepButtons(
            primaryLabel: 'Save and continue',
            loading: _saving,
            onPrimary: _save,
            onBack: widget.onBack,
          ),
        ],
      ),
    );
  }
}
