import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Heading at the top of a setup step.
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              subtitle!,
              style: context.textStyles.bodyLarge?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Back, skip and continue buttons at the bottom of a setup step.
class StepButtons extends StatelessWidget {
  const StepButtons({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.onBack,
    this.onSkip,
    this.skipLabel = 'Skip for now',
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sp.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: primaryLabel,
            expand: true,
            loading: loading,
            onPressed: onPrimary,
          ),
          if (onSkip != null || onBack != null) const SizedBox(height: Sp.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onBack != null)
                TextButton.icon(
                  onPressed: loading ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              if (onSkip != null)
                TextButton(
                  onPressed: loading ? null : onSkip,
                  child: Text(skipLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
