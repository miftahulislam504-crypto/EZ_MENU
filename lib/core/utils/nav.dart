import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Goes back when there is somewhere to go back to, otherwise to [fallback].
/// A screen opened from a link or after a refresh has no history to pop.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
