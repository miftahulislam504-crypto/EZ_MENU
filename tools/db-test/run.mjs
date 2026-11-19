// Runs every Supabase migration against an in-memory Postgres (PGlite) and
// verifies schema constraints, Row Level Security and the RPC functions.
//
//   cd tools/db-test && npm install && npm test
//
// Supabase itself is emulated only where the migrations touch it: the auth and
// storage schemas, the anon / authenticated roles and Supabase's default grants.

import { PGlite } from '@electric-sql/pglite';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = process.env.MIGRATIONS_DIR ?? join(here, '..', '..', 'supabase', 'migrations');

const db = new PGlite();
let passed = 0;
let failed = 0;
const failures = [];

function ok(cond, name) {
  if (cond) {
    passed++;
  } else {
    failed++;
    failures.push(name);
    console.log(`  FAIL  ${name}`);
  }
}
function eq(actual, expected, name) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a === e) {
    passed++;
  } else {
    failed++;
    failures.push(name);
    console.log(`  FAIL  ${name}\n        expected ${e}\n        actual   ${a}`);
  }
}
async function throws(promiseFactory, name, messagePart) {
  try {
    await promiseFactory();
    failed++;
    failures.push(name);
    console.log(`  FAIL  ${name} (expected an error, none was raised)`);
  } catch (e) {
    if (messagePart && !String(e.message).toLowerCase().includes(messagePart.toLowerCase())) {
      failed++;
      failures.push(name);
      console.log(`  FAIL  ${name} (error was: ${e.message})`);
    } else {
      passed++;
    }
  }
}
function section(title) {
  console.log(`\n${title}`);
}

const q = async (sql, params = []) => (await db.query(sql, params)).rows;
const one = async (sql, params = []) => (await q(sql, params))[0];
const val = async (sql, params = []) => {
  const row = await one(sql, params);
  return row ? Object.values(row)[0] : undefined;
};

async function asUser(uid, fn) {
  await db.exec('reset role');
  await db.exec('set role authenticated');
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [uid]);
  try {
    return await fn();
  } finally {
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claim.sub', '', false)`);
  }
}
async function asAnon(fn) {
  await db.exec('reset role');
  await db.exec('set role anon');
  await db.query(`select set_config('request.jwt.claim.sub', '', false)`);
  try {
    return await fn();
  } finally {
    await db.exec('reset role');
  }
}

try {
// ---------------------------------------------------------------------------
// Supabase emulation
// ---------------------------------------------------------------------------
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;

  create schema auth;
  create table auth.users (
    id uuid primary key default gen_random_uuid(),
    email text,
    raw_user_meta_data jsonb not null default '{}'::jsonb
  );
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;

  create schema storage;
  create table storage.buckets (
    id text primary key, name text, public boolean default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets(id),
    name text,
    owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language plpgsql immutable as $$
  declare _parts text[];
  begin
    select string_to_array(name, '/') into _parts;
    return _parts[1:array_length(_parts, 1) - 1];
  end $$;

  grant usage on schema public, auth, storage to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant execute on function storage.foldername(text) to anon, authenticated, service_role;
  grant all on all tables in schema storage to anon, authenticated, service_role;

  -- Supabase's default privileges for objects created in public.
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
`);

// ---------------------------------------------------------------------------
section('Migrations');
const files = readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
for (const f of files) {
  try {
    await db.exec(readFileSync(join(migrationsDir, f), 'utf8'));
    ok(true, `applied ${f}`);
    console.log(`  ok    ${f}`);
  } catch (e) {
    ok(false, `apply ${f}: ${e.message}`);
    console.log(`  FAIL  ${f}: ${e.message}`);
    console.log(`\n${passed} passed, ${failed} failed`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
section('Users, businesses and ownership');
const A = (await one(`insert into auth.users (email, raw_user_meta_data)
  values ('a@example.com', '{"full_name":"Rahim Uddin","phone":"01712345678"}') returning id`)).id;
const B = (await one(`insert into auth.users (email) values ('b@example.com') returning id`)).id;

eq(await val(`select full_name from public.profiles where id = $1`, [A]), 'Rahim Uddin', 'profile created from signup metadata');
eq(await val(`select phone from public.profiles where id = $1`, [A]), '01712345678', 'profile phone stored');

const bizA = await asUser(A, async () =>
  (await one(`insert into public.businesses (owner_id, slug, name_en, name_bn, timezone)
              values ($1, 'spice-garden', 'Spice Garden', 'স্পাইস গার্ডেন', 'Asia/Dhaka') returning id`, [A])).id);
ok(!!bizA, 'owner can create a business');
eq(await val(`select role from public.business_members where business_id = $1 and user_id = $2`, [bizA, A]), 'owner', 'owner membership created automatically');
eq(await asUser(A, () => val(`select count(*)::int from public.businesses`)), 1, 'owner sees own business');
eq(await asUser(B, () => val(`select count(*)::int from public.businesses`)), 0, 'other user cannot see the business');
await throws(() => asUser(B, () => q(`insert into public.businesses (owner_id, slug, name_en) values ($1, 'steal', 'Steal')`, [A])),
  'cannot create a business owned by someone else');
await throws(() => asUser(A, () => q(`insert into public.businesses (owner_id, slug) values ($1, 'no-name')`, [A])),
  'business requires a name');
await throws(() => asUser(A, () => q(`insert into public.businesses (owner_id, slug, name_en) values ($1, 'Bad Slug', 'X')`, [A])),
  'slug format enforced');
await throws(() => asAnon(() => q(`select * from public.businesses`)), 'anon has no direct table access', 'permission denied');
eq(await asUser(B, async () => {
  await q(`update public.businesses set name_en = 'Hacked' where id = $1`, [bizA]);
  return (await val(`select name_en from public.businesses where id = $1`, [bizA])) ?? null;
}), null, 'other user cannot update (and cannot read) the business');
eq(await val(`select name_en from public.businesses where id = $1`, [bizA]), 'Spice Garden', 'business name unchanged after foreign update attempt');

// ---------------------------------------------------------------------------
section('Branches, tables and QR codes');
const branch = await asUser(A, async () =>
  (await one(`insert into public.branches (business_id, slug, name_en, name_bn, address, phone)
              values ($1, 'gulshan', 'Gulshan', 'গুলশান', 'Gulshan 2, Dhaka', '01712345678') returning id`, [bizA])).id);
eq(await val(`select count(*)::int from public.qr_codes where branch_id = $1 and kind = 'branch' and is_active`, [branch]), 1, 'branch QR created automatically');
const branch2 = await asUser(A, async () =>
  (await one(`insert into public.branches (business_id, slug, name_en, sort_order) values ($1, 'banani', 'Banani', 2) returning id`, [bizA])).id);
await throws(() => asUser(A, () => q(`insert into public.branches (business_id, slug, name_en) values ($1, 'gulshan', 'Dup')`, [bizA])),
  'branch slug unique per business');
await throws(() => asUser(B, () => q(`insert into public.branches (business_id, slug, name_en) values ($1, 'evil', 'Evil')`, [bizA])),
  'foreign user cannot add a branch');

const table1 = await asUser(A, async () =>
  (await one(`insert into public.restaurant_tables (branch_id, name, capacity, zone) values ($1, 'T-01', 4, 'Ground Floor') returning id`, [branch])).id);
eq(await val(`select count(*)::int from public.qr_codes where table_id = $1 and kind = 'table' and is_active`, [table1]), 1, 'table QR created automatically');
await throws(() => asUser(A, () => q(`insert into public.restaurant_tables (branch_id, name) values ($1, 'T-01')`, [branch])),
  'table name unique per branch');
await throws(() => asUser(A, () => q(`insert into public.qr_codes (business_id, branch_id, kind) values ($1, $2, 'branch')`, [bizA, branch])),
  'only one active branch QR per branch');
eq(await val(`select business_id::text from public.qr_codes where branch_id = $1 and kind = 'branch' limit 1`, [branch]), bizA, 'QR business is derived from the branch');

// ---------------------------------------------------------------------------
section('Business hours and branch status');
// Asia/Dhaka is UTC+6. 2026-11-18 is a Wednesday (isodow 3).
const hours = [
  [3, '12:00', '15:00', 'Lunch'],
  [3, '18:00', '23:30', 'Dinner'],
  [5, '18:00', '02:00', 'Friday night'],   // overnight
  [6, '10:00', '22:00', null],
];
await asUser(A, async () => {
  for (const [wd, o, c, l] of hours) {
    await q(`insert into public.branch_hours (branch_id, weekday, open_time, close_time, label_en) values ($1,$2,$3,$4,$5)`,
      [branch, wd, o, c, l]);
  }
});
const status = (iso) => val(`select public.branch_status($1, $2::timestamptz)`, [branch, iso]);
let s = await status('2026-11-18T07:00:00Z');        // Wed 13:00 Dhaka
eq([s.status, s.is_open, s.closes_at], ['open', true, '15:00:00'], 'open during lunch');
s = await status('2026-11-18T10:00:00Z');            // Wed 16:00 Dhaka
eq([s.status, s.is_open, s.opens_at], ['closed', false, '18:00:00'], 'closed between periods, reports next opening');
s = await status('2026-11-18T13:00:00Z');            // Wed 19:00 Dhaka
eq(s.is_open, true, 'open during dinner (second period of the day)');
s = await status('2026-11-18T18:00:00Z');            // Wed 00:00+1 -> Thu 00:00 Dhaka, Thursday has no rows
eq(s.is_open, false, 'closed on a day without hours');
s = await status('2026-11-20T13:30:00Z');            // Fri 19:30 Dhaka
eq(s.is_open, true, 'open Friday evening (overnight period)');
s = await status('2026-11-20T20:30:00Z');            // Sat 02:30 Dhaka is after close at 02:00? 20:30Z = 02:30 +1
eq(s.is_open, false, 'overnight period ended at 02:00');
s = await status('2026-11-20T19:00:00Z');            // Sat 01:00 Dhaka -> still Friday-night period
eq([s.is_open, s.closes_at], [true, '02:00:00'], 'overnight period still running after midnight');

// Special day: closed all day on Wed 2026-11-18, and a custom-hours day.
await asUser(A, async () => {
  await q(`insert into public.branch_hours (branch_id, special_date, is_closed, label_en) values ($1, '2026-11-18', true, 'Holiday')`, [branch]);
  await q(`insert into public.branch_hours (branch_id, special_date, open_time, close_time, label_en) values ($1, '2026-11-19', '08:00', '12:00', 'Eid special')`, [branch]);
});
s = await status('2026-11-18T07:00:00Z');
eq(s.is_open, false, 'special closed day overrides weekly hours');
s = await status('2026-11-19T03:00:00Z');            // Thu 09:00 Dhaka, Thursday normally closed
eq(s.is_open, true, 'special custom hours open a normally closed day');
await asUser(A, () => q(`delete from public.branch_hours where branch_id = $1 and special_date is not null`, [branch]));

await throws(() => asUser(A, () => q(`insert into public.branch_hours (branch_id, weekday, special_date, open_time, close_time) values ($1, 1, '2026-01-01', '10:00','12:00')`, [branch])),
  'hours row cannot be both weekly and special');
await throws(() => asUser(A, () => q(`insert into public.branch_hours (branch_id, weekday) values ($1, 1)`, [branch])),
  'open period needs open and close times');

// Temporary closure
await asUser(A, () => q(`update public.branches set temp_closed = true, temp_closed_message_en = 'Back soon' where id = $1`, [branch]));
s = await status('2026-11-18T13:00:00Z');
eq(s.status, 'temporarily_closed', 'temporary closure wins over opening hours');
await asUser(A, () => q(`update public.branches set temp_closed_until = '2020-01-01T00:00:00Z' where id = $1`, [branch]));
s = await status('2026-11-18T13:00:00Z');
eq(s.status === 'temporarily_closed', false, 'temporary closure ends after temp_closed_until');
await asUser(A, () => q(`update public.branches set temp_closed = false, temp_closed_until = null where id = $1`, [branch]));

// ---------------------------------------------------------------------------
section('Menu: categories, items, variants');
await asUser(A, () => q(`select public.seed_sample_menu($1)`, [bizA]));
eq(await val(`select count(*)::int from public.menu_categories where business_id = $1`, [bizA]), 5, 'sample menu: 5 categories');
eq(await val(`select count(*)::int from public.menu_items where business_id = $1`, [bizA]), 10, 'sample menu: 10 items');
eq(await val(`select count(*)::int from public.item_options`), 5, 'sample menu: burger options');

await throws(() => asUser(A, () => q(`update public.menu_items set discount_price = price + 1 where business_id = $1 and sku is null and name_en = 'French Fries'`, [bizA])),
  'discount cannot exceed price');
await throws(() => asUser(A, () => q(`update public.menu_items set labels = array['bogus'] where business_id = $1`, [bizA])),
  'unknown label rejected');
await throws(() => asUser(A, () => q(`update public.menu_items set allergens = array['lava'] where business_id = $1`, [bizA])),
  'unknown allergen rejected');
const cat = await val(`select id from public.menu_categories where business_id = $1 and name_en = 'Drinks'`, [bizA]);
const sub = await asUser(A, async () => (await one(`insert into public.menu_categories (business_id, parent_id, name_en) values ($1, $2, 'Cold') returning id`, [bizA, cat])).id);
await throws(() => asUser(A, () => q(`insert into public.menu_categories (business_id, parent_id, name_en) values ($1, $2, 'Too deep')`, [bizA, sub])),
  'subcategory depth limited to one level', 'one level');
const bizB = await asUser(B, async () => (await one(`insert into public.businesses (owner_id, slug, name_en) values ($1, 'other-place', 'Other Place') returning id`, [B])).id);
await throws(() => asUser(B, () => q(`insert into public.menu_items (business_id, category_id, name_en, price) values ($1, $2, 'Cross', 10)`, [bizB, cat])),
  'item cannot point at another business category', 'another business');
await throws(() => asUser(A, () => q(`insert into public.item_option_groups (item_id, name_en, select_type, min_select, max_select)
   values ((select id from public.menu_items where name_en = 'French Fries' limit 1), 'Bad', 'single', 0, 3)`)),
  'single-select group cannot allow several choices');

eq(await asUser(B, () => val(`select count(*)::int from public.menu_items`)), 0, 'other business cannot read menu items');
eq(await asUser(B, () => val(`select count(*)::int from public.item_options`)), 0, 'other business cannot read options');
eq(await asUser(B, async () => {
  await q(`update public.menu_items set price = 1 where business_id = $1`, [bizA]);
  return 0;
}), 0, 'foreign update is a no-op');
eq(await val(`select count(*)::int from public.menu_items where business_id = $1 and price = 1`, [bizA]), 0, 'prices unchanged after foreign update');

// ---------------------------------------------------------------------------
section('Public menu payload');
const menu = (slug, branchSlug = null, token = null, preview = false) =>
  asAnon(() => val(`select public.get_public_menu($1, $2, $3, $4)`, [slug, branchSlug, token, preview]));

let m = await menu('spice-garden');
eq(m.error, undefined, 'public menu resolves by business slug');
eq(m.branch.slug, 'gulshan', 'defaults to the first active branch');
eq(m.branches.length, 2, 'lists active branches for the switcher');
eq(m.categories.length, 6, 'categories include the subcategory');
eq(m.items.length, 10, 'all items are listed');
ok(m.business.owner_id === undefined && m.business.onboarding_step === undefined, 'owner and internal fields are not exposed');
ok(m.items.every((i) => i.sku === undefined), 'SKU is not exposed');
const burger = m.items.find((i) => i.name_en === 'Classic Beef Burger');
eq(burger.option_groups.length, 2, 'burger has two option groups');
eq(burger.option_groups[0].price_mode, 'absolute', 'size group is absolute priced');
eq(burger.option_groups[0].options.map((o) => o.name_en), ['Regular', 'Large'], 'options keep their order');
eq(burger.availability, 'available', 'item is available by default');
eq(m.status.status, 'closed', 'status is included');
eq(m.context.kind, 'menu', 'plain slug access has menu context');
eq((await menu('spice-garden', 'banani')).branch.slug, 'banani', 'resolves a specific branch');
eq((await menu('nope')).error, 'not_found', 'unknown business');
eq((await menu('spice-garden', 'nowhere')).error, 'not_found', 'unknown branch');

// Sold out, schedules, hiding
const fries = await val(`select id from public.menu_items where name_en = 'French Fries'`);
await asUser(A, () => q(`update public.menu_items set is_sold_out = true where id = $1`, [fries]));
const avail = async (name) => (await menu('spice-garden')).items.find((i) => i.name_en === name)?.availability;
eq(await avail('French Fries'), 'sold_out', 'sold-out item is flagged');
await asUser(A, () => q(`update public.menu_items set sold_out_until = now() - interval '1 minute' where id = $1`, [fries]));
eq(await avail('French Fries'), 'available', 'sold-out expires automatically');
await asUser(A, () => q(`update public.menu_items set sold_out_until = now() + interval '2 hours' where id = $1`, [fries]));
eq(await avail('French Fries'), 'sold_out', 'timed sold-out still active');
await asUser(A, () => q(`update public.menu_items set is_sold_out = false, sold_out_until = null where id = $1`, [fries]));

await asUser(A, () => q(`insert into public.branch_item_settings (branch_id, item_id, is_sold_out) values ($1, $2, true)`, [branch, fries]));
eq((await menu('spice-garden', 'gulshan')).items.find((i) => i.name_en === 'French Fries').availability, 'sold_out', 'branch-level sold out applies to that branch');
eq((await menu('spice-garden', 'banani')).items.find((i) => i.name_en === 'French Fries').availability, 'available', 'branch-level sold out does not leak to other branches');

await asUser(A, () => q(`update public.businesses set sold_out_display = 'hide' where id = $1`, [bizA]));
eq((await menu('spice-garden', 'gulshan')).items.some((i) => i.name_en === 'French Fries'), false, 'sold-out items can be hidden entirely');
eq((await menu('spice-garden', 'banani')).items.some((i) => i.name_en === 'French Fries'), true, 'hide setting only affects items that are sold out');
await asUser(A, () => q(`update public.branches set sold_out_display = 'show' where id = $1`, [branch]));
eq((await menu('spice-garden', 'gulshan')).items.some((i) => i.name_en === 'French Fries'), true, 'branch setting overrides the business setting');
await asUser(A, () => q(`update public.businesses set sold_out_display = 'show' where id = $1`, [bizA]));
await asUser(A, () => q(`update public.branches set sold_out_display = null where id = $1`, [branch]));
await asUser(A, () => q(`delete from public.branch_item_settings where branch_id = $1`, [branch]));

// Schedule: item available only on days that are NOT today (local weekday).
const todayIso = await val(`select extract(isodow from (now() at time zone 'Asia/Dhaka'))::int`);
const otherDay = todayIso === 1 ? 2 : 1;
await asUser(A, () => q(`insert into public.item_schedules (item_id, weekdays) values ($1, $2)`, [fries, [otherDay]]));
eq(await avail('French Fries'), 'scheduled', 'item outside its schedule is marked scheduled');
await asUser(A, () => q(`insert into public.item_schedules (item_id, weekdays) values ($1, $2)`, [fries, [todayIso]]));
eq(await avail('French Fries'), 'available', 'any matching schedule row makes the item available');
await asUser(A, () => q(`delete from public.item_schedules where item_id = $1`, [fries]));
await asUser(A, () => q(`insert into public.item_schedules (item_id, start_time, end_time) values ($1, '03:00', '03:01')`, [fries]));
eq(await avail('French Fries'), 'scheduled', 'time window outside the current time');
await asUser(A, () => q(`delete from public.item_schedules where item_id = $1`, [fries]));

// Branch price override, offered flag, category toggle
const wings = await val(`select id from public.menu_items where name_en like 'Crispy Chicken Wings%'`);
await asUser(A, () => q(`insert into public.branch_item_settings (branch_id, item_id, price, discount_price) values ($1, $2, 350, null)`, [branch2, wings]));
let wingsB = (await menu('spice-garden', 'banani')).items.find((i) => i.id === wings);
eq([Number(wingsB.price), wingsB.discount_price], [350, null], 'branch price replaces regular and discount price');
let wingsG = (await menu('spice-garden', 'gulshan')).items.find((i) => i.id === wings);
eq([Number(wingsG.price), Number(wingsG.discount_price)], [320, 290], 'other branch keeps the base price');
await asUser(A, () => q(`update public.branch_item_settings set is_offered = false where branch_id = $1 and item_id = $2`, [branch2, wings]));
eq((await menu('spice-garden', 'banani')).items.some((i) => i.id === wings), false, 'item not offered at a branch is omitted');
const dessertCat = await val(`select id from public.menu_categories where business_id = $1 and name_en = 'Desserts'`, [bizA]);
await asUser(A, () => q(`insert into public.branch_category_settings (branch_id, category_id, is_active) values ($1, $2, false)`, [branch2, dessertCat]));
m = await menu('spice-garden', 'banani');
eq(m.categories.some((c) => c.id === dessertCat), false, 'category switched off for a branch disappears there');
eq(m.items.some((i) => i.name_en === 'Firni'), false, 'items of a switched-off category disappear there');
eq((await menu('spice-garden', 'gulshan')).categories.some((c) => c.id === dessertCat), true, 'category still visible at other branches');

// Hiding / soft-deleting
await asUser(A, () => q(`update public.menu_items set is_active = false where id = $1`, [fries]));
eq((await menu('spice-garden', 'gulshan')).items.some((i) => i.id === fries), false, 'hidden item is not public');
await asUser(A, () => q(`update public.menu_items set is_active = true where id = $1`, [fries]));
await asUser(A, () => q(`update public.menu_categories set is_active = false where id = $1`, [cat]));
m = await menu('spice-garden', 'gulshan');
eq([m.categories.some((c) => c.id === cat), m.categories.some((c) => c.id === sub)], [false, false], 'hiding a category hides its subcategory too');
await asUser(A, () => q(`update public.menu_categories set is_active = true where id = $1`, [cat]));

// Publish state and preview
await asUser(A, () => q(`update public.businesses set menu_published = false where id = $1`, [bizA]));
eq((await menu('spice-garden')).error, 'unpublished', 'unpublished menu is not public');
eq((await menu('spice-garden', null, null, true)).error, 'unpublished', 'preview flag alone does not bypass publishing');
m = await asUser(A, () => val(`select public.get_public_menu('spice-garden', null, null, true)`));
eq([m.error, m.is_preview], [undefined, true], 'members can preview an unpublished menu');
m = await asUser(B, () => val(`select public.get_public_menu('spice-garden', null, null, true)`));
eq(m.error, 'unpublished', 'non-members cannot preview');
await asUser(A, () => q(`update public.businesses set menu_published = true where id = $1`, [bizA]));

// ---------------------------------------------------------------------------
section('QR codes');
const tableToken = await val(`select token from public.qr_codes where table_id = $1`, [table1]);
m = await menu(null, null, tableToken);
eq([m.context.kind, m.context.table_name], ['table', 'T-01'], 'table QR opens the right table context');
eq(await val(`select scan_count::int from public.qr_codes where token = $1`, [tableToken]), 1, 'scan counted');
await menu(null, null, tableToken, true);
eq(await val(`select scan_count::int from public.qr_codes where token = $1`, [tableToken]), 2, 'preview by anon still counts as a scan');
m = await asUser(A, () => val(`select public.get_public_menu(null, null, $1, true)`, [tableToken]));
eq(await val(`select scan_count::int from public.qr_codes where token = $1`, [tableToken]), 2, 'member preview does not inflate scan count');
const qrRow = await val(`select id from public.qr_codes where table_id = $1`, [table1]);
const regenerated = await asUser(A, () => one(`select * from public.regenerate_qr_code($1)`, [qrRow]));
ok(regenerated.token && regenerated.token !== tableToken && regenerated.is_active, 'regenerate creates a new active token');
eq((await menu(null, null, tableToken)).error, 'qr_inactive', 'old QR token stops working');
eq((await menu(null, null, regenerated.token)).context.table_name, 'T-01', 'new QR token works');
eq((await menu(null, null, 'doesnotexist')).error, 'qr_inactive', 'unknown token');
await asUser(A, () => q(`update public.restaurant_tables set is_active = false where id = $1`, [table1]));
eq((await menu(null, null, regenerated.token)).error, 'table_inactive', 'inactive table disables its QR');
await asUser(A, () => q(`update public.restaurant_tables set is_active = true where id = $1`, [table1]));
const takeaway = await asUser(A, () => one(`select * from public.create_qr_code($1, 'takeaway', null, 'Counter')`, [branch]));
eq(takeaway.kind, 'takeaway', 'takeaway QR can be created');
await throws(() => asUser(A, () => q(`select * from public.create_qr_code($1, 'takeaway')`, [branch])), 'only one active takeaway QR');
eq((await menu(null, null, takeaway.token)).context.kind, 'takeaway', 'takeaway QR opens takeaway context');
await throws(() => asUser(B, () => q(`select * from public.regenerate_qr_code($1)`, [qrRow])), 'foreign user cannot regenerate a QR code', 'not found');

// ---------------------------------------------------------------------------
section('Bulk price changes');
const ids = (await q(`select id from public.menu_items where business_id = $1 and name_en in ('Kacchi Biryani','Beef Tehari')`, [bizA])).map((r) => r.id);
let n = await asUser(A, () => val(`select public.bulk_adjust_prices($1::uuid[], 'percent_increase', 10)`, [ids]));
eq(n, 2, 'bulk adjust reports updated rows');
eq(Number(await val(`select price from public.menu_items where name_en = 'Kacchi Biryani'`)), 418, '+10% applied (380 -> 418)');
await asUser(A, () => q(`select public.bulk_adjust_prices($1::uuid[], 'fixed_decrease', 18.5, 'price', true)`, [ids]));
eq(Number(await val(`select price from public.menu_items where name_en = 'Kacchi Biryani'`)), 400, 'fixed decrease with whole-taka rounding');
const wingsBase = await val(`select id from public.menu_items where name_en like 'Crispy Chicken Wings%'`);
await asUser(A, () => q(`select public.bulk_adjust_prices($1::uuid[], 'set', 100, 'price')`, [[wingsBase]]));
eq(await val(`select discount_price from public.menu_items where id = $1`, [wingsBase]), null, 'discount dropped when it would exceed the new price');
await asUser(A, () => q(`select public.bulk_adjust_prices($1::uuid[], 'percent_increase', 10, 'price', false, $2)`, [ids, branch]));
eq(Number(await val(`select price from public.branch_item_settings where branch_id = $1 and item_id = $2`, [branch, ids[0]])) > 0, true, 'branch override created from base price');
await throws(() => asUser(A, () => q(`select public.bulk_adjust_prices($1::uuid[], 'explode', 1)`, [ids])), 'invalid mode rejected');
await throws(() => asUser(A, () => q(`select public.bulk_adjust_prices($1::uuid[], 'set', -5)`, [ids])), 'negative value rejected');
eq(await asUser(B, () => val(`select public.bulk_adjust_prices($1::uuid[], 'set', 1)`, [ids])), 0, 'foreign user changes nothing');

// ---------------------------------------------------------------------------
section('Duplicate, trash and restore');
const burgerId = await val(`select id from public.menu_items where name_en = 'Classic Beef Burger'`);
const copyId = await asUser(A, () => val(`select public.duplicate_menu_item($1)`, [burgerId]));
const copy = await one(`select name_en, name_bn, sku from public.menu_items where id = $1`, [copyId]);
eq([copy.name_en, copy.name_bn], ['Classic Beef Burger (Copy)', 'ক্লাসিক বিফ বার্গার (কপি)'], 'duplicate item gets a copy suffix');
eq(await val(`select count(*)::int from public.item_option_groups where item_id = $1`, [copyId]), 2, 'duplicate keeps option groups');
eq(await val(`select count(*)::int from public.item_options o join public.item_option_groups g on g.id = o.group_id where g.item_id = $1`, [copyId]), 5, 'duplicate keeps options');

const burgerCat = await val(`select id from public.menu_categories where name_en = 'Burgers'`);
const catCopy = await asUser(A, () => val(`select public.duplicate_menu_category($1, true)`, [burgerCat]));
eq(await val(`select count(*)::int from public.menu_items where category_id = $1`, [catCopy]), 2, 'duplicate category copies its items');
const topCopy = await asUser(A, () => val(`select public.duplicate_menu_category($1, true)`, [cat]));
eq(await val(`select count(*)::int from public.menu_categories where parent_id = $1`, [topCopy]), 1, 'duplicate category copies subcategories');

const extraTarget = await val(`select id from public.menu_items where name_en = 'Borhani'`);
await asUser(A, () => q(`select public.copy_option_groups($1, $2)`, [burgerId, extraTarget]));
eq(await val(`select count(*)::int from public.item_option_groups where item_id = $1`, [extraTarget]), 2, 'option groups can be copied to another item');
await throws(() => asUser(A, () => q(`select public.copy_option_groups($1, $1)`, [burgerId])), 'cannot copy groups onto the same item');

await asUser(A, () => q(`select public.soft_delete_category($1)`, [burgerCat]));
eq(await val(`select count(*)::int from public.menu_items where category_id = $1 and deleted_at is not null`, [burgerCat]), 2, 'soft delete trashes items with the category');
m = await menu('spice-garden', 'gulshan');
eq(m.categories.some((c) => c.id === burgerCat), false, 'deleted category is not public');
await throws(() => asUser(A, () => q(`select public.restore_menu_item($1)`, [burgerId])), 'cannot restore an item inside a deleted category', 'restore the category first');
await asUser(A, () => q(`select public.restore_category($1)`, [burgerCat]));
eq(await val(`select count(*)::int from public.menu_items where category_id = $1 and deleted_at is null`, [burgerCat]), 2, 'restore brings the items back');

await asUser(A, () => q(`update public.menu_items set deleted_at = now() where id = $1`, [fries]));
await asUser(A, () => q(`select public.restore_menu_item($1)`, [fries]));
eq(await val(`select deleted_at from public.menu_items where id = $1`, [fries]), null, 'single item can be restored');

// Sub-category restore with its parent
await asUser(A, () => q(`select public.soft_delete_category($1)`, [cat]));
eq(await val(`select count(*)::int from public.menu_categories where id = $1 and deleted_at is not null`, [sub]), 1, 'deleting a category trashes its subcategory');
await throws(() => asUser(A, () => q(`select public.restore_category($1)`, [sub])), 'cannot restore a subcategory under a deleted parent', 'parent');
await asUser(A, () => q(`select public.restore_category($1)`, [cat]));
eq(await val(`select deleted_at from public.menu_categories where id = $1`, [sub]), null, 'restoring the parent restores the subcategory');

// ---------------------------------------------------------------------------
section('Ordering');
const catIds = (await q(`select id from public.menu_categories where business_id = $1 and parent_id is null and deleted_at is null and name_en in ('Starters','Rice & Curry','Burgers')`, [bizA])).map((r) => r.id).reverse();
await asUser(A, () => q(`select public.reorder_menu_categories($1::uuid[])`, [catIds]));
const ordered = (await q(`select id from public.menu_categories where id = any($1::uuid[]) order by sort_order`, [catIds])).map((r) => r.id);
eq(ordered, catIds, 'categories reordered');

// ---------------------------------------------------------------------------
section('Import');
const rows = [
  { category_en: 'Starters', name_en: 'Spring Rolls', name_bn: 'স্প্রিং রোল', price: '180', sku: 'SR-1', labels: ['vegetarian', 'bogus'] },
  { category_en: 'Brand New Category', name_en: 'Soup of the Day', price: '150', is_sold_out: 'true' },
  { category_en: 'Starters', name_en: 'Spring Rolls', price: '200', sku: 'SR-1' },
  { category_en: 'Starters', price: '10' },
  { category_en: 'Starters', name_en: 'Bad Discount', price: '10', discount_price: '20' },
  { name_en: 'No Category', price: '10' },
];
const imp = await asUser(A, () => val(`select public.import_menu_items($1, $2::jsonb, true)`, [bizA, JSON.stringify(rows)]));
eq([imp.created, imp.updated, imp.skipped, imp.errors.length], [2, 1, 0, 3], 'import counts created, updated and failed rows');
eq(imp.errors.map((e) => e.row), [4, 5, 6], 'import reports which rows failed');
eq(await val(`select labels from public.menu_items where sku = 'SR-1'`), ['vegetarian'], 'unknown labels are dropped');
eq(Number(await val(`select price from public.menu_items where sku = 'SR-1'`)), 200, 'existing item matched by SKU is updated');
eq(await val(`select count(*)::int from public.menu_categories where name_en = 'Brand New Category'`), 1, 'missing category created');
eq(await val(`select is_sold_out from public.menu_items where name_en = 'Soup of the Day'`), true, 'boolean columns are parsed');
const imp2 = await asUser(A, () => val(`select public.import_menu_items($1, $2::jsonb, false)`, [bizA, JSON.stringify([rows[0]])]));
eq([imp2.skipped, imp2.updated], [1, 0], 'existing rows are skipped when updates are off');
await throws(() => asUser(A, () => q(`select public.import_menu_items($1, '{}'::jsonb)`, [bizA])), 'import requires an array');
const impForeign = await asUser(B, () => val(`select public.import_menu_items($1, $2::jsonb, true)`, [bizA, JSON.stringify([rows[0]])]));
eq(impForeign.created, 0, 'foreign user cannot import into another business');

// ---------------------------------------------------------------------------
section('Stats and slugs');
const stats = await asUser(A, () => val(`select public.get_menu_stats($1, $2)`, [bizA, branch]));
ok(stats.items >= 10 && stats.categories >= 5 && stats.branches === 2 && stats.tables === 1, 'stats return counts');
eq(await asUser(A, () => val(`select public.is_business_slug_available('spice-garden')`)), false, 'taken slug reported');
eq(await asUser(A, () => val(`select public.is_business_slug_available('spice-garden', $1)`, [bizA])), true, 'own slug is available when excluded');
eq(await asUser(A, () => val(`select public.is_business_slug_available('fresh-name')`)), true, 'free slug reported');
eq(await asUser(A, () => val(`select public.is_business_slug_available('admin')`)), false, 'reserved slug rejected');
eq(await asUser(A, () => val(`select public.is_business_slug_available('Bad Slug')`)), false, 'invalid slug rejected');
eq(await asUser(A, () => val(`select public.is_branch_slug_available($1, 'gulshan')`, [bizA])), false, 'taken branch slug reported');
eq(await asUser(A, () => val(`select public.is_branch_slug_available($1, 'gulshan', $2)`, [bizA, branch])), true, 'own branch slug available when excluded');

// ---------------------------------------------------------------------------
section('Storage policies');
await asUser(A, () => q(`insert into storage.objects (bucket_id, name) values ('menu-images', $1)`, [`${bizA}/items/a.jpg`]));
ok(true, 'member can upload inside their business folder');
await throws(() => asUser(B, () => q(`insert into storage.objects (bucket_id, name) values ('menu-images', $1)`, [`${bizA}/items/b.jpg`])),
  'foreign user cannot upload into another business folder');
await throws(() => asUser(A, () => q(`insert into storage.objects (bucket_id, name) values ('menu-images', 'not-a-uuid/x.jpg')`)),
  'upload outside a business folder is rejected');
eq(await asAnon(() => val(`select count(*)::int from storage.objects where bucket_id = 'menu-images'`)), 1, 'images are publicly readable');
await throws(() => asUser(A, () => q(`insert into storage.objects (bucket_id, name) values ('other-bucket', $1)`, [`${bizA}/x.jpg`])),
  'other buckets are not writable through these policies');

// ---------------------------------------------------------------------------
section('Function privileges');
await throws(() => asAnon(() => q(`select public.bulk_adjust_prices('{}'::uuid[], 'set', 1)`)), 'anon cannot call dashboard RPCs', 'permission denied');
await throws(() => asAnon(() => q(`select public.branch_periods_for($1, current_date)`, [branch])), 'anon cannot call internal helpers', 'permission denied');
ok((await asAnon(() => val(`select public.get_public_menu('spice-garden')`))).business !== undefined, 'anon can call get_public_menu');
ok((await asAnon(() => val(`select public.branch_status($1)`, [branch]))).status !== undefined, 'anon can call branch_status');

// ---------------------------------------------------------------------------
console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.log('\nFailures:');
  for (const f of failures) console.log(`  - ${f}`);
  process.exit(1);
}
} catch (e) {
  console.log(`\nFATAL after ${passed} passed checks: ${e.message}`);
  if (e.query) console.log(`  query: ${String(e.query).replace(/\s+/g, ' ').slice(0, 300)}`);
  process.exit(1);
}
