import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Builds the public addresses that QR codes and share buttons point to.
class PublicLinks {
  const PublicLinks._();

  /// Address of the deployed web app without a trailing slash. Empty when it
  /// cannot be determined (mobile app without PUBLIC_BASE_URL).
  static String get baseUrl {
    var base = Env.publicBaseUrl.trim();
    if (base.isEmpty && kIsWeb) base = Uri.base.origin;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  static String businessMenu(String businessSlug) =>
      joinUrl(baseUrl, '/m/$businessSlug');

  static String branchMenu(String businessSlug, String branchSlug) =>
      joinUrl(baseUrl, '/m/$businessSlug/$branchSlug');

  static String qr(String token) => joinUrl(baseUrl, '/q/$token');

  @visibleForTesting
  static String joinUrl(String base, String path) => '$base$path';
}
