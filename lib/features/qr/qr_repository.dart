import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/supabase_providers.dart';
import 'qr_logic.dart';
import 'qr_models.dart';

/// Reads and writes tables and QR codes. Every method throws on failure;
/// screens show the message with `friendlyError`.
///
/// Row level security limits writes to owners, managers and the roles that run
/// the floor, so a refused write surfaces as a permission message.
class QrRepository {
  QrRepository(this._client);

  final SupabaseClient _client;

  // ---- reading ------------------------------------------------------------

  /// Every table and QR code of one branch, shaped for the screens.
  Future<QrOverview> overview(String branchId) async {
    final tableRows = await _client
        .from('restaurant_tables')
        .select()
        .eq('branch_id', branchId)
        .order('sort_order')
        .order('created_at');
    final codeRows = await _client
        .from('qr_codes')
        .select()
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);
    final tables = [
      for (final row in tableRows) RestaurantTable.fromJson(row),
    ]..sort(compareTables);
    final codes = [for (final row in codeRows) QrCode.fromJson(row)];
    return QrOverview.fromRows(tables: tables, codes: codes);
  }

  // ---- tables -------------------------------------------------------------

  /// Creates one table. A database trigger gives it a QR code.
  Future<RestaurantTable> createTable(
    String branchId,
    RestaurantTable table,
  ) async {
    final row = await _client
        .from('restaurant_tables')
        .insert({...table.toWriteJson(), 'branch_id': branchId})
        .select()
        .single();
    return RestaurantTable.fromJson(row);
  }

  /// Creates many tables in one request (each gets its QR code by trigger).
  /// [startOrder] is the display order of the first one.
  Future<int> createTables(
    String branchId,
    List<String> names, {
    required int startOrder,
    int? capacity,
    String? zone,
  }) async {
    if (names.isEmpty) return 0;
    final rows = [
      for (var i = 0; i < names.length; i++)
        {
          'branch_id': branchId,
          'name': names[i],
          'capacity': capacity,
          'zone': zone,
          'is_active': true,
          'sort_order': startOrder + i,
        },
    ];
    final saved = await _client.from('restaurant_tables').insert(rows).select('id');
    return saved.length;
  }

  Future<RestaurantTable> updateTable(RestaurantTable table) async {
    final row = await _client
        .from('restaurant_tables')
        .update(table.toWriteJson())
        .eq('id', table.id)
        .select()
        .single();
    return RestaurantTable.fromJson(row);
  }

  /// Switches a table on or off. A table that is off shows "table not
  /// available" to a customer who scans its code.
  Future<void> setTableActive(String id, bool active) async {
    await _client.from('restaurant_tables').update({'is_active': active}).eq('id', id);
  }

  /// Deletes a table and, by cascade, all of its QR codes.
  Future<void> deleteTable(String id) async {
    await _client.from('restaurant_tables').delete().eq('id', id);
  }

  // ---- QR codes -----------------------------------------------------------

  /// Creates a code of [kind] for the branch (or for [tableId]).
  Future<QrCode> createCode({
    required String branchId,
    required QrKind kind,
    String? tableId,
    String? label,
  }) async {
    final row = await _client.rpc(
      'create_qr_code',
      params: {
        'p_branch_id': branchId,
        'p_kind': kind.value,
        'p_table_id': kind == QrKind.table ? tableId : null,
        'p_label': label,
      },
    );
    return QrCode.fromJson(_asMap(row));
  }

  /// Replaces a code: the old token stops working at once and a new code of
  /// the same kind takes its place.
  Future<QrCode> regenerate(String qrId) async {
    final row = await _client.rpc('regenerate_qr_code', params: {'p_qr_id': qrId});
    return QrCode.fromJson(_asMap(row));
  }

  /// Switches a code off. Scanning it shows "this QR code is not active".
  Future<void> deactivate(String qrId) async {
    await _client
        .from('qr_codes')
        .update({
          'is_active': false,
          'deactivated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', qrId);
  }

  /// Switches an old code back on. Fails when the branch, takeaway counter
  /// or table already has another active code.
  Future<void> reactivate(String qrId) async {
    try {
      await _client
          .from('qr_codes')
          .update({'is_active': true, 'deactivated_at': null})
          .eq('id', qrId);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const AppException(
          'Another code is already active here. Switch it off first.',
        );
      }
      rethrow;
    }
  }

  /// One code by id, or null when it does not exist (or is not visible).
  Future<QrCode?> codeById(String qrId) async {
    final rows = await _client.from('qr_codes').select().eq('id', qrId).limit(1);
    if (rows.isEmpty) return null;
    return QrCode.fromJson(rows.first);
  }

  /// One table by id, or null when it does not exist (or is not visible).
  Future<RestaurantTable?> tableById(String tableId) async {
    final rows = await _client.from('restaurant_tables').select().eq('id', tableId).limit(1);
    if (rows.isEmpty) return null;
    return RestaurantTable.fromJson(rows.first);
  }

  /// A code together with its table, for the detail screen.
  Future<QrDetail?> detail(String qrId) async {
    final code = await codeById(qrId);
    if (code == null) return null;
    final tableId = code.tableId;
    final table = tableId == null ? null : await tableById(tableId);
    return QrDetail(code: code, table: table);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw const AppException('The server sent back something unexpected. Try again.');
  }
}

final qrRepositoryProvider = Provider<QrRepository>(
  (ref) => QrRepository(ref.watch(supabaseClientProvider)),
);

/// Tables and codes of the selected branch. Null while no branch is selected.
final qrOverviewProvider = FutureProvider.autoDispose<QrOverview?>((ref) async {
  final branch = ref.watch(selectedBranchProvider);
  if (branch == null) return null;
  return ref.watch(qrRepositoryProvider).overview(branch.id);
});

/// One code with its table (the detail screen).
final qrDetailProvider = FutureProvider.autoDispose.family<QrDetail?, String>((
  ref,
  qrId,
) {
  return ref.watch(qrRepositoryProvider).detail(qrId);
});

/// One table by id (the table form).
final restaurantTableProvider = FutureProvider.autoDispose
    .family<RestaurantTable?, String>((ref, tableId) {
      return ref.watch(qrRepositoryProvider).tableById(tableId);
    });

/// Refreshes the tables and codes lists after a change.
void refreshQr(WidgetRef ref) {
  ref.invalidate(qrOverviewProvider);
}
