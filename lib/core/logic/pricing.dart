import 'dart:math' as math;

/// How an option's price combines with the item price.
///  - additional: the option price is added (extra cheese +40).
///  - absolute:   the option price REPLACES the item price (Half 250 / Full 450).
enum OptionPriceMode { additional, absolute }

class PricedOption {
  const PricedOption({
    required this.id,
    required this.price,
    this.discountPrice,
    this.isAvailable = true,
  });

  final String id;
  final double price;
  final double? discountPrice;
  final bool isAvailable;
}

class PricedGroup {
  const PricedGroup({
    required this.id,
    required this.options,
    this.multiple = false,
    this.mode = OptionPriceMode.additional,
    this.isRequired = false,
    this.minSelect = 0,
    this.maxSelect,
  });

  final String id;
  final List<PricedOption> options;
  final bool multiple;
  final OptionPriceMode mode;
  final bool isRequired;
  final int minSelect;
  final int? maxSelect;

  /// A required group always needs at least one choice.
  int get effectiveMin => isRequired ? math.max(minSelect, 1) : minSelect;

  /// A single-choice group never allows more than one.
  int? get effectiveMax => multiple ? maxSelect : 1;
}

/// Why a selection is not valid yet.
enum SelectionProblem { required, tooFew, tooMany, unavailable }

class SelectionIssue {
  const SelectionIssue(this.groupId, this.problem);

  final String groupId;
  final SelectionProblem problem;

  @override
  String toString() => 'SelectionIssue($groupId, ${problem.name})';
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.unitPrice,
    required this.unitOriginalPrice,
    required this.issues,
  });

  /// Price of one unit with the current selection and discounts applied.
  final double unitPrice;

  /// Price of one unit before discounts (what to show struck through).
  final double unitOriginalPrice;
  final List<SelectionIssue> issues;

  bool get hasDiscount => unitOriginalPrice - unitPrice > 0.004;
  bool get isValid => issues.isEmpty;

  double lineTotal(int quantity) => _round2(unitPrice * quantity);
  double lineOriginalTotal(int quantity) =>
      _round2(unitOriginalPrice * quantity);
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// Computes the price of one unit of an item for the chosen options.
///
/// [selections] maps a group id to the set of chosen option ids.
///
/// Rules
///  * The first absolute group with a choice replaces the item price. The
///    item-level discount then no longer applies; the option's own discount
///    does.
///  * Additional options add their regular price.
///  * Required / min / max limits and unavailable options are reported in
///    [PriceBreakdown.issues]; the price is still computed so the UI can show it.
PriceBreakdown computeItemPrice({
  required double basePrice,
  double? baseDiscountPrice,
  required List<PricedGroup> groups,
  required Map<String, Set<String>> selections,
}) {
  var current = baseDiscountPrice ?? basePrice;
  var original = basePrice;
  var absoluteApplied = false;
  var additions = 0.0;
  final issues = <SelectionIssue>[];

  for (final group in groups) {
    final chosenIds = selections[group.id] ?? const <String>{};
    final chosen = group.options
        .where((o) => chosenIds.contains(o.id))
        .toList();

    if (chosen.any((o) => !o.isAvailable)) {
      issues.add(SelectionIssue(group.id, SelectionProblem.unavailable));
    }
    if (chosen.isEmpty && group.isRequired) {
      issues.add(SelectionIssue(group.id, SelectionProblem.required));
    } else if (chosen.length < group.effectiveMin) {
      issues.add(SelectionIssue(group.id, SelectionProblem.tooFew));
    }
    final max = group.effectiveMax;
    if (max != null && chosen.length > max) {
      issues.add(SelectionIssue(group.id, SelectionProblem.tooMany));
    }

    if (chosen.isEmpty) continue;
    if (group.mode == OptionPriceMode.absolute) {
      if (!absoluteApplied) {
        final option = chosen.first;
        current = option.discountPrice ?? option.price;
        original = option.price;
        absoluteApplied = true;
      }
    } else {
      for (final option in chosen) {
        additions += option.price;
      }
    }
  }

  return PriceBreakdown(
    unitPrice: _round2(current + additions),
    unitOriginalPrice: _round2(original + additions),
    issues: issues,
  );
}

/// Ids of the options marked as default, per group (for the initial selection).
Map<String, Set<String>> defaultSelections(
  List<PricedGroup> groups,
  Set<String> defaultOptionIds,
) {
  final result = <String, Set<String>>{};
  for (final group in groups) {
    final ids = group.options
        .where((o) => o.isAvailable && defaultOptionIds.contains(o.id))
        .map((o) => o.id)
        .toSet();
    if (ids.isNotEmpty) {
      result[group.id] = group.multiple || ids.length == 1 ? ids : {ids.first};
    }
  }
  return result;
}
