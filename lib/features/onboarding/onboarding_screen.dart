import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/session/models.dart';
import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_repository.dart';
import 'steps/branch_step.dart';
import 'steps/done_step.dart';
import 'steps/hours_step.dart';
import 'steps/menu_step.dart';
import 'steps/profile_step.dart';
import 'steps/qr_step.dart';

const List<String> _stepTitles = [
  'Restaurant',
  'Branch',
  'Hours',
  'First dish',
  'QR code',
  'Done',
];

/// Guided setup shown to a new owner until the first menu is ready.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Zero based index into [_stepTitles]; null until resumed from saved state.
  int? _step;

  int _resumeIndex(Business? business) {
    if (business == null) return 0;
    // onboarding_step is the last finished step, so continue with the next.
    return business.onboardingStep.clamp(0, _stepTitles.length - 1);
  }

  void _go(int index) {
    setState(() => _step = index.clamp(0, _stepTitles.length - 1));
  }

  Future<void> _signOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out',
      message:
          'Your setup progress is saved. You can sign in later and '
          'continue where you stopped.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final businessValue = ref.watch(currentBusinessProvider);
    final branches = ref.watch(branchesProvider);

    return businessValue.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        body: ErrorState(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(businessesProvider),
        ),
      ),
      data: (business) {
        // Fixed on first load so creating the restaurant does not skip ahead.
        final step = _step ??= _resumeIndex(business);
        final branch = (branches.valueOrNull ?? const <Branch>[]).isEmpty
            ? null
            : branches.valueOrNull!.first;

        // A step that needs the restaurant or branch falls back when the
        // saved progress is ahead of the data (for example, a deleted branch).
        var effective = step;
        if (business == null) effective = 0;
        if (business != null && branch == null && effective > 1) {
          effective = branches.isLoading ? effective : 1;
        }

        return Scaffold(
          backgroundColor: context.palette.paper,
          appBar: AppBar(
            backgroundColor: context.palette.paper,
            automaticallyImplyLeading: false,
            title: const BrandMark(size: 28),
            actions: [
              TextButton(onPressed: _signOut, child: const Text('Sign out')),
              const SizedBox(width: Sp.sm),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.lg,
                    Sp.sm,
                    Sp.lg,
                    Sp.xxl,
                  ),
                  children: [
                    _Progress(index: effective),
                    const SizedBox(height: Sp.xl),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(effective),
                        child: _stepBody(effective, business, branch),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepBody(int index, Business? business, Branch? branch) {
    switch (index) {
      case 0:
        return ProfileStep(business: business, onNext: () => _go(1));
      case 1:
        return BranchStep(
          business: business!,
          existing: branch,
          onNext: () => _go(2),
          onBack: () => _go(0),
        );
      case 2:
        return HoursStep(
          business: business!,
          branch: branch!,
          onNext: () => _go(3),
          onBack: () => _go(1),
        );
      case 3:
        return MenuStep(
          business: business!,
          onNext: () => _go(4),
          onBack: () => _go(2),
        );
      case 4:
        return QrStep(
          business: business!,
          branch: branch!,
          onNext: () => _go(5),
          onBack: () => _go(3),
        );
      default:
        return DoneStep(
          business: business!,
          branch: branch,
          onFinished: () => context.go(AppRoutes.home),
        );
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stepTitles.length; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= index ? colors.primary : context.palette.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < _stepTitles.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: Sp.sm),
        Text(
          'Step ${index + 1} of ${_stepTitles.length}: ${_stepTitles[index]}',
          style: context.textStyles.labelLarge?.copyWith(
            color: context.palette.muted,
          ),
        ),
      ],
    );
  }
}
