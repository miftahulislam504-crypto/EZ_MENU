import '../../core/logic/menu_search.dart';
import '../../core/logic/sold_out.dart';
import 'menu_models.dart';

/// Pure helpers for the availability screen: what "sold out" means for a dish
/// in the current view, counts, grouping by category and the row captions.
/// No Flutter imports.

/// Where a sold-out switch applies on the availability screen.
enum StockScope { allBranches, thisBranch }

/// Whether a dish can be ordered right now and why not.
class StockStatus {
  const StockStatus({
    required this.soldOut,
    this.until,
    this.byMaster = false,
    this.byBranch = false,
  });

  static const StockStatus available = StockStatus(soldOut: false);

  final bool soldOut;

  /// When the dish returns by itself. Null while sold out means it stays sold
  /// out until someone switches it back on.
  final DateTime? until;

  /// Sold out at every branch (the master switch).
  final bool byMaster;

  /// Sold out at the viewed branch through its own override.
  final bool byBranch;

  /// Sold out at the viewed branch only.
  bool get branchOnly => soldOut && byBranch && !byMaster;

  /// Sold out now and coming back at a set time.
  bool get scheduled => soldOut && until != null;

  @override
  bool operator ==(Object other) =>
      other is StockStatus &&
      other.soldOut == soldOut &&
      other.until == until &&
      other.byMaster == byMaster &&
      other.byBranch == byBranch;

  @override
  int get hashCode => Object.hash(soldOut, until, byMaster, byBranch);
}

/// Status of [item] at [now]. [setting] is the viewed branch's override, or
/// null when the view is "all branches". An expired "back at" time counts as
/// available again.
StockStatus stockStatus(
  MenuItem item,
  BranchItemSetting? setting,
  DateTime now,
) {
  final byMaster = item.isSoldOutAt(now);
  final byBranch = setting?.isSoldOutAt(now) ?? false;
  if (!byMaster && !byBranch) return StockStatus.available;

  // It returns only when every active switch has cleared, so a manual switch
  // wins and otherwise the latest time counts.
  final times = <DateTime?>[
    if (byMaster) item.soldOutUntil,
    if (byBranch) setting!.soldOutUntil,
  ];
  DateTime? until;
  if (!times.contains(null)) {
    for (final time in times) {
      if (until == null || time!.isAfter(until)) until = time;
    }
  }
  return StockStatus(
    soldOut: true,
    until: until,
    byMaster: byMaster,
    byBranch: byBranch,
  );
}

/// A dish and its status in the current view.
class StockEntry {
  const StockEntry(this.item, this.status);

  final MenuItem item;
  final StockStatus status;

  StockEntry withStatus(StockStatus next) => StockEntry(item, next);
}

/// Everything the screen lists: live dishes that are switched on. Dishes that
/// are switched off (hidden from customers) are not listed; they are counted
/// in [hiddenCount] so the screen can say so.
class StockView {
  const StockView({required this.entries, this.hiddenCount = 0});

  final List<StockEntry> entries;
  final int hiddenCount;
}

/// [settings] is empty for the "all branches" view. [overrides] holds
/// optimistic statuses that replace the stored ones until a write finishes.
StockView buildStockView(
  Iterable<MenuItem> items, {
  required Map<String, BranchItemSetting> settings,
  required DateTime now,
  Map<String, StockStatus> overrides = const {},
}) {
  final entries = <StockEntry>[];
  var hidden = 0;
  for (final item in items) {
    if (item.isDeleted) continue;
    if (!item.isActive) {
      hidden++;
      continue;
    }
    final status =
        overrides[item.id] ?? stockStatus(item, settings[item.id], now);
    entries.add(StockEntry(item, status));
  }
  return StockView(entries: entries, hiddenCount: hidden);
}

/// Header numbers. The three groups never overlap.
class StockCounts {
  const StockCounts({
    this.available = 0,
    this.soldOut = 0,
    this.scheduled = 0,
  });

  /// Can be ordered.
  final int available;

  /// Sold out until someone switches it back on.
  final int soldOut;

  /// Sold out now but coming back at a set time.
  final int scheduled;

  int get total => available + soldOut + scheduled;

  /// Sold out for any reason.
  int get unavailable => soldOut + scheduled;
}

StockCounts countStock(Iterable<StockEntry> entries) {
  var available = 0;
  var soldOut = 0;
  var scheduled = 0;
  for (final entry in entries) {
    if (!entry.status.soldOut) {
      available++;
    } else if (entry.status.until != null) {
      scheduled++;
    } else {
      soldOut++;
    }
  }
  return StockCounts(
    available: available,
    soldOut: soldOut,
    scheduled: scheduled,
  );
}

/// Entries matching the search words and, when given, a set of categories.
List<StockEntry> filterStock(
  Iterable<StockEntry> entries, {
  String query = '',
  Set<String>? categoryIds,
}) {
  return [
    for (final entry in entries)
      if ((categoryIds == null || categoryIds.contains(entry.item.categoryId)) &&
          itemMatchesQuery(entry.item, query))
        entry,
  ];
}

/// Dishes of one category, in menu order.
class StockGroup {
  const StockGroup({
    required this.id,
    required this.name,
    required this.entries,
  });

  /// Category id, or `uncategorised` for dishes whose category is gone.
  final String id;
  final String name;
  final List<StockEntry> entries;

  int get soldOutCount => entries.where((e) => e.status.soldOut).length;
  int get availableCount => entries.length - soldOutCount;
}

const String uncategorisedGroupId = 'uncategorised';

/// Groups [entries] by category in menu order. A subcategory is named
/// "Parent / Child". Empty groups are left out. Within a group dishes follow
/// their sort order, then name.
List<StockGroup> groupStock(
  Iterable<StockEntry> entries,
  List<MenuCategory> categories,
) {
  final byId = {for (final c in categories) c.id: c};
  final rank = categoryRankOf(categories);
  final buckets = <String, List<StockEntry>>{};
  for (final entry in entries) {
    final id = byId.containsKey(entry.item.categoryId)
        ? entry.item.categoryId
        : uncategorisedGroupId;
    buckets.putIfAbsent(id, () => []).add(entry);
  }

  String nameOf(MenuCategory category) {
    final parent = category.parentId == null ? null : byId[category.parentId];
    return parent == null
        ? category.displayName
        : '${parent.displayName} / ${category.displayName}';
  }

  int compareEntries(StockEntry a, StockEntry b) {
    final byOrder = a.item.sortOrder.compareTo(b.item.sortOrder);
    if (byOrder != 0) return byOrder;
    final byName = a.item.displayName.toLowerCase().compareTo(
      b.item.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.item.id.compareTo(b.item.id);
  }

  final ids = buckets.keys.where((id) => id != uncategorisedGroupId).toList()
    ..sort((a, b) {
      final byRank = (rank[a] ?? 1 << 30).compareTo(rank[b] ?? 1 << 30);
      return byRank != 0 ? byRank : a.compareTo(b);
    });

  return [
    for (final id in ids)
      StockGroup(
        id: id,
        name: nameOf(byId[id]!),
        entries: buckets[id]!..sort(compareEntries),
      ),
    if (buckets.containsKey(uncategorisedGroupId))
      StockGroup(
        id: uncategorisedGroupId,
        name: 'Uncategorised',
        entries: buckets[uncategorisedGroupId]!..sort(compareEntries),
      ),
  ];
}

String _capitalise(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// The line under a sold-out dish: "Back at 3:30 PM", "Until switched back on",
/// plus where it applies when the view is a branch ([showScope]).
String stockCaption(StockStatus status, DateTime now, {bool showScope = false}) {
  if (!status.soldOut) return 'Available';
  final when = status.until == null
      ? 'Until switched back on'
      : _capitalise(backAtText(status.until!, now));
  if (!showScope) return when;
  if (status.branchOnly) return '$when  -  This branch only';
  if (status.byMaster) return '$when  -  All branches';
  return when;
}

/// Ids of entries that are not sold out (the ones a bulk "sold out" touches).
List<String> availableIds(Iterable<StockEntry> entries) => [
  for (final entry in entries)
    if (!entry.status.soldOut) entry.item.id,
];

/// Ids of entries that are sold out for any reason.
List<String> soldOutIds(Iterable<StockEntry> entries) => [
  for (final entry in entries)
    if (entry.status.soldOut) entry.item.id,
];

/// How a "back in stock" write splits: the master switch on these dishes and
/// the branch override on these dishes.
class RestockPlan {
  const RestockPlan({this.masterIds = const [], this.branchIds = const []});

  final List<String> masterIds;
  final List<String> branchIds;

  bool get isEmpty => masterIds.isEmpty && branchIds.isEmpty;
}

/// Which switches must be cleared to bring [entries] back in stock. Only the
/// switches that are actually on are touched.
RestockPlan planRestock(Iterable<StockEntry> entries) {
  final master = <String>[];
  final branch = <String>[];
  for (final entry in entries) {
    if (entry.status.byMaster) master.add(entry.item.id);
    if (entry.status.byBranch) branch.add(entry.item.id);
  }
  return RestockPlan(masterIds: master, branchIds: branch);
}

/// The status a dish should show right after the person switches it, before
/// the server answers.
StockStatus optimisticSoldOut({
  required DateTime? until,
  required bool branchWrite,
}) => StockStatus(
  soldOut: true,
  until: until,
  byMaster: !branchWrite,
  byBranch: branchWrite,
);

/// Short phrase for a count of dishes: "1 dish", "12 dishes".
String dishCount(int count) => count == 1 ? '1 dish' : '$count dishes';
