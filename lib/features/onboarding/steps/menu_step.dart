import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/money.dart';
import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/controllers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_repository.dart';
import '../onboarding_widgets.dart';

enum _MenuChoice { own, sample }

/// Step 4: a first category and dish, or a sample menu. Can be skipped.
class MenuStep extends ConsumerStatefulWidget {
  const MenuStep({
    super.key,
    required this.business,
    required this.onNext,
    required this.onBack,
  });

  final Business business;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<MenuStep> createState() => _MenuStepState();
}

class _MenuStepState extends ConsumerState<MenuStep> {
  final _form = GlobalKey<FormState>();
  final _c = ControllerBag();
  _MenuChoice _choice = _MenuChoice.own;
  bool _saving = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _insertOwn() async {
    final client = ref.read(supabaseClientProvider);
    final id = widget.business.id;
    final category = await client
        .from('menu_categories')
        .insert({
          'business_id': id,
          'name_en': _c.nullable('category_en'),
          'name_bn': _c.nullable('category_bn'),
          'sort_order': 1,
        })
        .select('id')
        .single();
    await client.from('menu_items').insert({
      'business_id': id,
      'category_id': category['id'],
      'name_en': _c.nullable('item_en'),
      'name_bn': _c.nullable('item_bn'),
      'price': parseAmount(_c.text('price')),
      'sort_order': 1,
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_choice == _MenuChoice.own &&
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    final business = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      if (_choice == _MenuChoice.sample) {
        await client.rpc(
          'seed_sample_menu',
          params: {'p_business_id': widget.business.id},
        );
      } else {
        await _insertOwn();
      }
      await business.advanceOnboarding(widget.business.id, 4);
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    final business = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      await business.advanceOnboarding(widget.business.id, 4);
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeading(
            title: 'Add your first dish',
            subtitle:
                'Start with one category and one dish so your menu is not '
                'empty. The full menu editor comes next.',
          ),
          SegmentedChoice<_MenuChoice>(
            value: _choice,
            onChanged: (v) => setState(() => _choice = v),
            options: const [
              ChoiceOption(value: _MenuChoice.own, label: 'My own dish'),
              ChoiceOption(value: _MenuChoice.sample, label: 'Sample menu'),
            ],
          ),
          const SizedBox(height: Sp.lg),
          if (_choice == _MenuChoice.sample)
            Container(
              padding: const EdgeInsets.all(Sp.lg),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(Rad.panel),
                border: Border.all(color: context.palette.line),
              ),
              child: Text(
                'We will add five example categories (starters, rice and '
                'curry, burgers, drinks and desserts) with a few dishes, '
                'including sizes and add-ons. Edit or delete them any time.',
                style: context.textStyles.bodyMedium,
              ),
            )
          else ...[
            FormSection(
              title: 'Category',
              children: [
                BilingualFields(
                  label: 'Category name',
                  englishController: _c['category_en'],
                  banglaController: _c['category_bn'],
                  requireOne: true,
                  hintEnglish: 'Burgers',
                  hintBangla: 'বার্গার',
                ),
              ],
            ),
            FormSection(
              title: 'Dish',
              children: [
                BilingualFields(
                  label: 'Dish name',
                  englishController: _c['item_en'],
                  banglaController: _c['item_bn'],
                  requireOne: true,
                  hintEnglish: 'Beef burger',
                  hintBangla: 'বিফ বার্গার',
                ),
                AppTextField(
                  label: 'Price',
                  controller: _c['price'],
                  prefixText: '${widget.business.currency} ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: Validators.price(),
                ),
              ],
            ),
          ],
          StepButtons(
            primaryLabel: _choice == _MenuChoice.sample
                ? 'Add sample menu'
                : 'Save and continue',
            loading: _saving,
            onPrimary: _save,
            onBack: widget.onBack,
            onSkip: _skip,
          ),
        ],
      ),
    );
  }
}
