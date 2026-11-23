# EZ Menu

Digital menu and smart ordering platform for restaurants, cafes, bakeries and
food courts in Bangladesh. One Flutter codebase (Android, iOS, web) on Supabase
(Postgres, Auth, Storage, RPC, row level security).

This is the finished Phase 1 build: the digital menu, QR codes and tables, and
the customer menu. Ordering and payments come in Phase 2. Read `docs/STATUS.md`
first: it lists exactly what is built, what is not in Phase 1, and how the code
was checked (the Flutter UI has not been compiled yet).

## What you need

- Flutter 3.35 or newer (Dart 3.9)
- A Supabase project (the free tier is enough to start)
- Node 20 or newer, only for the database tests in `tools/db-test`

## Set up

1. Create the database. In the Supabase SQL editor, or with the Supabase CLI
   (`supabase db push`), run the three files in `supabase/migrations` in order.
2. In Supabase, open Authentication and then Email templates. The sign-up and
   password recovery emails must contain the one-time code, for example
   `Your code is {{ .Token }}`. The app verifies the code, not a link.
3. Copy `env.example.json` to `env.json` and fill it in:
   - `SUPABASE_URL` and `SUPABASE_ANON_KEY`: Project settings, API.
   - `PUBLIC_BASE_URL`: where the web app will be hosted, for example
     `https://menu.your-domain.com`. QR codes and share links use it.
   - `SUPPORT_EMAIL`: optional. The Help screen hides the contact row when empty.
4. Create the platform folders once: `flutter create . --platforms=android,ios,web`
   (keep this project's `web/index.html` and `web/manifest.json` if asked).
5. `flutter pub get`

## Run and build

```
flutter run -d chrome --dart-define-from-file=env.json
flutter build web --release --dart-define-from-file=env.json
```

Host the `build/web` folder anywhere that can rewrite every path to
`index.html` (`vercel.json` and `web/_redirects` are included), because the
customer menu lives at `/m/<restaurant>/<branch>` and `/q/<qr-token>`.

## Checks

```
flutter analyze
flutter test
cd tools/db-test && npm install && npm test
```

## Layout

```
supabase/migrations   schema, row level security, storage, functions
lib/core              theme, widget kit, session, Supabase access, pure logic
lib/app               router and app shell
lib/features          auth, onboarding, business, branches, menu, qr,
                      public_menu (customer menu), home, more, ...
test/                 unit tests for pure Dart logic (606 checks)
tools/db-test         runs the migrations in an in-memory Postgres
docs/ARCHITECTURE.md  conventions and database notes
docs/STATUS.md        what is built and what is not
```
