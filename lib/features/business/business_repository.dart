import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/models.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/json_utils.dart';

/// The signed-in person's own details (profiles table).
class UserProfile {
  const UserProfile({this.fullName, this.phone});

  final String? fullName;
  final String? phone;
}

class BusinessRepository {
  BusinessRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<Business> create(Map<String, dynamic> values) async {
    final row = await _client
        .from('businesses')
        .insert({...values, 'owner_id': _userId})
        .select()
        .single();
    return Business.fromJson(row);
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    await _client.from('businesses').update(values).eq('id', id);
  }

  Future<bool> isSlugAvailable(String slug, {String? excludeBusinessId}) async {
    final result = await _client.rpc(
      'is_business_slug_available',
      params: {'p_slug': slug, 'p_exclude_business': excludeBusinessId},
    );
    return result == true;
  }

  /// Moves onboarding progress forward only, never back.
  Future<void> advanceOnboarding(String id, int step) async {
    await _client
        .from('businesses')
        .update({'onboarding_step': step})
        .eq('id', id)
        .lt('onboarding_step', step);
  }

  Future<void> completeOnboarding(String id) async {
    await _client
        .from('businesses')
        .update({
          'onboarding_step': 6,
          'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<UserProfile> loadProfile() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    if (row == null) return const UserProfile();
    return UserProfile(fullName: row.str('full_name'), phone: row.str('phone'));
  }

  Future<void> saveProfile({String? fullName, String? phone}) async {
    await _client.from('profiles').upsert({
      'id': _userId,
      'full_name': fullName,
      'phone': phone,
    });
  }
}

final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => BusinessRepository(ref.watch(supabaseClientProvider)),
);

final userProfileProvider = FutureProvider.autoDispose<UserProfile>(
  (ref) => ref.watch(businessRepositoryProvider).loadProfile(),
);
