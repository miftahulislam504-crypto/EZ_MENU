import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_layout.dart';
import 'auth_repository.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signedIn = await ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      if (!signedIn) {
        final email = Uri.encodeQueryComponent(_email.text.trim());
        context.go('${AppRoutes.verify}?email=$email');
      }
      // Otherwise the router moves on as soon as the session arrives.
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Set up your digital menu in a few minutes.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Already have an account?',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Your name',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.required('your name'),
              ),
              const SizedBox(height: Sp.lg),
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email(),
              ),
              const SizedBox(height: Sp.lg),
              AppPasswordField(
                controller: _password,
                helper: 'At least 8 characters.',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: Sp.lg),
                Container(
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: context.palette.dangerSoft,
                    borderRadius: BorderRadius.circular(Rad.control),
                  ),
                  child: Text(
                    _error!,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.palette.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Sp.xl),
              AppButton(
                label: 'Create account',
                expand: true,
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: Sp.md),
              Text(
                'By creating an account you agree to the terms and privacy '
                'notice.',
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
