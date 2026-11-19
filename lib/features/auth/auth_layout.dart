import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';

/// Frame shared by the sign in, sign up, verify and forgot password screens.
///
/// Wide screens get a green brand panel beside the form; phones get a single
/// calm column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Small line under the form, e.g. "New here? Create an account".
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final split = MediaQuery.sizeOf(context).width >= 900;
    final form = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.md),
                    child: TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                    ),
                  ),
                if (!split)
                  const Padding(
                    padding: EdgeInsets.only(bottom: Sp.xl),
                    child: BrandMark(size: 44),
                  ),
                Text(title, style: context.textStyles.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: Sp.sm),
                  Text(
                    subtitle!,
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: Sp.xl),
                child,
                if (footer != null) ...[
                  const SizedBox(height: Sp.xl),
                  Center(child: footer!),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: split
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: form),
              ],
            )
          : form,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.leaf,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const BrandMark(size: 44, inverted: true),
              const SizedBox(width: Sp.md),
              Text(
                'EZ Menu',
                style: context.textStyles.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your menu, always up to date.',
                style: context.textStyles.displaySmall?.copyWith(
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: Sp.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Change a price or mark a dish sold out, and every QR code '
                  'shows it straight away. No reprinting, no app for your '
                  'customers to install.',
                  style: context.textStyles.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Digital menu for restaurants, cafes and bakeries.',
            style: context.textStyles.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
