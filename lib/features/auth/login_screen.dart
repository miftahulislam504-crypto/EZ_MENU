import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_layout.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _needsVerification = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _needsVerification = false;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      // The router takes over once the session arrives.
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().toLowerCase();
      setState(() {
        _error = friendlyError(error);
        _needsVerification =
            text.contains('email_not_confirmed') ||
            text.contains('email not confirmed');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goVerify() {
    final email = Uri.encodeQueryComponent(_email.text.trim());
    context.go('${AppRoutes.verify}?email=$email');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to manage your menu.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'New to EZ Menu?',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.signup),
            child: const Text('Create an account'),
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: Validators.required('your password'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    final email = Uri.encodeQueryComponent(_email.text.trim());
                    context.go('${AppRoutes.forgotPassword}?email=$email');
                  },
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Sp.sm),
                _InlineError(message: _error!),
                if (_needsVerification)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _goVerify,
                      child: const Text('Enter the verification code'),
                    ),
                  ),
              ],
              const SizedBox(height: Sp.lg),
              AppButton(
                label: 'Sign in',
                expand: true,
                loading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red note under a form, used by all auth screens.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: context.palette.dangerSoft,
        borderRadius: BorderRadius.circular(Rad.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: context.palette.danger,
          ),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              message,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.palette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
