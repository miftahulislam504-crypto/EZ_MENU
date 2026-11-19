import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/models.dart';
import '../core/session/session_providers.dart';
import '../core/supabase/supabase_providers.dart';
import '../core/widgets/widgets.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/branches/branch_edit_screen.dart';
import '../features/branches/branch_hours_screen.dart';
import '../features/branches/branch_list_screen.dart';
import '../features/business/account_screen.dart';
import '../features/business/branding_screen.dart';
import '../features/business/business_profile_screen.dart';
import '../features/business/public_link_screen.dart';
import '../features/help/help_screen.dart';
import '../features/help/legal_screen.dart';
import '../features/home/home_screen.dart';
import '../features/menu/availability_screen.dart';
import '../features/menu/bulk_price_screen.dart';
import '../features/menu/category_edit_screen.dart';
import '../features/menu/category_list_screen.dart';
import '../features/menu/customer_preview_screen.dart';
import '../features/menu/import_export_screen.dart';
import '../features/menu/item_edit_screen.dart';
import '../features/menu/item_list_screen.dart';
import '../features/menu/menu_overview_screen.dart';
import '../features/menu/trash_screen.dart';
import '../features/more/more_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/public_menu/public_menu_screen.dart';
import '../features/qr/qr_detail_screen.dart';
import '../features/qr/qr_print_screen.dart';
import '../features/qr/qr_tables_screen.dart';
import '../features/qr/table_edit_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import 'routes.dart';

/// Tells the router to run its redirect again when the person signs in or out
/// or their business data changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentSessionProvider, (_, __) => notifyListeners());
    ref.listen(businessesProvider, (_, __) => notifyListeners());
  }
}

/// Where a request should really go, or null to stay.
///
/// Order of checks:
///  1. The customer menu is public.
///  2. Forgot password is reachable signed in or out (the recovery code signs
///     the person in before the new password is saved).
///  3. Signed out: only the sign-in pages.
///  4. Signed in, business still loading: splash.
///  5. No business, or setup not finished: onboarding.
///  6. Otherwise the dashboard.
String? decideRedirect({
  required String path,
  required bool signedIn,
  required AsyncValue<List<Business>> businesses,
}) {
  if (AppRoutes.isPublic(path)) return null;
  if (path == AppRoutes.forgotPassword) return null;

  if (!signedIn) {
    return AppRoutes.isAuthPath(path) ? null : AppRoutes.login;
  }

  if (!businesses.hasValue) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final list = businesses.valueOrNull ?? const <Business>[];
  final business = list.isEmpty ? null : list.first;
  final needsSetup = business == null || !business.onboardingComplete;
  if (needsSetup) {
    return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }

  if (path == '/' ||
      path == AppRoutes.splash ||
      path == AppRoutes.onboarding ||
      AppRoutes.isAuthPath(path)) {
    return AppRoutes.home;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => decideRedirect(
      path: state.uri.path,
      signedIn: ref.read(currentSessionProvider) != null,
      businesses: ref.read(businessesProvider),
    ),
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Sign in
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.verify,
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),

      // First-run setup
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Customer menu: public, no sign in
      GoRoute(
        path: '/m/:business',
        builder: (context, state) =>
            PublicMenuScreen(businessSlug: state.pathParameters['business']),
      ),
      GoRoute(
        path: '/m/:business/:branch',
        builder: (context, state) => PublicMenuScreen(
          businessSlug: state.pathParameters['business'],
          branchSlug: state.pathParameters['branch'],
        ),
      ),
      GoRoute(
        path: '/q/:token',
        builder: (context, state) =>
            PublicMenuScreen(qrToken: state.pathParameters['token']),
      ),

      // Dashboard
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.menu,
                builder: (context, state) => const MenuOverviewScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoryListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => CategoryEditScreen(
                          parentId: state.uri.queryParameters['parent'],
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => CategoryEditScreen(
                          categoryId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'items',
                    builder: (context, state) => ItemListScreen(
                      categoryId: state.uri.queryParameters['category'],
                    ),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => ItemEditScreen(
                          categoryId: state.uri.queryParameters['category'],
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) =>
                            ItemEditScreen(itemId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'availability',
                    builder: (context, state) => const AvailabilityScreen(),
                  ),
                  GoRoute(
                    path: 'bulk-prices',
                    builder: (context, state) => const BulkPriceScreen(),
                  ),
                  GoRoute(
                    path: 'import-export',
                    builder: (context, state) => const ImportExportScreen(),
                  ),
                  GoRoute(
                    path: 'trash',
                    builder: (context, state) => const TrashScreen(),
                  ),
                  GoRoute(
                    path: 'preview',
                    builder: (context, state) => const CustomerPreviewScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.qr,
                builder: (context, state) => const QrTablesScreen(),
                routes: [
                  GoRoute(
                    path: 'code/:id',
                    builder: (context, state) =>
                        QrDetailScreen(qrId: state.pathParameters['id'] ?? ''),
                  ),
                  GoRoute(
                    path: 'print',
                    builder: (context, state) => const QrPrintScreen(),
                  ),
                  GoRoute(
                    path: 'tables/new',
                    builder: (context, state) => const TableEditScreen(),
                  ),
                  GoRoute(
                    path: 'tables/:id',
                    builder: (context, state) =>
                        TableEditScreen(tableId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const BusinessProfileScreen(),
                  ),
                  GoRoute(
                    path: 'branding',
                    builder: (context, state) => const BrandingScreen(),
                  ),
                  GoRoute(
                    path: 'public-link',
                    builder: (context, state) => const PublicLinkScreen(),
                  ),
                  GoRoute(
                    path: 'branches',
                    builder: (context, state) => const BranchListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const BranchEditScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => BranchEditScreen(
                          branchId: state.pathParameters['id'],
                        ),
                        routes: [
                          GoRoute(
                            path: 'hours',
                            builder: (context, state) => BranchHoursScreen(
                              branchId: state.pathParameters['id'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (context, state) => const AccountScreen(),
                  ),
                  GoRoute(
                    path: 'help',
                    builder: (context, state) => const HelpScreen(),
                  ),
                  GoRoute(
                    path: 'legal',
                    builder: (context, state) => const LegalScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _NotFoundScreen extends ConsumerWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.explore_off_outlined,
          title: 'Page not found',
          message:
              'This address does not lead anywhere. Go back to the dashboard.',
          actionLabel: 'Go to dashboard',
          onAction: () => GoRouter.of(context).go(AppRoutes.home),
        ),
      ),
    );
  }
}
