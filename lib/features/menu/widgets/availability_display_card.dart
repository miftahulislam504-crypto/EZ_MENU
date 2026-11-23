import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_repository.dart';

/// "How sold out dishes appear to customers": the business setting, saved the
/// moment it is changed. A branch can override it in its own settings, which
/// is pointed out when the viewed branch does.
class SoldOutDisplayCard extends ConsumerStatefulWidget {
  const SoldOutDisplayCard({super.key, required this.business, this.branch});

  final Business business;

  /// The branch being viewed, to mention its own override.
  final Branch? branch;

  @override
  ConsumerState<SoldOutDisplayCard> createState() => _SoldOutDisplayCardState();
}

class _SoldOutDisplayCardState extends ConsumerState<SoldOutDisplayCard> {
  /// Shown while a save is in flight so the control moves at once.
  String? _pending;
  bool _saving = false;

  Future<void> _change(String value) async {
    if (_saving || value == widget.business.soldOutDisplay) return;
    setState(() {
      _pending = value;
      _saving = true;
    });
    final ok = await runWithToast(
      context,
      () async {
        await ref.read(businessRepositoryProvider).update(
          widget.business.id,
          {'sold_out_display': value},
        );
        ref.refreshBusiness();
      },
      onError: friendlyError,
      successMessage: value == 'hide'
          ? 'Sold out dishes are now hidden from customers'
          : 'Sold out dishes now show as sold out',
    );
    if (!mounted) return;
    // On success the refreshed business arrives with the same value; on
    // failure the control returns to the stored one.
    setState(() {
      _saving = false;
      if (!ok) _pending = null;
    });
  }

  @override
  void didUpdateWidget(SoldOutDisplayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending != null &&
        !_saving &&
        widget.business.soldOutDisplay == _pending) {
      _pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = _pending ?? widget.business.soldOutDisplay;
    final hides = current == 'hide';
    final branchOverride = widget.branch?.soldOutDisplay;

    return FormSection(
      title: 'How sold out dishes appear to customers',
      subtitle: 'Applies to the whole menu unless a branch sets its own.',
      children: [
        SegmentedChoice<String>(
          value: hides ? 'hide' : 'show',
          onChanged: _change,
          options: const [
            ChoiceOption(
              value: 'show',
              label: 'Show as sold out',
              icon: Icons.visibility_outlined,
            ),
            ChoiceOption(
              value: 'hide',
              label: 'Hide',
              icon: Icons.visibility_off_outlined,
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(
                  hides
                      ? 'The dish disappears from the menu while it is sold out.'
                      : 'The dish stays on the menu, greyed out with a Sold out '
                            'badge, and cannot be ordered.',
                  key: ValueKey(hides),
                  style: context.textStyles.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
              if (branchOverride != null && widget.branch != null) ...[
                const SizedBox(height: Sp.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: palette.warning),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Text(
                        '${widget.branch!.name} uses its own setting: '
                        '${branchOverride == 'hide' ? 'Hide' : 'Show as sold out'}.',
                        style: context.textStyles.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push(AppRoutes.branchEdit(widget.branch!.id)),
                      child: const Text('Branch settings'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
