import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';

/// Placeholder shape of the menu while it loads: cover, name, chips and rows.
class MenuLoadingView extends StatelessWidget {
  const MenuLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading the menu',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const SkeletonBox(height: 150, radius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 68, height: 68, radius: 34),
                const SizedBox(height: 14),
                const SkeletonBox(width: 200, height: 24),
                const SizedBox(height: 10),
                const SkeletonBox(width: 140, height: 14),
                const SizedBox(height: 22),
                const SkeletonBox(height: 44, radius: 14),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    SkeletonBox(width: 56, height: 38, radius: 19),
                    SizedBox(width: 8),
                    SkeletonBox(width: 88, height: 38, radius: 19),
                    SizedBox(width: 8),
                    SkeletonBox(width: 76, height: 38, radius: 19),
                  ],
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < 3; i++) ...[
                  const SkeletonBox(height: 120, radius: 16),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu cannot be opened (wrong link, code switched off, unpublished...).
/// The language is not known yet, so the message is given in both.
class MenuProblemView extends StatelessWidget {
  const MenuProblemView({super.key, required this.problem, this.onRetry});

  final PublicMenuProblem problem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final english = problemText(problem, bangla: false);
    final bangla = problemText(problem, bangla: true);
    final retry = problem == PublicMenuProblem.unknown ? onRetry : null;
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  problem == PublicMenuProblem.unknown ? Icons.cloud_off_rounded : Icons.qr_code_scanner_rounded,
                  size: 30,
                  color: context.colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text(english.title, style: context.textStyles.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                english.message,
                style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.lg),
              Divider(color: palette.line, height: 1),
              const SizedBox(height: Sp.lg),
              Text(bangla.title, style: context.textStyles.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                bangla.message,
                style: context.textStyles.bodyMedium?.copyWith(color: palette.muted),
                textAlign: TextAlign.center,
              ),
              if (retry != null) ...[
                const SizedBox(height: Sp.xl),
                AppButton(label: 'Try again', onPressed: retry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
