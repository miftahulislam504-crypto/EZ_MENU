import '../../features/menu/menu_models.dart';
import 'money.dart';

/// Bulk price changes. This mirrors the database function
/// `bulk_adjust_prices` (and `_adjust_amount`) exactly, so the preview shows
/// what will be saved:
///  - the new amount is never below 0 and is rounded half up to 2 decimals
///    (or to a whole number with [PriceChange.roundWhole]);
///  - a discount is dropped whenever it is no longer lower than the price;
///  - with a branch, the branch price override is changed instead of the dish
///    price. A branch price replaces both the regular and the discount price.

enum PriceChangeMode {
  percentIncrease('percent_increase'),
  percentDecrease('percent_decrease'),
  fixedIncrease('fixed_increase'),
  fixedDecrease('fixed_decrease'),
  setExact('set');

  const PriceChangeMode(this.sql);

  /// The value the database function expects.
  final String sql;

  bool get isPercent =>
      this == PriceChangeMode.percentIncrease ||
      this == PriceChangeMode.percentDecrease;
}

enum PriceTarget {
  price('price'),
  discount('discount'),
  both('both');

  const PriceTarget(this.sql);
  final String sql;

  bool get touchesPrice => this != PriceTarget.discount;
  bool get touchesDiscount => this != PriceTarget.price;
}

/// What the person asked for.
class PriceChange {
  const PriceChange({
    required this.mode,
    required this.value,
    this.target = PriceTarget.price,
    this.roundWhole = false,
    this.branchId,
  });

  final PriceChangeMode mode;
  final double value;
  final PriceTarget target;
  final bool roundWhole;

  /// When set, the branch price override of this branch is changed.
  final String? branchId;

  bool get isBranch => branchId != null;

  /// A message when the database would refuse this change, else null.
  String? get problem {
    if (value.isNaN || value.isInfinite || value < 0) {
      return 'Enter a number, zero or more.';
    }
    if (mode == PriceChangeMode.setExact && target == PriceTarget.discount && isBranch) {
      return 'Set a branch price instead of a branch discount only.';
    }
    return null;
  }

  /// A note that is not an error but worth reading, else null.
  String? get notice {
    if (mode == PriceChangeMode.percentDecrease && value > 100) {
      return 'A decrease above 100% sets the prices to 0.';
    }
    if (mode == PriceChangeMode.setExact && target == PriceTarget.both) {
      return 'Both the price and the discount price become the same amount, so the discount is removed.';
    }
    return null;
  }
}

/// Rounds half up (away from zero), like the database `round(numeric, n)`.
double roundHalfUp(double value, int decimals) {
  var factor = 1.0;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  final scaled = value * factor;
  // A tiny nudge keeps 1.005 * 100 = 100.49999999999999 from rounding down.
  final nudged = scaled + (scaled >= 0 ? 1e-7 : -1e-7);
  return nudged.roundToDouble() / factor;
}

/// `_adjust_amount` of the database.
double adjustAmount(
  double amount,
  PriceChangeMode mode,
  double value, {
  bool roundWhole = false,
}) {
  double raw;
  switch (mode) {
    case PriceChangeMode.percentIncrease:
      raw = amount * (1 + value / 100);
    case PriceChangeMode.percentDecrease:
      raw = amount * (1 - value / 100);
    case PriceChangeMode.fixedIncrease:
      raw = amount + value;
    case PriceChangeMode.fixedDecrease:
      raw = amount - value;
    case PriceChangeMode.setExact:
      raw = value;
  }
  if (raw < 0) raw = 0;
  return roundHalfUp(raw, roundWhole ? 0 : 2);
}

/// Parses the typed value: "10", "10%", "2.5", "tk 50", "৫০". Null when empty
/// or not a plain number.
double? parseChangeValue(String? text) {
  if (text == null) return null;
  return parseMoneyText(text.replaceAll('%', ''));
}

enum PriceWarning {
  /// The new price is 0.
  becomesFree,

  /// The discount is dropped because it is no longer lower than the price.
  discountDropped,

  /// The dish gets a branch price it did not have (branch scope).
  createsBranchPrice,
}

/// One dish in the preview.
class PriceRow {
  const PriceRow({
    required this.itemId,
    required this.name,
    required this.oldPrice,
    required this.oldDiscount,
    required this.newPrice,
    required this.newDiscount,
    this.warnings = const [],
  });

  final String itemId;
  final String name;
  final double oldPrice;
  final double? oldDiscount;
  final double newPrice;
  final double? newDiscount;
  final List<PriceWarning> warnings;

  bool get priceChanged => newPrice != oldPrice;
  bool get discountChanged => newDiscount != oldDiscount;
  bool get changed => priceChanged || discountChanged;
  double get delta => newPrice - oldPrice;

  /// What a customer pays now and after the change.
  double get oldPayable => oldDiscount ?? oldPrice;
  double get newPayable => newDiscount ?? newPrice;
}

/// The preview of [change] for [items] (pass only dishes that are not
/// deleted, as the database ignores deleted ones). [branchSettings] maps a
/// dish id to its override at the branch of the change.
List<PriceRow> previewPriceChange({
  required List<MenuItem> items,
  required PriceChange change,
  Map<String, BranchItemSetting> branchSettings = const {},
}) {
  final rows = <PriceRow>[];
  for (final item in items) {
    double currentPrice = item.price;
    double? currentDiscount = item.discountPrice;
    var hadBranchPrice = false;
    if (change.isBranch) {
      final setting = branchSettings[item.id];
      if (setting != null && setting.price != null) {
        hadBranchPrice = true;
        currentPrice = setting.price!;
        currentDiscount = setting.discountPrice;
      }
    }

    final newPrice = change.target.touchesPrice
        ? adjustAmount(currentPrice, change.mode, change.value, roundWhole: change.roundWhole)
        : currentPrice;
    double? adjustedDiscount = currentDiscount;
    if (change.target.touchesDiscount && currentDiscount != null) {
      adjustedDiscount = adjustAmount(
        currentDiscount,
        change.mode,
        change.value,
        roundWhole: change.roundWhole,
      );
    }
    final dropped = adjustedDiscount != null && adjustedDiscount >= newPrice;
    final newDiscount = dropped ? null : adjustedDiscount;

    final row = PriceRow(
      itemId: item.id,
      name: item.displayName,
      oldPrice: currentPrice,
      oldDiscount: currentDiscount,
      newPrice: newPrice,
      newDiscount: newDiscount,
      warnings: const [],
    );
    final warnings = <PriceWarning>[
      if (row.changed && newPrice == 0 && currentPrice > 0) PriceWarning.becomesFree,
      if (row.changed && dropped && currentDiscount != null && !(currentDiscount >= currentPrice))
        PriceWarning.discountDropped,
      if (row.changed && change.isBranch && !hadBranchPrice) PriceWarning.createsBranchPrice,
    ];
    rows.add(
      PriceRow(
        itemId: row.itemId,
        name: row.name,
        oldPrice: row.oldPrice,
        oldDiscount: row.oldDiscount,
        newPrice: row.newPrice,
        newDiscount: row.newDiscount,
        warnings: warnings,
      ),
    );
  }
  return rows;
}

/// Totals of a preview.
class PriceSummary {
  const PriceSummary({
    this.total = 0,
    this.changed = 0,
    this.unchanged = 0,
    this.discountsDropped = 0,
    this.becameFree = 0,
    this.createsBranchPrice = 0,
    this.totalDelta = 0,
  });

  final int total;
  final int changed;
  final int unchanged;
  final int discountsDropped;
  final int becameFree;
  final int createsBranchPrice;

  /// Sum of (new price - old price) over the changed dishes.
  final double totalDelta;
}

PriceSummary summarizePriceChange(List<PriceRow> rows) {
  var changed = 0;
  var dropped = 0;
  var free = 0;
  var creates = 0;
  var delta = 0.0;
  for (final row in rows) {
    if (!row.changed) continue;
    changed++;
    delta += row.delta;
    if (row.warnings.contains(PriceWarning.discountDropped)) dropped++;
    if (row.warnings.contains(PriceWarning.becomesFree)) free++;
    if (row.warnings.contains(PriceWarning.createsBranchPrice)) creates++;
  }
  return PriceSummary(
    total: rows.length,
    changed: changed,
    unchanged: rows.length - changed,
    discountsDropped: dropped,
    becameFree: free,
    createsBranchPrice: creates,
    totalDelta: roundHalfUp(delta, 2),
  );
}

/// Ids of the dishes that must be sent to the database: only those that
/// change, so a branch is not given a pointless price of its own.
List<String> idsToApply(List<PriceRow> rows) => [
  for (final row in rows)
    if (row.changed) row.itemId,
];
