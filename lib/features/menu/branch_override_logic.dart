import 'menu_models.dart';

/// Pure helpers for per-branch price and availability overrides.
///
/// A branch price replaces BOTH the regular and the discount price of the dish
/// at that branch. A branch without any override has no entry at all.

/// What a branch charges for a dish.
class BranchPriceView {
  const BranchPriceView({
    required this.price,
    this.discountPrice,
    this.isOverride = false,
  });

  final double price;
  final double? discountPrice;
  final bool isOverride;

  bool get hasDiscount => discountPrice != null && discountPrice! < price;
  double get payable => hasDiscount ? discountPrice! : price;
}

BranchPriceView branchPriceView({
  required double basePrice,
  double? baseDiscountPrice,
  BranchItemSetting? setting,
}) {
  if (setting != null && setting.price != null) {
    return BranchPriceView(
      price: setting.price!,
      discountPrice: setting.discountPrice,
      isOverride: true,
    );
  }
  return BranchPriceView(price: basePrice, discountPrice: baseDiscountPrice);
}

/// True when the entry changes anything compared with "same as all branches".
bool hasOverride(BranchItemSetting setting) =>
    !setting.isOffered || setting.price != null || setting.isSoldOut;

/// The entry for one branch, or null.
BranchItemSetting? settingOf(List<BranchItemSetting> settings, String branchId) {
  for (final s in settings) {
    if (s.branchId == branchId) return s;
  }
  return null;
}

/// Replaces (or adds) the entry for the branch. An entry that no longer
/// overrides anything is removed. The order of other entries is kept.
List<BranchItemSetting> upsertSetting(
  List<BranchItemSetting> settings,
  BranchItemSetting next,
) {
  final result = <BranchItemSetting>[];
  var placed = false;
  for (final s in settings) {
    if (s.branchId == next.branchId) {
      if (hasOverride(next)) result.add(next);
      placed = true;
    } else {
      result.add(s);
    }
  }
  if (!placed && hasOverride(next)) result.add(next);
  return result;
}

List<BranchItemSetting> removeSetting(
  List<BranchItemSetting> settings,
  String branchId,
) => [
  for (final s in settings)
    if (s.branchId != branchId) s,
];

/// A blank (no override) entry for a branch.
BranchItemSetting blankSetting(String branchId, String itemId) =>
    BranchItemSetting(branchId: branchId, itemId: itemId);

/// The same settings with the real dish id (a new dish is saved first).
List<BranchItemSetting> withItemId(List<BranchItemSetting> settings, String itemId) => [
  for (final s in settings)
    BranchItemSetting(
      branchId: s.branchId,
      itemId: itemId,
      isOffered: s.isOffered,
      price: s.price,
      discountPrice: s.discountPrice,
      isSoldOut: s.isSoldOut,
      soldOutUntil: s.soldOutUntil,
    ),
];

/// Branch ids that had an override before and have none now: their rows must
/// be cleared on save.
List<String> removedBranchIds(
  List<BranchItemSetting> before,
  List<BranchItemSetting> after,
) {
  final kept = {for (final s in after) s.branchId};
  return [
    for (final s in before)
      if (!kept.contains(s.branchId)) s.branchId,
  ];
}

/// Plain English problems, empty when the settings can be saved.
/// [branchNames] maps a branch id to the name used in the messages.
List<String> validateBranchSettings(
  List<BranchItemSetting> settings, {
  required double basePrice,
  Map<String, String> branchNames = const {},
}) {
  final errors = <String>[];
  final seen = <String>{};
  for (final s in settings) {
    final name = branchNames[s.branchId] ?? 'A branch';
    if (!seen.add(s.branchId)) {
      errors.add('$name has more than one override.');
    }
    final price = s.price;
    final discount = s.discountPrice;
    if (price != null && price < 0) {
      errors.add('$name: the branch price cannot be negative.');
    }
    if (price == null && discount != null) {
      errors.add('$name: a branch discount needs a branch price.');
    }
    if (price != null && discount != null) {
      if (discount < 0) {
        errors.add('$name: the branch discount price cannot be negative.');
      } else if (discount >= price) {
        errors.add('$name: the branch discount must be lower than the branch price.');
      }
    }
  }
  return errors;
}
