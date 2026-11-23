import '../../core/utils/json_utils.dart';

/// Rows of `qr_codes` and `restaurant_tables`. Pure Dart, no Flutter imports.

enum QrKind {
  branch('branch'),
  takeaway('takeaway'),
  table('table');

  const QrKind(this.value);

  /// Value stored in `qr_codes.kind`.
  final String value;

  static QrKind parse(String? value) {
    for (final kind in QrKind.values) {
      if (kind.value == value) return kind;
    }
    return QrKind.branch;
  }
}

class QrCode {
  const QrCode({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.kind,
    required this.token,
    required this.isActive,
    this.tableId,
    this.label,
    this.scanCount = 0,
    this.lastScannedAt,
    this.deactivatedAt,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String branchId;
  final String? tableId;
  final QrKind kind;
  final String token;
  final String? label;
  final bool isActive;
  final int scanCount;
  final DateTime? lastScannedAt;
  final DateTime? deactivatedAt;
  final DateTime? createdAt;

  factory QrCode.fromJson(Map<String, dynamic> j) => QrCode(
    id: j.requireStr('id'),
    businessId: j.requireStr('business_id'),
    branchId: j.requireStr('branch_id'),
    tableId: j.str('table_id'),
    kind: QrKind.parse(j.str('kind')),
    token: j.requireStr('token'),
    label: j.str('label'),
    isActive: j.boolean('is_active', fallback: true),
    scanCount: j.integer('scan_count'),
    lastScannedAt: j.date('last_scanned_at'),
    deactivatedAt: j.date('deactivated_at'),
    createdAt: j.date('created_at'),
  );
}

class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.branchId,
    required this.name,
    this.capacity,
    this.zone,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String branchId;
  final String name;
  final int? capacity;
  final String? zone;
  final bool isActive;
  final int sortOrder;

  factory RestaurantTable.fromJson(Map<String, dynamic> j) => RestaurantTable(
    id: j.requireStr('id'),
    branchId: j.requireStr('branch_id'),
    name: j.requireStr('name'),
    capacity: j.intOrNull('capacity'),
    zone: j.str('zone'),
    isActive: j.boolean('is_active', fallback: true),
    sortOrder: j.integer('sort_order'),
  );

  /// Columns written on insert and update (never the branch or the id).
  Map<String, dynamic> toWriteJson() => {
    'name': name,
    'capacity': capacity,
    'zone': zone,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

/// One code with the table it belongs to (null for branch and takeaway codes).
class QrDetail {
  const QrDetail({required this.code, this.table});

  final QrCode code;
  final RestaurantTable? table;
}

/// Everything the QR and tables screen shows for one branch.
class QrOverview {
  const QrOverview({
    this.branchCode,
    this.takeawayCode,
    this.tables = const [],
    this.tableCodes = const {},
    this.inactiveCodes = 0,
  });

  /// The active branch menu code, if any.
  final QrCode? branchCode;

  /// The active takeaway counter code, if any.
  final QrCode? takeawayCode;
  final List<RestaurantTable> tables;

  /// Active code of each table, keyed by table id.
  final Map<String, QrCode> tableCodes;

  /// Old (replaced or switched off) codes of the branch.
  final int inactiveCodes;

  /// Total scans over the active codes shown on this screen.
  int get totalScans =>
      (branchCode?.scanCount ?? 0) +
      (takeawayCode?.scanCount ?? 0) +
      tableCodes.values.fold<int>(0, (sum, c) => sum + c.scanCount);

  /// Number of active codes (branch, takeaway and tables).
  int get activeCodes =>
      (branchCode == null ? 0 : 1) + (takeawayCode == null ? 0 : 1) + tableCodes.length;

  /// Builds the overview from raw rows. Only the newest active code of each
  /// kind and table is kept (the database allows one anyway).
  factory QrOverview.fromRows({
    required List<RestaurantTable> tables,
    required List<QrCode> codes,
  }) {
    QrCode? branch;
    QrCode? takeaway;
    final byTable = <String, QrCode>{};
    var inactive = 0;
    for (final code in codes) {
      if (!code.isActive) {
        inactive++;
        continue;
      }
      switch (code.kind) {
        case QrKind.branch:
          branch ??= code;
        case QrKind.takeaway:
          takeaway ??= code;
        case QrKind.table:
          final id = code.tableId;
          if (id != null) byTable.putIfAbsent(id, () => code);
      }
    }
    return QrOverview(
      branchCode: branch,
      takeawayCode: takeaway,
      tables: tables,
      tableCodes: byTable,
      inactiveCodes: inactive,
    );
  }
}
