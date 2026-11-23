# Phase 1 status

Phase 1 is the core digital menu (plan section 25). This file is an honest
inventory. Nothing from the plan has been dropped; what belongs to later phases
is listed at the end.

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

App: account and setup
- Sign up with email code, sign in, forgot password with code, sign out
- Guided onboarding in six steps with resume (restaurant, branch, hours,
  first dish or sample menu, QR code, done)
- Restaurant profile, branding (logo, cover, colour, theme, layout), public
  link and publish switch, account and password
- Branches: list, add, edit, reorder, delete; weekly hours with several periods
  and overnight service; special days; temporary closure
- Home (branch status, menu numbers, shortcuts, setup checklist, share link)
- More (settings, menu tools, account, coming later list), Help, Terms and
  privacy, Orders screen that says plainly it arrives in Phase 2
- Responsive shell: bottom bar on phones, side rail on wide screens

App: menu management
- Menu overview, categories (tree, icons, reorder, trash with undo), dish list
  (search, filters, sort, bulk actions, reorder, quick add), dish editor
  (bilingual basics, photos, pricing, details, variants and add-ons, schedules,
  per-branch overrides, live customer card preview)
- Availability (quick sold out with auto return time, branch scope, category
  bulk actions, sold-out display setting), bulk price update (preview, apply,
  undo), trash
- CSV import and export: file picker, column check, preview table with create,
  update and skip counts, import in chunks with progress, template and error
  report download, export of the whole menu or of the selected branch's prices and
  availability (`import_export_screen.dart`)

App: QR codes and tables (`lib/features/qr`)
- Table list with zones and capacity, add one table or many at once (for
  example Table 1 to Table 20), edit, switch on and off, delete
- Every table gets its QR code by database trigger; branch, takeaway and
  table codes can be created, replaced (the old code stops working at once),
  switched off and back on
- Code detail with a card preview, link copy and share, scan count, PNG
  download
- Print sheet: choose branch, takeaway or table codes, 1, 2, 4 or 6 cards per
  A4 page, PDF export, print and share. Cards are drawn as images first so
  Bangla text shapes correctly, then placed in the PDF
- Branch QR panel (onboarding and public link) with copy, share and download

App: customer menu (`lib/features/public_menu`)
- The page behind `/m/<restaurant>`, `/m/<restaurant>/<branch>` and
  `/q/<token>`; no sign in. A table or takeaway code shows "Table 5" or
  "Takeaway" on the menu
- Cover, logo, name, branch and area, open or closed status with closing or
  opening time, temporary closure message, welcome note
- English and Bangla toggle (remembered on the device), search that finds
  Bangla and English digits alike, category chips, dietary filters (vegetarian,
  vegan, halal, spicy, gluten free, dairy free), "Available now" switch
- Featured, popular and new rails, list or grid layout by the restaurant's
  setting, three themes and the brand colour
- Dish sheet: photo gallery, price with discount, preparation time, spice
  level, calories, labels, description, ingredients, allergens and note,
  nutrition, when a scheduled dish is served, sold-out state, variants and
  add-ons with the price updating as choices are made and the rules for each
  group shown
- Information sheet: today's hours highlighted, weekly hours, special days,
  address, call, WhatsApp, email, map, website and social links, about us,
  allergen notice, refunds and terms
- Branch switcher when the restaurant has several branches
- Clear screens for a wrong link, a switched off or replaced code, an
  inactive table or branch, and an unpublished menu, in English and Bangla
- Customer preview in the dashboard (`/menu/preview`): the same customer menu
  inside a phone frame, branch picker, link copy, open and share, and a banner
  when the menu is not published (the owner can still see it)

## Not in Phase 1

The customer menu is view only in this phase. Choosing a dish shows its price
for the chosen options but there is no cart, checkout, order or payment yet.

Phase 2 (ordering): cart, checkout with dine-in, takeaway and delivery,
live orders, payments, receipts, notifications.

Later phases: kitchen display, floors and table status, staff and roles,
promotions, reservations, customers, reports. The More screen lists them
honestly with their phase.

## How this was checked, and what that does not prove

The environment this was written in has no Flutter SDK and cannot download one.
- Database: all migrations run against an in-memory Postgres; 150 checks pass.
- Pure Dart logic: 606 unit tests pass, run without Flutter (447 from earlier
  work plus QR 48, CSV screen state 33, public menu models 9 and logic 69).
- Every Dart file passes the Dart analyzer run against stand-ins for the
  Flutter, Riverpod, Supabase and other packages. That finds missing imports,
  wrong constructor arguments and missing members of project classes.
- Every column and function the new screens use was checked against the
  migrations, including each key the customer menu reads from
  `get_public_menu`.
- The Flutter UI has never been compiled or run, so layout, animation and
  gesture behaviour are untested. Expect to fix a few compile errors and
  visual details on the first `flutter analyze` and run. Package versions in
  `pubspec.yaml` were chosen from memory and not verified against pub.dev.

First things to try on a device: scan a table QR code on a phone, switch
language, open a dish with variants, open the PDF print sheet, and import the
CSV template.
