# Phase 1 status

Phase 1 is the core digital menu (plan section 25). This file is an honest
inventory. Nothing from the plan has been dropped; unfinished parts are listed
as unfinished and show a "Not built yet" screen in the app instead of fake data.

## Finished

Database (3 migrations, 150 automated checks pass)
- Businesses, members, branches, opening hours, special days, temporary closure
- Categories, items, bilingual names and descriptions, variants and add-ons
  (option groups with additional or absolute pricing), schedules, per-branch
  availability and price overrides, sold-out with automatic return time
- Tables and QR codes (branch, table, takeaway), scan counting, regenerate
- Soft delete and restore, duplicate, reorder, bulk price update, CSV import
- Public menu function for anonymous customers, menu stats, sample menu
- Row level security for every table, storage policies for images

App
- Sign up with email code, sign in, forgot password with code, sign out
- Guided onboarding in six steps with resume (restaurant, branch, hours,
  first dish or sample menu, QR code, done)
- Restaurant profile, branding (logo, cover, colour), public link and publish
  switch, account and password
- Branches: list, add, edit, reorder, delete; weekly hours with several periods
  and overnight service; special days; temporary closure
- Home (branch status, menu numbers, shortcuts, setup checklist, share link)
- More (settings, menu tools, account, coming later list), Help, Terms and
  privacy, Orders screen that says plainly it arrives in Phase 2
- Responsive shell: bottom bar on phones, side rail on wide screens
- Branch QR code with copy and share

## Not built yet (placeholder screens)

These routes exist and the database behind them is finished and tested.
- Menu management: menu overview, categories, items (photos, labels, allergens,
  nutrition, variants and add-ons, schedules, branch overrides), availability,
  bulk price update, CSV import and export, trash, customer preview
- QR and tables screen: table list and editor, QR detail with PNG and PDF
  download, print sheet, regenerate and deactivate
- Customer mobile menu (the page behind `/m/...` and `/q/...`) with language
  toggle, search, item sheet with live price, hours and info

## Later phases (not Phase 1)

Cart, checkout, orders, payments, kitchen display, floors and table status,
staff and roles, promotions, reservations, customers, reports. The More screen
lists them honestly with their phase.

## How this was checked, and what that does not prove

The environment this was written in has no Flutter SDK and cannot download one.
- Database: all migrations run against an in-memory Postgres; 150 checks pass.
- Pure Dart logic: 72 unit tests pass, run without Flutter.
- Every Dart file is parsed, and a project analysis finds missing imports,
  wrong constructor arguments and missing members of project classes.
- The Flutter UI code has never been compiled or run. Expect to fix a few
  compile errors and visual details on the first `flutter analyze` and run.
  Package versions in `pubspec.yaml` were chosen from memory and not verified
  against pub.dev.
