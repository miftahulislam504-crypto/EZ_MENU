import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/json_utils.dart';

/// Menu numbers shown on Home, from the `get_menu_stats` database function.
class MenuStats {
  const MenuStats({
    this.categories = 0,
    this.items = 0,
    this.visibleItems = 0,
    this.soldOutItems = 0,
    this.itemsWithoutImage = 0,
    this.branches = 0,
    this.tables = 0,
    this.qrScans = 0,
    this.trash = 0,
  });

  final int categories;
  final int items;
  final int visibleItems;
  final int soldOutItems;
  final int itemsWithoutImage;
  final int branches;
  final int tables;
  final int qrScans;
  final int trash;

  factory MenuStats.fromJson(Map<String, dynamic> j) => MenuStats(
    categories: j.integer('categories'),
    items: j.integer('items'),
    visibleItems: j.integer('visible_items'),
    soldOutItems: j.integer('sold_out_items'),
    itemsWithoutImage: j.integer('items_without_image'),
    branches: j.integer('branches'),
    tables: j.integer('tables'),
    qrScans: j.integer('qr_scans'),
    trash: j.integer('trash'),
  );

  bool get hasMenu => items > 0;
}

/// Key for [menuStatsProvider]: the business and, optionally, one branch.
typedef MenuStatsKey = ({String businessId, String? branchId});

final menuStatsProvider = FutureProvider.autoDispose
    .family<MenuStats, MenuStatsKey>((ref, key) async {
      final result = await ref
          .watch(supabaseClientProvider)
          .rpc(
            'get_menu_stats',
            params: {
              'p_business_id': key.businessId,
              'p_branch_id': key.branchId,
            },
          );
      if (result is Map) {
        return MenuStats.fromJson(Map<String, dynamic>.from(result));
      }
      return const MenuStats();
    });
