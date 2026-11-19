import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/bd_phone.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/controllers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_repository.dart';
import 'business_repository.dart';

/// Your own details, password and sign out.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _c = ControllerBag();
  bool _filled = false;
  bool _saving = false;
  bool _changingPassword = false;
  bool _showPasswordForm = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final phone = _c.nullable('phone');
    await runWithToast(
      context,
      () async {
        await ref
            .read(businessRepositoryProvider)
            .saveProfile(
              fullName: _c.nullable('name'),
              phone: phone == null ? null : (BdPhone.normalize(phone) ?? phone),
            );
        ref.invalidate(userProfileProvider);
      },
      onError: friendlyError,
      successMessage: 'Saved',
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _changePassword() async {
    if (_changingPassword ||
        !(_passwordForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _changingPassword = true);
    final ok = await runWithToast(
      context,
      () => ref
          .read(authRepositoryProvider)
          .changePassword(_c.text('new_password')),
      onError: friendlyError,
      successMessage: 'Password updated',
    );
    if (!mounted) return;
    setState(() {
      _changingPassword = false;
      if (ok) {
        _showPasswordForm = false;
        _c['new_password'].clear();
      }
    });
  }

  Future<void> _signOut() async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign in again.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentSessionProvider)?.user.email ?? '';
    final profile = ref.watch(userProfileProvider);
    final loaded = profile.valueOrNull;
    if (loaded != null && !_filled) {
      _filled = true;
      // Fill after this frame: changing a controller while building would
      // rebuild the fields that are being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.fill({'name': loaded.fullName, 'phone': loaded.phone});
      });
    }

    return AppPage(
      title: 'Account and security',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _form,
            child: FormSection(
              title: 'Your details',
              children: [
                AppTextField(
                  label: 'Email',
                  initialValue: email,
                  readOnly: true,
                  enabled: false,
                  helper: 'This is the email you sign in with.',
                ),
                AppTextField(
                  label: 'Your name',
                  controller: _c['name'],
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.maxLength(120, what: 'The name'),
                ),
                AppTextField(
                  label: 'Mobile number',
                  controller: _c['phone'],
                  keyboardType: TextInputType.phone,
                  optional: true,
                  validator: Validators.bdMobile(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Save details',
                    loading: _saving,
                    onPressed: _saveDetails,
                  ),
                ),
              ],
            ),
          ),
          FormSection(
            title: 'Password',
            children: [
              if (!_showPasswordForm)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Change password',
                    kind: AppButtonKind.secondary,
                    icon: Icons.lock_outline_rounded,
                    onPressed: () => setState(() => _showPasswordForm = true),
                  ),
                )
              else
                Form(
                  key: _passwordForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppPasswordField(
                        controller: _c['new_password'],
                        label: 'New password',
                        helper: 'At least 8 characters.',
                        validator: (value) =>
                            (value == null || value.length < 8)
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                      const SizedBox(height: Sp.md),
                      Row(
                        children: [
                          AppButton(
                            label: 'Update password',
                            loading: _changingPassword,
                            onPressed: _changePassword,
                          ),
                          const SizedBox(width: Sp.sm),
                          AppButton(
                            label: 'Cancel',
                            kind: AppButtonKind.text,
                            onPressed: () =>
                                setState(() => _showPasswordForm = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          FormSection(
            title: 'Your data',
            children: [
              Text(
                'To export or delete your account data, contact support with '
                'the email you sign in with.',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
          AppButton(
            label: 'Sign out',
            kind: AppButtonKind.danger,
            icon: Icons.logout_rounded,
            expand: true,
            onPressed: _signOut,
          ),
        ],
      ),
    );
  }
}
