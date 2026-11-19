/// Every path in the app. Screens navigate with these constants so a path is
/// never typed twice.
class AppRoutes {
  const AppRoutes._();

  // Start and auth
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verify = '/verify';
  static const String forgotPassword = '/forgot-password';

  // First-run setup
  static const String onboarding = '/onboarding';

  // Dashboard tabs
  static const String home = '/home';
  static const String orders = '/orders';
  static const String menu = '/menu';
  static const String qr = '/qr';
  static const String more = '/more';

  // Menu
  static const String categories = '/menu/categories';
  static const String categoryNew = '/menu/categories/new';
  static String categoryEdit(String id) => '/menu/categories/$id';
  static const String items = '/menu/items';
  static const String itemNew = '/menu/items/new';
  static String itemEdit(String id) => '/menu/items/$id';
  static const String availability = '/menu/availability';
  static const String bulkPrices = '/menu/bulk-prices';
  static const String importExport = '/menu/import-export';
  static const String trash = '/menu/trash';
  static const String preview = '/menu/preview';

  // QR and tables
  static String qrDetail(String id) => '/qr/code/$id';
  static const String qrPrint = '/qr/print';
  static const String tableNew = '/qr/tables/new';
  static String tableEdit(String id) => '/qr/tables/$id';

  // More
  static const String profile = '/more/profile';
  static const String branding = '/more/branding';
  static const String publicLink = '/more/public-link';
  static const String branches = '/more/branches';
  static const String branchNew = '/more/branches/new';
  static String branchEdit(String id) => '/more/branches/$id';
  static String branchHours(String id) => '/more/branches/$id/hours';
  static const String account = '/more/account';
  static const String help = '/more/help';
  static const String legal = '/more/legal';

  // Customer menu (public, no sign in)
  static const String publicMenuPrefix = '/m';
  static const String publicQrPrefix = '/q';

  static String publicMenu(String businessSlug, [String? branchSlug]) =>
      branchSlug == null ? '/m/$businessSlug' : '/m/$businessSlug/$branchSlug';

  static String publicQr(String token) => '/q/$token';

  /// Paths a signed-out person may open.
  static bool isPublic(String path) =>
      path.startsWith('$publicMenuPrefix/') ||
      path.startsWith('$publicQrPrefix/');

  static bool isAuthPath(String path) =>
      path == login ||
      path == signup ||
      path == verify ||
      path == forgotPassword;
}
