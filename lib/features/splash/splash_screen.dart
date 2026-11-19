import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_providers.dart';
import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';

/// Shown while the signed-in person's business loads. The router moves on by
/// itself when the data arrives; on a failure this offers a retry.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessesProvider);
    final failed = businesses.hasError && !businesses.hasValue;

    return Scaffold(
      body: SafeArea(
        child: failed
            ? ErrorState(
                title: 'Could not open EZ Menu',
                message: friendlyError(businesses.error),
                onRetry: () => ref.invalidate(businessesProvider),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: 64),
                    SizedBox(height: Sp.xl),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
