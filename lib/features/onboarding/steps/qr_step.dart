import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/models.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_repository.dart';
import '../../qr/branch_qr_panel.dart';
import '../onboarding_widgets.dart';

/// Step 5: the branch QR code, ready to print or share.
class QrStep extends ConsumerStatefulWidget {
  const QrStep({
    super.key,
    required this.business,
    required this.branch,
    required this.onNext,
    required this.onBack,
  });

  final Business business;
  final Branch branch;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  ConsumerState<QrStep> createState() => _QrStepState();
}

class _QrStepState extends ConsumerState<QrStep> {
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    final repository = ref.read(businessRepositoryProvider);
    final ok = await runWithToast(context, () async {
      await repository.advanceOnboarding(widget.business.id, 5);
      ref.refreshBusiness();
    }, onError: friendlyError);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeading(
          title: 'Your menu QR code',
          subtitle:
              'Customers scan this to open your menu. Print it for tables and '
              'the counter, or share the link. Table QR codes and a printable '
              'poster are available later from the QR and tables tab.',
        ),
        BranchQrPanel(branch: widget.branch),
        const SizedBox(height: Sp.lg),
        StepButtons(
          primaryLabel: 'Continue',
          loading: _saving,
          onPrimary: _continue,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}
