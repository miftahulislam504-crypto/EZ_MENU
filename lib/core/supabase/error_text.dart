import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by the app itself when the message is already written for people.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns any error into one sentence a restaurant owner can act on.
String friendlyError(Object? error) {
  if (error == null) return 'Something went wrong. Try again.';
  if (error is AppException) return error.message;

  if (error is AuthException) {
    return _authMessage(error);
  }
  if (error is PostgrestException) {
    return _databaseMessage(error);
  }
  if (error is StorageException) {
    if (error.statusCode == '413')
      return 'That image is too large. Use one under 5 MB.';
    if (error.statusCode == '403' || error.statusCode == '401') {
      return 'You do not have permission to upload here.';
    }
    return 'The image could not be uploaded. Check your connection and try again.';
  }
  if (error is TimeoutException) {
    return 'The request took too long. Check your connection and try again.';
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest error') ||
      text.contains('Network is unreachable')) {
    return 'No internet connection. Check it and try again.';
  }
  return 'Something went wrong. Try again.';
}

String _authMessage(AuthException error) {
  final message = error.message.toLowerCase();
  final code = (error.code ?? '').toLowerCase();

  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return 'The email or password is incorrect.';
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return 'Verify your email first. Enter the code we sent you.';
  }
  if (code == 'user_already_exists' || message.contains('already registered')) {
    return 'An account with this email already exists. Sign in instead.';
  }
  if (code == 'otp_expired' ||
      message.contains('expired') ||
      message.contains('token has expired or is invalid')) {
    return 'That code is wrong or has expired. Request a new one.';
  }
  if (code == 'weak_password' || message.contains('password should be')) {
    return 'Choose a stronger password with at least 8 characters.';
  }
  if (code.contains('rate_limit') ||
      error.statusCode == '429' ||
      message.contains('rate limit')) {
    return 'Too many attempts. Wait a minute and try again.';
  }
  if (message.contains('same password')) {
    return 'Choose a password you have not used before.';
  }
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('fetch')) {
    return 'No internet connection. Check it and try again.';
  }
  return error.message.isEmpty ? 'Sign in failed. Try again.' : error.message;
}

String _databaseMessage(PostgrestException error) {
  switch (error.code) {
    case '23505':
      return 'That name or link is already in use. Choose a different one.';
    case '23503':
      return 'This is still linked to other records, so it cannot be removed.';
    case '23514':
      return 'Some values are not allowed. Check the form and try again.';
    case '23502':
      return 'A required field is missing.';
    case '42501':
      return 'You do not have permission to do that.';
    case 'PGRST301':
    case 'PGRST303':
      return 'Your session expired. Sign in again.';
    case 'P0001':
      // Raised on purpose by our own functions with a readable message.
      return error.message;
  }
  final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
  if (text.contains('row-level security') ||
      text.contains('permission denied')) {
    return 'You do not have permission to do that.';
  }
  if (text.contains('jwt')) return 'Your session expired. Sign in again.';
  if (text.contains('failed host lookup') || text.contains('socketexception')) {
    return 'No internet connection. Check it and try again.';
  }
  return 'Something went wrong while saving. Try again.';
}
