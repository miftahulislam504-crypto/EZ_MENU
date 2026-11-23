import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';
import 'public_menu_models.dart';

/// Which menu to load: by restaurant and branch address, or by a QR code.
/// [preview] is for the owner's own preview: the menu is shown even when it is
/// not published, and the visit is not counted as a scan.
class PublicMenuRequest {
  const PublicMenuRequest({
    this.businessSlug,
    this.branchSlug,
    this.qrToken,
    this.preview = false,
  });

  final String? businessSlug;
  final String? branchSlug;
  final String? qrToken;
  final bool preview;

  @override
  bool operator ==(Object other) =>
      other is PublicMenuRequest &&
      other.businessSlug == businessSlug &&
      other.branchSlug == branchSlug &&
      other.qrToken == qrToken &&
      other.preview == preview;

  @override
  int get hashCode => Object.hash(businessSlug, branchSlug, qrToken, preview);
}

/// Loads the customer menu in one request (`get_public_menu`).
class PublicMenuRepository {
  PublicMenuRepository(this._client);

  final SupabaseClient _client;

  Future<PublicMenuResult> load(PublicMenuRequest request) async {
    final response = await _client.rpc(
      'get_public_menu',
      params: {
        'p_business_slug': request.businessSlug,
        'p_branch_slug': request.branchSlug,
        'p_qr_token': request.qrToken,
        'p_preview': request.preview,
      },
    );
    return PublicMenuResult.fromJson(response);
  }
}

final publicMenuRepositoryProvider = Provider<PublicMenuRepository>(
  (ref) => PublicMenuRepository(ref.watch(supabaseClientProvider)),
);

/// The menu for a request. A visit through a QR code counts as a scan, so the
/// result is kept for as long as the page is open and is not loaded again by a
/// rebuild. Only an explicit retry or [ref.invalidate] loads it again.
final publicMenuProvider = FutureProvider.autoDispose.family<PublicMenuResult, PublicMenuRequest>((
  ref,
  request,
) {
  ref.keepAlive();
  return ref.watch(publicMenuRepositoryProvider).load(request);
});

/// The same menu for the owner's preview in the dashboard. It is not kept
/// alive: leaving the screen drops it, so every visit shows the latest dishes
/// and prices. Requests made with `preview: true` are never counted as scans.
final publicMenuPreviewProvider = FutureProvider.autoDispose.family<PublicMenuResult, PublicMenuRequest>((
  ref,
  request,
) {
  return ref.watch(publicMenuRepositoryProvider).load(request);
});
