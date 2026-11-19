import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/utils/public_links.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_repository.dart';
import '../onboarding_widgets.dart';

/// Step 6: setup is finished. Marks onboarding complete and opens the app.
class DoneStep extends ConsumerStatefulWidget {
  const DoneStep({
    super.key,
    required this.business,
    required this.branch,
    required this.onFinished,
  });

  final Business business;
  final Branch? branch;
  final VoidCallback onFinished;

  @override
  ConsumerState<DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends ConsumerState<DoneStep> {
  bool _saving = false;

  String get _link {
    final branch = widget.branch;
    return branch == null
        ? PublicLinks.businessMenu(widget.business.slug)
        : PublicLinks.branchMenu(widget.business.slug, branch.slug);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final repository = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      await repository.completeOnboarding(widget.business.id);
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: IconBadge(
            Icons.check_rounded,
            color: context.palette.success,
            background: context.palette.successSoft,
            size: 72,
          ),
        ),
        const SizedBox(height: Sp.xl),
        Text(
          '${widget.business.name} is ready',
          textAlign: TextAlign.center,
          style: context.textStyles.headlineSmall,
        ),
        const SizedBox(height: Sp.sm),
        Text(
          'Your digital menu has its own link. Share it with customers or '
          'put it on a QR code.',
          textAlign: TextAlign.center,
          style: context.textStyles.bodyLarge?.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: Sp.xl),
        ListGroup(
          children: [
            ListRow(
              title: 'Menu link',
              subtitle: link,
              leading: const IconBadge(Icons.link_rounded),
            ),
          ],
        ),
        const SizedBox(height: Sp.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Copy link',
                icon: Icons.copy_rounded,
                kind: AppButtonKind.secondary,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) showToast(context, 'Link copied');
                },
              ),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: AppButton(
                label: 'Share',
                icon: Icons.ios_share_rounded,
                kind: AppButtonKind.secondary,
                onPressed: () => Share.share(link),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.xl),
        StepButtons(
          primaryLabel: 'Go to dashboard',
          loading: _saving,
          onPrimary: _finish,
        ),
      ],
    );
  }
}
