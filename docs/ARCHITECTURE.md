# EZ Menu architecture and conventions

This file describes how the app is organised and the rules every screen
follows. Read it before adding a screen. When this file and habit disagree,
follow this file. If it does not cover something, add the smallest thing inside
the feature folder you are working in.

## 1. What is being built (Phase 1: Core Digital Menu)

Source of truth: `EZ_Menu_Feature_Plan.md` in the Claude project (28 sections).
Phase 1 scope (Section 25): restaurant registration and profile, branch setup,
category and food item management, variants and add-ons, QR code generation,
customer mobile menu, menu language support, sold out and availability control.
Also in Phase 1: login, registration, forgot password, OTP verification (19.2),
guided onboarding (3, 19.2), business hours (3.3), branding (3.4), bulk menu
tools (4.5), QR and table screens (5.1, 19.6), home dashboard for menu stats (19.3).

Not in Phase 1 (do not build, do not fake): cart, checkout, orders, payments,
kitchen display, floors and floor plans, table status, staff and roles,
promotions, reports, customer accounts. Where the UI hints at them, say plainly
that they arrive in a later phase.

Project rules from the owner: NO emojis anywhere (code, copy, comments, docs).
English UI and UX copy. Premium, smooth look. Content inside the menu (food
names, descriptions) can be Bangla. No feature from the plan may be silently
dropped: if something in your scope is hard, build the simple honest version
and say so plainly in the UI.

## 2. Stack and layout

Flutter (Android, iOS, Web) with Supabase (Postgres, Auth, Storage, RPC, RLS).
State: flutter_riverpod 2.6 (no code generation). Navigation: go_router 14.
Fonts: Anek Bangla through google_fonts. Dart ^3.9.

```
lib/
  main.dart                      entry point (done)
  app/                           app.dart, router.dart, routes.dart (done)
  core/
    config/env.dart              build-time settings
    logic/                       pure Dart, no Flutter imports, unit tested
    session/                     Business, Branch, providers, BranchStatus
    supabase/                    client, friendlyError, ImageUploadService
    theme/                       AppColors, AppTheme, AppPalette, Sp, Rad
    utils/                       json_utils, public_links, launch, nav, validators
    widgets/                     shared widget kit (import widgets.dart)
  features/
    shell/ home/ more/ orders/ qr/ splash/ help/   
    auth/ onboarding/ business/ branches/          
    menu/                                          
    public_menu/                                   
```

Keep a feature's code inside its own folder. Core files are shared: you may ADD to core when you must (a new widget, a new helper) but
do not change existing signatures.

## 3. Conventions

Imports: relative only (`../../core/widgets/widgets.dart`). No `package:ez_menu`.
Use `import '../../core/widgets/widgets.dart';` for the widget kit and theme.

Theme access: `context.colors` (ColorScheme), `context.textStyles`,
`context.palette` (muted, line, success, warning, danger, accent and soft
variants), `context.isCompact`, `context.isWide`. Spacing `Sp.xs..xxl`, radii
`Rad.control/panel/sheet`. Never hard-code colors except the customer menu,
which themes itself from the business brand colour.

Structure of a form screen:

```dart
AppPage(
  title: 'Restaurant profile',
  body: Form(key: _form, child: Column(children: [FormSection(...), ...])),
  bottomBar: StickyActionBar(child: AppButton(label: 'Save changes', expand: true, loading: _saving, onPressed: _save)),
)
```

Lists and settings use `ListGroup` + `ListRow` (a single white panel with
hairline dividers), not a grid of identical cards. Use `StatusPill` for state,
`EmptyState` for empty lists (say what the screen is for and offer the action),
`ErrorState` through `AsyncValueView` for failures, `SkeletonList` for loading
lists, `confirmAction` for destructive steps, `showAppSheet` for pickers,
`showToast` and `runWithToast` for results.

Copy rules: sentence case ("Add item", not "Add Item" or "ADD ITEM"). A button
names the action ("Save changes", "Publish"). The toast repeats the verb
("Saved", "Published"). Errors say what happened and what to do, never
apologise, always go through `friendlyError(error)`. No "->" or arrow glyphs,
no strings joined with middle dots, no ALL CAPS labels, no exclamation marks.

Accessibility: every icon-only button has a `tooltip`; custom tappables have
`Semantics`; touch targets are at least 44 logical pixels; do not rely on
colour alone (pair colour with a label or icon).

Avoid deprecated or removed Flutter API (this code cannot be compiled where it
is written, so it has to be right the first time):
- colours: `color.withValues(alpha: x)`, never `withOpacity`; `color.r/g/b/a`
  (doubles), never `.red/.green/.blue/.alpha/.value`.
- `WidgetStateProperty` / `WidgetState`, never `MaterialStateProperty`.
- no `DropdownButtonFormField(value:)`, no `Radio` / `RadioListTile`
  (`groupValue` is deprecated): use `SelectField<T>` and `SegmentedChoice<T>`.
- `PopScope`, never `WillPopScope`. `MediaQuery.sizeOf(context)`, never
  `MediaQuery.of(context).size`. `Theme.of(context).colorScheme.surface`, never
  `.background`. `CardThemeData`, `DialogThemeData`. No `textScaleFactor`.
- `Switch` / `SwitchListTile`: use `SwitchRow` from the widget kit.
- `await` before using a `BuildContext` needs `if (!mounted) return;` (State)
  or `if (!context.mounted) return;` first.
- `const` constructors wherever possible; `final` locals; no `print`.

Data access: one repository class per feature that takes a `SupabaseClient`
(`ref.watch(supabaseClientProvider)`). UI never calls Supabase directly except
trivial reads. Table and column names must match the migrations EXACTLY (the
migrations in `supabase/migrations/` are the schema; read them, do not guess).
Writes go through PostgREST (`from(...).insert/update/delete`) or the RPCs in
section 5. After a write, invalidate the providers that show that data.
Convert empty text to null with `emptyToNull` (core/utils/json_utils.dart).
Read JSON with the `JsonMapReader` helpers (`j.str`, `j.integer`, `j.boolean`,
`j.numberOrNull`, `j.date`, `j.stringList`), never raw casts.

Pure logic that does not need Flutter (parsing, formatting, pricing, layout
math) goes in a file with NO `package:flutter` import so it can be unit tested
in this environment. Use what already exists in `core/logic/`: `slugify`,
`slugCandidates`, `isValidSlug`, `BdPhone`, `formatMoney`, `formatAmount`,
`parseAmount`, `toBanglaDigits`, `pickText`, `pickTextOr`, `dashboardName`,
`computeItemPrice` + `PricedGroup`, `CsvCodec`, hours helpers (`formatClock`,
`formatPeriod`, `summarizeWeek`, `weekOrderBangladesh`, `ClockTime`,
`parseClock`, `clockToDb`, `HoursPeriod`).

Navigation: `context.go(path)` between tabs, `context.push(path)` to drill in,
`popOrGo(context, fallbackPath)` (core/utils/nav.dart) to go back. Always use
the constants and builders in `lib/app/routes.dart`.

Bilingual content: every customer-visible text is a pair of columns `_en` and
`_bn`. Dashboard screens show `pickText`/`dashboardName` (English first). Forms
use `BilingualFields`. At least one of the two names is required.

## 4. Screen and class manifest

The router (`lib/app/router.dart`, already written) imports EXACTLY these files
and constructs EXACTLY these classes. Names, paths and constructor parameters
are fixed. Each is a widget (ConsumerWidget or ConsumerStatefulWidget) with a
`const` constructor and `super.key`.

| Path | File | Class and constructor |
|------|------|-----------------------|
| /login | features/auth/login_screen.dart | `LoginScreen()` |
| /signup | features/auth/signup_screen.dart | `SignUpScreen()` |
| /verify?email= | features/auth/verify_email_screen.dart | `VerifyEmailScreen({required String email})` |
| /forgot-password?email= | features/auth/forgot_password_screen.dart | `ForgotPasswordScreen({String? initialEmail})` |
| /onboarding | features/onboarding/onboarding_screen.dart | `OnboardingScreen()` |
| /more/profile | features/business/business_profile_screen.dart | `BusinessProfileScreen()` |
| /more/branding | features/business/branding_screen.dart | `BrandingScreen()` |
| /more/public-link | features/business/public_link_screen.dart | `PublicLinkScreen()` |
| /more/account | features/business/account_screen.dart | `AccountScreen()` |
| /more/branches | features/branches/branch_list_screen.dart | `BranchListScreen()` |
| /more/branches/new, /more/branches/:id | features/branches/branch_edit_screen.dart | `BranchEditScreen({String? branchId})` |
| /more/branches/:id/hours | features/branches/branch_hours_screen.dart | `BranchHoursScreen({required String branchId})` |
| /menu | features/menu/menu_overview_screen.dart | `MenuOverviewScreen()` |
| /menu/categories | features/menu/category_list_screen.dart | `CategoryListScreen()` |
| /menu/categories/new?parent=, /menu/categories/:id | features/menu/category_edit_screen.dart | `CategoryEditScreen({String? categoryId, String? parentId})` |
| /menu/items?category= | features/menu/item_list_screen.dart | `ItemListScreen({String? categoryId})` |
| /menu/items/new?category=, /menu/items/:id | features/menu/item_edit_screen.dart | `ItemEditScreen({String? itemId, String? categoryId})` |
| /menu/availability | features/menu/availability_screen.dart | `AvailabilityScreen()` |
| /menu/bulk-prices | features/menu/bulk_price_screen.dart | `BulkPriceScreen()` |
| /menu/import-export | features/menu/import_export_screen.dart | `ImportExportScreen()` |
| /menu/trash | features/menu/trash_screen.dart | `TrashScreen()` |
| /menu/preview | features/menu/customer_preview_screen.dart | `CustomerPreviewScreen()` |
| /m/:business, /m/:business/:branch, /q/:token | features/public_menu/public_menu_screen.dart | `PublicMenuScreen({String? businessSlug, String? branchSlug, String? qrToken})` |

Other screens already in the app: `SplashScreen`, `HomeScreen`, `OrdersScreen`,
`MoreScreen`, `HelpScreen`, `LegalScreen`, `AppShell`, `BranchSwitcher`.

Screens inside the dashboard sit in the shell (a bottom bar or side rail is
provided): build them as `AppPage` (it has its own app bar). The login,
sign-up, verify, forgot-password, onboarding and customer menu screens are
full-screen and must provide their own `Scaffold`.

Router behaviour you can rely on (see `decideRedirect` in router.dart):
signed-out people are sent to /login; a signed-in person with no business, or a
business whose `onboarding_completed_at` is null, is sent to /onboarding; once
setup is complete the auth screens and onboarding redirect to /home. The forgot
password screen is reachable both signed in and signed out, because the
recovery code signs the person in before the new password is saved: do the
verify and the password update in ONE repository call that does not touch
widget state in between, and only then navigate to `AppRoutes.home`.

### Cross-feature APIs (agreed signatures)

The customer menu module provides, in `features/public_menu/public_menu_view.dart`:

```dart
/// What to load. Value equality so it can key a provider family.
class PublicMenuRequest {
  const PublicMenuRequest({this.businessSlug, this.branchSlug, this.qrToken, this.preview = false});
  final String? businessSlug; final String? branchSlug; final String? qrToken; final bool preview;
  // operator == and hashCode over all four fields
}
/// The whole customer menu without a Scaffold route around it. Used by the
/// public route and, with embedded: true, inside the dashboard preview.
class PublicMenuView extends ConsumerStatefulWidget {
  const PublicMenuView({super.key, required this.request, this.embedded = false});
  final PublicMenuRequest request; final bool embedded;
}
```
With `embedded: true` the view must not use route navigation, must size itself
to the space it is given (a phone frame), must not scroll the page body, and
must not count a QR scan. `request.preview == true` passes `p_preview: true` to
`get_public_menu`, which only works for signed-in members and shows an
unpublished menu.

`features/qr/branch_qr_panel.dart` (used by onboarding step 5):

```dart
/// Shows the active branch QR code with copy and share actions. The
/// full QR module extends it with download and print.
class BranchQrPanel extends ConsumerWidget {
  const BranchQrPanel({super.key, required this.branch});
  final Branch branch;
}
```

After changing hours or a temporary closure:
`ref.invalidate(branchStatusProvider(branchId))` (core/session/branch_status.dart),
and after changing a business or branch: `ref.refreshBusiness()` or
`ref.refreshBranches()` (core/session/session_providers.dart).
All screens follow the dashboard's branch: `ref.watch(selectedBranchProvider)`
(a `Branch?`), the business is `ref.watch(currentBusinessProvider)` or
`currentBusinessIdProvider`.

Onboarding steps. `businesses.onboarding_step` records progress
so a person who closes the app resumes where they stopped:
0 nothing saved yet, 1 profile saved, 2 first branch saved, 3 hours saved (or
skipped), 4 first menu saved (or skipped), 5 QR step seen. Completing sets
`onboarding_step = 6` and `onboarding_completed_at = now()`; only then does the
router release the person to /home. The six visible steps are: Restaurant,
Branch, Opening hours, First menu, QR code, Done (plan 19.2). Steps 3 and 4 may
be skipped; 1 and 2 may not. Step 4 offers "Add my first category and item"
(a short form) and "Use a sample menu" (RPC `seed_sample_menu`).

## 5. Database facts you need

Read the three migrations. Highlights:

- Tables: profiles, businesses, business_members, branches, branch_hours,
  menu_categories, menu_items, item_schedules, item_option_groups,
  item_options, branch_category_settings, branch_item_settings,
  restaurant_tables, qr_codes. Row level security limits every dashboard
  query to the signed-in member's business; you do not add business filters for
  security, only for correctness (for example `.eq('business_id', id)`).
- Anonymous visitors cannot read tables. The customer menu loads ONLY through
  `rpc('get_public_menu', params: {p_business_slug, p_branch_slug, p_qr_token,
  p_preview})`, which returns a jsonb document (see the SQL header and body).
- Soft delete: `menu_categories` and `menu_items` have `deleted_at`. Normal
  lists filter `deleted_at is null` (`.isFilter('deleted_at', null)`).
- RPCs (all callable by signed-in users): `is_business_slug_available(p_slug,
  p_exclude_business)`, `is_branch_slug_available(p_business_id, p_slug,
  p_exclude_branch)`, `reorder_menu_categories(p_ids uuid[])`,
  `reorder_menu_items(p_ids uuid[])`, `bulk_adjust_prices(p_item_ids, p_mode,
  p_value, p_target, p_round_whole, p_branch_id)`, `copy_option_groups(p_from_item,
  p_to_item)`, `duplicate_menu_item(p_item_id)`, `duplicate_menu_category(
  p_category_id, p_include_items)`, `soft_delete_category(p_category_id)`,
  `restore_category(p_category_id)`, `restore_menu_item(p_item_id)`,
  `import_menu_items(p_business_id, p_rows jsonb, p_update_existing)`,
  `create_qr_code(p_branch_id, p_kind, p_table_id, p_label)`,
  `regenerate_qr_code(p_qr_id)`, `get_menu_stats(p_business_id, p_branch_id)`,
  `seed_sample_menu(p_business_id)`, `branch_status(p_branch_id, p_at)`.
- Item soft delete is an update of `deleted_at` (`now()` or null to restore via
  `restore_menu_item`). Category delete must use `soft_delete_category`.
- A new branch automatically gets a branch QR code (trigger). A new table
  automatically gets a table QR code (trigger).
- Storage buckets `brand-assets` (logo, cover) and `menu-images` (categories,
  items). Upload with `ImagePickerField`, `MultiImageField` or
  `ref.read(imageUploadServiceProvider).pickAndUpload(...)`; paths start with
  the business id automatically.

## 6. Quality bar and verification

Checks that ship with the project:

- `tools/db-test`: runs the three migrations in an in-memory Postgres and
  checks schema, row level security, storage policies and every RPC
  (`cd tools/db-test && npm install && npm test`).
- `test/`: unit tests for pure Dart logic (slugs, Bangladesh phone numbers,
  money, localized text, item pricing, CSV, opening hours, hours editing).
  Run with `flutter test`.

Pure logic that does not need Flutter lives in files with no `package:flutter`
import so it can be tested without a device. Every column or RPC parameter a
screen references must exist in the migrations; check the SQL before adding
one. Run `flutter analyze` and `flutter test` before every release.
