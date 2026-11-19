import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';

/// Sign in, sign up and password recovery against Supabase Auth.
///
/// The email codes (verify and recovery) need `{{ .Token }}` in the Supabase
/// email templates; see the README.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Returns true when the person is signed in straight away (email
  /// confirmation is off), false when a code was emailed and must be entered.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    return response.session != null;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await _auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  }

  Future<void> resendSignupCode(String email) async {
    await _auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> requestRecoveryCode(String email) async {
    await _auth.resetPasswordForEmail(email.trim());
  }

  /// Verifies the emailed code and saves the new password in one go. The code
  /// signs the person in, so nothing between the two calls may depend on the
  /// screen still being open.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> changePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
