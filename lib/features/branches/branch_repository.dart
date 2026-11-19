import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/models.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/logic/hours.dart';
import 'hours_editing.dart';

/// Branch records and their opening hours.
class BranchRepository {
  BranchRepository(this._client);

  final SupabaseClient _client;

  Future<Branch> create(String businessId, Map<String, dynamic> values) async {
    final row = await _client
        .from('branches')
        .insert({...values, 'business_id': businessId})
        .select()
        .single();
    return Branch.fromJson(row);
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    await _client.from('branches').update(values).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }

  /// Writes the new display order: the first id gets 0, the next 1, and so on.
  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client
          .from('branches')
          .update({'sort_order': i})
          .eq('id', orderedIds[i]);
    }
  }

  Future<bool> isSlugAvailable(
    String businessId,
    String slug, {
    String? excludeBranchId,
  }) async {
    final result = await _client.rpc(
      'is_branch_slug_available',
      params: {
        'p_business_id': businessId,
        'p_slug': slug,
        'p_exclude_branch': excludeBranchId,
      },
    );
    return result == true;
  }

  // ---- hours --------------------------------------------------------------

  Future<List<HoursRow>> loadHours(String branchId) async {
    final rows = await _client
        .from('branch_hours')
        .select()
        .eq('branch_id', branchId)
        .order('created_at');
    return rows.map((row) => HoursRow.fromJson(row)).toList();
  }

  /// Replaces the weekly schedule. New rows are written first and the old ones
  /// removed afterwards, so a failure part way never leaves the branch with no
  /// hours at all.
  Future<void> saveWeekly(String branchId, WeekDraft week) async {
    final existing = await _client
        .from('branch_hours')
        .select('id')
        .eq('branch_id', branchId)
        .not('weekday', 'is', null);
    final oldIds = [for (final row in existing) row['id'] as String];

    final inserts = <Map<String, dynamic>>[];
    for (final day in weekOrderBangladesh) {
      for (final period in week[day] ?? const <DraftPeriod>[]) {
        inserts.add({
          'branch_id': branchId,
          'weekday': day,
          'open_time': period.open,
          'close_time': period.close,
          'label_en': period.labelEn.trim().isEmpty
              ? null
              : period.labelEn.trim(),
          'label_bn': period.labelBn.trim().isEmpty
              ? null
              : period.labelBn.trim(),
        });
      }
    }
    if (inserts.isNotEmpty) {
      await _client.from('branch_hours').insert(inserts);
    }
    if (oldIds.isNotEmpty) {
      await _client.from('branch_hours').delete().inFilter('id', oldIds);
    }
  }

  /// Adds a special day or range: closed, or with its own periods.
  Future<void> addSpecialDay(
    String branchId, {
    required DateTime start,
    DateTime? end,
    required bool closed,
    List<DraftPeriod> periods = const <DraftPeriod>[],
    String? noteEn,
    String? noteBn,
  }) async {
    final base = {
      'branch_id': branchId,
      'special_date': isoDate(start),
      'special_date_end': end == null ? null : isoDate(end),
    };
    String? clean(String? value) {
      final text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    if (closed) {
      await _client.from('branch_hours').insert({
        ...base,
        'is_closed': true,
        'label_en': clean(noteEn),
        'label_bn': clean(noteBn),
      });
      return;
    }
    await _client.from('branch_hours').insert([
      for (final period in periods)
        {
          ...base,
          'is_closed': false,
          'open_time': period.open,
          'close_time': period.close,
          'label_en': period.labelEn.trim().isEmpty
              ? null
              : period.labelEn.trim(),
          'label_bn': period.labelBn.trim().isEmpty
              ? null
              : period.labelBn.trim(),
        },
    ]);
  }

  Future<void> deleteHoursRows(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('branch_hours').delete().inFilter('id', ids);
  }

  Future<void> saveClosure(
    String branchId, {
    required bool closed,
    String? messageEn,
    String? messageBn,
    DateTime? until,
    required String outsideHoursBehavior,
  }) async {
    await _client
        .from('branches')
        .update({
          'outside_hours_behavior': outsideHoursBehavior,
          'temp_closed': closed,
          'temp_closed_message_en': closed ? messageEn : null,
          'temp_closed_message_bn': closed ? messageBn : null,
          'temp_closed_until': closed ? until?.toUtc().toIso8601String() : null,
        })
        .eq('id', branchId);
  }
}

final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepository(ref.watch(supabaseClientProvider)),
);

/// All hours rows of one branch. Invalidate after saving.
final branchHoursProvider = FutureProvider.autoDispose
    .family<List<HoursRow>, String>(
      (ref, branchId) =>
          ref.watch(branchRepositoryProvider).loadHours(branchId),
    );
