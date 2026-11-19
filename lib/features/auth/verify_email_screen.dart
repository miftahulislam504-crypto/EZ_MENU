import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'auth_layout.dart';
import 'auth_repository.dart';

/// Enter the 6 digit code emailed after sign up.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const int _cooldownSeconds = 60;

  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  bool _busy = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _remaining = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining = _remaining - 1);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_busy) return;
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6 digit code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifySignupCode(email: widget.email, code: code);
      // The router continues to setup once the session arrives.
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _remaining > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendSignupCode(widget.email);
      if (!mounted) return;
      showToast(context, 'Code sent');
      _startCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = widget.email.isNotEmpty;
    return AuthScaffold(
      title: 'Check your email',
      subtitle: hasEmail
          ? 'We sent a 6 digit code to ${widget.email}. Enter it below to '
                'verify your account.'
          : 'Enter the 6 digit code we emailed you.',
      onBack: () => context.go(AppRoutes.login),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Verification code',
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofocus: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              _error!,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.palette.danger,
              ),
            ),
          ],
          const SizedBox(height: Sp.lg),
          AppButton(
            label: 'Verify and continue',
            expand: true,
            loading: _busy,
            onPressed: _verify,
          ),
          const SizedBox(height: Sp.md),
          Center(
            child: TextButton(
              onPressed: (_remaining > 0 || _resending) ? null : _resend,
              child: Text(
                _remaining > 0
                    ? 'Send a new code in ${_remaining}s'
                    : 'Send a new code',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
