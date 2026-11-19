import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shared Supabase client. Override in tests with a fake.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Emits on sign in, sign out, token refresh and password recovery.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The signed-in session, or null. Rebuilds on every auth event.
final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Only changes when a different person signs in or out, so data providers do
/// not reload on every token refresh.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider.select((s) => s?.user.id)),
);
