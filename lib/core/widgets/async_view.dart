import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/error_text.dart';
import 'feedback.dart';

/// Renders an [AsyncValue] with the app's standard loading and error screens.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Replaces the default spinner, e.g. with a [SkeletonList].
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (error, _) =>
          ErrorState(message: friendlyError(error), onRetry: onRetry),
    );
  }
}
