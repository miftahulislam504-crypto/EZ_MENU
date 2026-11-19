import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/hours.dart';
import '../supabase/supabase_providers.dart';
import '../utils/json_utils.dart';

/// Whether a branch is open right now, worked out by the database in the
/// business time zone (single source of truth, also used by the customer menu).
class BranchStatus {
  const BranchStatus({
    required this.status,
    required this.isOpen,
    this.opensAt,
    this.closesAt,
    this.until,
  });

  /// 'open', 'closed' or 'temporarily_closed'.
  final String status;
  final bool isOpen;

  /// `HH:mm:ss` of today's next opening, when closed.
  final String? opensAt;

  /// `HH:mm:ss` of today's closing, when open.
  final String? closesAt;

  /// End of a temporary closure, when it has one.
  final DateTime? until;

  bool get isTemporarilyClosed => status == 'temporarily_closed';

  factory BranchStatus.fromJson(Map<String, dynamic> j) {
    final status = j.str('status') ?? 'closed';
    return BranchStatus(
      status: status,
      isOpen: j.boolean('is_open'),
      opensAt: j.str('opens_at'),
      closesAt: j.str('closes_at'),
      until: j.date('until'),
    );
  }

  /// One line for the dashboard, e.g. "Open now, closes at 10:00 PM".
  String get summary {
    if (isTemporarilyClosed) return 'Temporarily closed';
    if (isOpen) {
      return closesAt == null
          ? 'Open now'
          : 'Open now, closes at ${formatClock(closesAt)}';
    }
    return opensAt == null
        ? 'Closed'
        : 'Closed, opens at ${formatClock(opensAt)}';
  }
}

/// Live status of one branch. Invalidate after changing hours or closures.
final branchStatusProvider = FutureProvider.autoDispose
    .family<BranchStatus, String>((ref, branchId) async {
      final result = await ref
          .watch(supabaseClientProvider)
          .rpc('branch_status', params: {'p_branch_id': branchId});
      if (result is Map) {
        return BranchStatus.fromJson(Map<String, dynamic>.from(result));
      }
      return const BranchStatus(status: 'closed', isOpen: false);
    });
