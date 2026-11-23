# EZ Menu - Phase 1 progress

Last updated: 2026-11-23. Phase 1 is complete and handed over as a zip.
Unit tests: 606 pass (pure Dart). The Flutter UI has never been compiled.

Phase 1 goal: a restaurant can replace the paper menu with a QR based digital menu
(profile, branches, categories, dishes, variants and add-ons, QR codes, customer
mobile menu, Bangla and English, sold-out control).

How to read the status:
- Done = written and passes the static checks available here (Dart analyzer against
  stand-ins for the Flutter packages, plus unit tests of the pure logic).
- The Flutter UI has not been compiled or run, because no Flutter SDK can be
  installed in the build environment. Expect small compile fixes on the first
  `flutter run`. See "Verification" at the end.

## Summary

| Area | Status |
| --- | --- |
| Database schema, RLS, storage, functions (3 migrations, 150 SQL checks) | Done |
| App shell, theme, widget kit, auth, onboarding, business profile, branches, branding, business hours, public link | Done |
| Shared menu layer (models, repository, catalog vocabularies, icons) | Done |
| Menu overview, category list, category edit, trash | Done |
| Dish list (search, filters, sort, bulk actions, reorder, quick add) | Done |
| Dish editor (basics, photos, pricing, details, variants and add-ons, schedules, branch overrides, live customer card preview) | Done |
| Availability screen (quick sold out, branch scope, restock list, category bulk actions, sold-out display setting) | Done |
| Bulk price update with preview and session undo | Done |
| CSV import and export (screen, preview, chunked import, template, error report, export) | Done |
| QR codes and tables (list, bulk add, detail, print sheet, table edit, PNG and PDF export) | Done |
| Customer mobile menu (public page, language toggle, search, filters, dish sheet with live price, hours and info, branch switcher) | Done |
| Customer preview inside the dashboard (phone frame, branch picker, link actions, unpublished banner) | Done |
| Unit tests for the new pure logic | Done (606 in total) |
| README, STATUS and ARCHITECTURE refresh, final zip | Done |

## Done in this round

- CSV screen: `lib/features/menu/import_export_screen.dart`, `import_export_state.dart`
  (33 tests), `widgets/import_widgets.dart`. Uses the existing `core/logic/menu_csv.dart`.
- QR and tables: `lib/features/qr/` with `qr_models`, `qr_logic` (48 tests),
  `qr_repository`, `qr_render` (cards drawn with dart:ui so Bangla shapes
  correctly), `qr_pdf`, `qr_export`, `qr_assets`, the four screens
  (`qr_tables_screen`, `qr_detail_screen`, `table_edit_screen`, `qr_print_screen`)
  and `widgets/`. `branch_qr_panel.dart` gained a PNG download.
- Customer menu: `lib/features/public_menu/` with `public_menu_models` (9 tests),
  `public_menu_logic` (69 tests), `public_menu_repository`, `public_menu_screen`
  and `widgets/` (header, item card, highlight rails, search and category bar,
  dish sheet, information and branch sheets, state views, `public_menu_view`).
  Sheets are laid over the menu itself (`menu_sheet.dart`) so they work inside the
  preview frame.
- Customer preview: `lib/features/menu/customer_preview_screen.dart` and
  `widgets/phone_frame.dart`. A separate provider (`publicMenuPreviewProvider`) is
  not kept alive, so every visit shows current data.
- `core/theme/menu_palette.dart`: added `open`, `closed` and `caution` status colours.
- Bug fixed: `hours_step.dart` (onboarding) was missing the `session_providers` import.
- Docs: README, `docs/STATUS.md` and `docs/ARCHITECTURE.md` refreshed (manifest now
  lists the QR routes; the customer menu API matches what was built).

## Next: Phase 2 (ordering)

Cart, checkout (dine-in, takeaway, delivery), live orders, payments, receipts and
notifications. The customer menu already has the dish sheet and the price logic
for variants and add-ons (`public_menu_logic.dart`, `core/logic/pricing.dart`); the
"Add to cart" action goes on that sheet.

## Verification

- The Dart analyzer was run over `lib` and `test` against stand-ins for the Flutter,
  Riverpod, Supabase and other packages, and the pure Dart tests were run without
  Flutter. These helper scripts live outside this project and are not shipped; they do
  not replace `flutter analyze` and `flutter test`.
- Before shipping: run `flutter pub get`, `flutter analyze`, `flutter test`, then try
  the flows on an Android device and in Chrome (scan a table QR code, switch language,
  open a dish with variants, print the PDF sheet, import the CSV template).
