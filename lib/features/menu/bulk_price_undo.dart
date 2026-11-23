import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/price_adjust.dart';
import 'menu_models.dart';
import 'menu_repository.dart';

/// What a bulk price change replaced, kept in memory so it can be undone.
/// It lives only while the app is open.
class PriceSnapshot {
  const PriceSnapshot({
    required this.rows,
    required this.appliedAt,
    this.branchId,
    this.branchName,
    this.branchBefore = const {},
  });

  /// The changed dishes with their old and new prices.
  final List<PriceRow> rows;
  final DateTime appliedAt;

  /// Set when a branch price was changed instead of the dish price.
  final String? branchId;
  final String? branchName;

  /// The branch entry of each dish before the change (null: it had none).
  final Map<String, BranchItemSetting?> branchBefore;

  int get count => rows.length;
}

class PriceUndoNotifier extends Notifier<PriceSnapshot?> {
  @override
  PriceSnapshot? build() => null;

  void remember(PriceSnapshot snapshot) => state = snapshot;

  void forget() => state = null;
}

final priceUndoProvider = NotifierProvider<PriceUndoNotifier, PriceSnapshot?>(
  PriceUndoNotifier.new,
);

/// Writes the old prices back. Several dishes are written at a time to keep
/// large undos quick.
Future<void> undoPriceChange(MenuRepository repo, PriceSnapshot snapshot) async {
  const batch = 8;
  final rows = snapshot.rows;
  for (var start = 0; start < rows.length; start += batch) {
    final slice = rows.skip(start).take(batch);
    await Future.wait([
      for (final row in slice) _undoOne(repo, snapshot, row),
    ]);
  }
}

Future<void> _undoOne(MenuRepository repo, PriceSnapshot snapshot, PriceRow row) {
  final branchId = snapshot.branchId;
  if (branchId == null) {
    return repo.updateItem(row.itemId, {
      'price': row.oldPrice,
      'discount_price': row.oldDiscount,
    });
  }
  final before = snapshot.branchBefore[row.itemId];
  if (before == null) return repo.clearBranchSetting(branchId, row.itemId);
  return repo.saveBranchSetting(before);
}
