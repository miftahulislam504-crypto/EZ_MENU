import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shown instead of the app when the Supabase keys were not provided at build
/// time, so a missing setting is obvious rather than a blank screen.
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key, this.details});

  final String? details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EZ Menu',
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sp.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Builder(
                  builder: (context) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.settings_suggest_outlined,
                          size: 40,
                          color: context.colors.primary,
                        ),
                        const SizedBox(height: Sp.lg),
                        Text(
                          'EZ Menu is not connected yet',
                          style: context.textStyles.headlineSmall,
                        ),
                        const SizedBox(height: Sp.sm),
                        Text(
                          'The Supabase project address and key are missing. '
                          'Create an env.json file from env.example.json and '
                          'run the app with:',
                          style: context.textStyles.bodyLarge,
                        ),
                        const SizedBox(height: Sp.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Sp.md),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(Rad.control),
                            border: Border.all(color: context.palette.line),
                          ),
                          child: const SelectableText(
                            'flutter run --dart-define-from-file=env.json',
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        if (details != null) ...[
                          const SizedBox(height: Sp.lg),
                          Text(
                            details!,
                            style: context.textStyles.bodySmall?.copyWith(
                              color: context.palette.muted,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
