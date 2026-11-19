import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/supabase/error_text.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_layout.dart';
import 'auth_repository.dart';

/// Two steps on one screen: ask for a code, then enter it with a new password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy || !(_emailForm.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestRecoveryCode(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !(_resetForm.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Take what is needed before the first await: the recovery code signs the
    // person in and the router may rebuild this screen.
    final repository = ref.read(authRepositoryProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await repository.resetPassword(
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      router.go(AppRoutes.home);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _codeSent ? 'Set a new password' : 'Reset your password',
      subtitle: _codeSent
          ? 'Enter the 6 digit code we emailed to ${_email.text.trim()} and '
                'choose a new password.'
          : 'Enter your email and we will send you a code.',
      onBack: () => context.go(AppRoutes.login),
      child: _codeSent ? _resetStep(context) : _emailStep(context),
    );
  }

  Widget _errorNote(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Sp.md),
      child: Text(
        _error!,
        style: context.textStyles.bodySmall?.copyWith(
          color: context.palette.danger,
        ),
      ),
    );
  }

  Widget _emailStep(BuildContext context) {
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(),
            validator: Validators.email(),
          ),
          _errorNote(context),
          const SizedBox(height: Sp.xl),
          AppButton(
            label: 'Send code',
            expand: true,
            loading: _busy,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _resetStep(BuildContext context) {
    return Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Verification code',
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) => (value == null || value.trim().length < 6)
                ? 'Enter the 6 digit code from the email.'
                : null,
          ),
          const SizedBox(height: Sp.md),
          AppPasswordField(
            controller: _password,
            label: 'New password',
            helper: 'At least 8 characters.',
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _reset(),
            validator: (value) => (value == null || value.length < 8)
                ? 'Use at least 8 characters.'
                : null,
          ),
          _errorNote(context),
          const SizedBox(height: Sp.xl),
          AppButton(
            label: 'Update password',
            expand: true,
            loading: _busy,
            onPressed: _reset,
          ),
          const SizedBox(height: Sp.md),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _error = null;
                    }),
              child: const Text('Use a different email'),
            ),
          ),
        ],
      ),
    );
  }
}
