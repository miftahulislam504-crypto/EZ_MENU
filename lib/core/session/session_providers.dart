import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../supabase/supabase_providers.dart';
import 'models.dart';

/// Every business the signed-in person belongs to (row level security does the
/// filtering). Phase 1 works with the first one.
final businessesProvider = FutureProvider<List<Business>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <Business>[];
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('businesses')
      .select()
      .order('created_at');
  return rows.map((row) => Business.fromJson(row)).toList();
});

/// The business the dashboard is working on, or null before onboarding.
final currentBusinessProvider = Provider<AsyncValue<Business?>>((ref) {
  return ref
      .watch(businessesProvider)
      .whenData((list) => list.isEmpty ? null : list.first);
});

final currentBusinessIdProvider = Provider<String?>(
  (ref) => ref.watch(currentBusinessProvider).valueOrNull?.id,
);

/// All branches of the current business, in display order.
final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final businessId = ref.watch(currentBusinessIdProvider);
  if (businessId == null) return const <Branch>[];
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('branches')
      .select()
      .eq('business_id', businessId)
      .order('sort_order')
      .order('created_at');
  return rows.map((row) => Branch.fromJson(row)).toList();
});

/// Remembers which branch the dashboard shows between launches.
class SelectedBranchNotifier extends Notifier<String?> {
  static const String _key = 'selected_branch_id';

  @override
  String? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) state = saved;
    } catch (_) {
      // Storage can be unavailable (private browsing); the first branch is used.
    }
  }

  Future<void> select(String? branchId) async {
    state = branchId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (branchId == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, branchId);
      }
    } catch (_) {
      // Ignore: the choice still applies for this session.
    }
  }
}

final selectedBranchIdProvider =
    NotifierProvider<SelectedBranchNotifier, String?>(
      SelectedBranchNotifier.new,
    );

/// The branch the dashboard is showing: the remembered one if it still exists
/// and is active, otherwise the first active branch.
final selectedBranchProvider = Provider<Branch?>((ref) {
  final branches = ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
  if (branches.isEmpty) return null;
  final active = branches.where((b) => b.isActive).toList();
  final pool = active.isEmpty ? branches : active;
  final savedId = ref.watch(selectedBranchIdProvider);
  for (final branch in pool) {
    if (branch.id == savedId) return branch;
  }
  return pool.first;
});

/// Reload helpers for screens that just changed business or branch data.
extension SessionRefresh on WidgetRef {
  void refreshBusiness() {
    invalidate(businessesProvider);
    invalidate(branchesProvider);
  }

  void refreshBranches() => invalidate(branchesProvider);
}
