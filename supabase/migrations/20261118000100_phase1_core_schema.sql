-- =============================================================================
-- EZ Menu - Phase 1: Core schema
-- Businesses, branches, business hours, menu (categories, items, variants and
-- add-ons, schedules, per-branch overrides), tables and QR codes.
--
-- Conventions
--   * Bilingual content uses paired columns:  <field>_en / <field>_bn.
--   * Every table that holds business data is protected by Row Level Security
--     (see the next migration). The public customer menu is served ONLY by the
--     get_public_menu() RPC, never by direct table access.
--   * business_members is created now (owner only) so staff roles can be added
--     in Phase 3 without a schema change.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Generic helpers
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Random, URL-safe token for QR codes (12 hex chars from a CSPRNG-backed uuid).
create or replace function public.generate_qr_token()
returns text
language sql
volatile
as $$
  select substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
$$;

-- ----------------------------------------------------------------------------
-- profiles
-- ----------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text check (full_name is null or char_length(full_name) <= 120),
  phone       text check (phone is null or char_length(phone) <= 32),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'phone'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- businesses
-- ----------------------------------------------------------------------------
create table public.businesses (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references auth.users (id) on delete restrict,
  slug          text not null unique
                  check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 3 and 60),

  name_en       text check (name_en is null or char_length(name_en) <= 120),
  name_bn       text check (name_bn is null or char_length(name_bn) <= 120),
  business_type text not null default 'restaurant'
                  check (business_type in
                    ('restaurant','cafe','fast_food','bakery','food_court','cloud_kitchen','sweets_shop','other')),

  logo_url      text,
  cover_url     text,

  phone         text check (phone is null or char_length(phone) <= 32),
  email         text check (email is null or char_length(email) <= 160),
  address       text check (address is null or char_length(address) <= 400),
  map_url       text check (map_url is null or char_length(map_url) <= 600),

  description_en text check (description_en is null or char_length(description_en) <= 1500),
  description_bn text check (description_bn is null or char_length(description_bn) <= 1500),

  website_url     text check (website_url is null or char_length(website_url) <= 300),
  facebook_url    text check (facebook_url is null or char_length(facebook_url) <= 300),
  instagram_url   text check (instagram_url is null or char_length(instagram_url) <= 300),
  tiktok_url      text check (tiktok_url is null or char_length(tiktok_url) <= 300),
  youtube_url     text check (youtube_url is null or char_length(youtube_url) <= 300),
  whatsapp_number text check (whatsapp_number is null or char_length(whatsapp_number) <= 32),

  currency          text not null default 'BDT' check (char_length(currency) = 3),
  default_language  text not null default 'bn' check (default_language in ('bn','en')),
  timezone          text not null default 'Asia/Dhaka',

  brand_color   text not null default '#166A4C' check (brand_color ~ '^#[0-9A-Fa-f]{6}$'),
  menu_theme    text not null default 'light' check (menu_theme in ('light','warm','dark')),
  menu_layout   text not null default 'list' check (menu_layout in ('list','grid')),

  welcome_message_en text check (welcome_message_en is null or char_length(welcome_message_en) <= 400),
  welcome_message_bn text check (welcome_message_bn is null or char_length(welcome_message_bn) <= 400),
  terms_en            text check (terms_en is null or char_length(terms_en) <= 6000),
  terms_bn            text check (terms_bn is null or char_length(terms_bn) <= 6000),
  refund_policy_en    text check (refund_policy_en is null or char_length(refund_policy_en) <= 6000),
  refund_policy_bn    text check (refund_policy_bn is null or char_length(refund_policy_bn) <= 6000),
  allergen_notice_en  text check (allergen_notice_en is null or char_length(allergen_notice_en) <= 1500),
  allergen_notice_bn  text check (allergen_notice_bn is null or char_length(allergen_notice_bn) <= 1500),

  -- How sold-out / out-of-schedule items appear on the customer menu.
  sold_out_display  text not null default 'show' check (sold_out_display in ('show','hide')),
  menu_published    boolean not null default true,

  onboarding_step         smallint not null default 0,
  onboarding_completed_at timestamptz,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint businesses_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> '')
);

create index businesses_owner_idx on public.businesses (owner_id);

create trigger businesses_set_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- business_members (owner now, staff roles in Phase 3)
-- ----------------------------------------------------------------------------
create table public.business_members (
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        text not null
                check (role in ('owner','admin','manager','cashier','waiter','kitchen')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  primary key (business_id, user_id)
);

create index business_members_user_idx on public.business_members (user_id);

-- The creator of a business becomes its owner member.
create or replace function public.add_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.business_members (business_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (business_id, user_id) do nothing;
  return new;
end;
$$;

create trigger businesses_add_owner_membership
  after insert on public.businesses
  for each row execute function public.add_owner_membership();

-- ----------------------------------------------------------------------------
-- Permission helpers (used by RLS policies and RPCs)
-- ----------------------------------------------------------------------------
create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members m
    where m.business_id = p_business_id
      and m.user_id = auth.uid()
      and m.is_active
  );
$$;

create or replace function public.has_business_role(p_business_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members m
    where m.business_id = p_business_id
      and m.user_id = auth.uid()
      and m.is_active
      and m.role = any (p_roles)
  );
$$;

-- Owner / admin: profile, branding, branches.
create or replace function public.can_manage_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_business_role(p_business_id, array['owner','admin']);
$$;

-- Owner / admin / manager: menu, hours, tables, QR codes.
create or replace function public.can_manage_operations(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_business_role(p_business_id, array['owner','admin','manager']);
$$;

-- ----------------------------------------------------------------------------
-- branches
-- ----------------------------------------------------------------------------
create table public.branches (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  slug         text not null
                 check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 2 and 60),
  name_en      text check (name_en is null or char_length(name_en) <= 120),
  name_bn      text check (name_bn is null or char_length(name_bn) <= 120),

  address      text check (address is null or char_length(address) <= 400),
  area         text check (area is null or char_length(area) <= 120),
  phone        text check (phone is null or char_length(phone) <= 32),
  email        text check (email is null or char_length(email) <= 160),
  map_url      text check (map_url is null or char_length(map_url) <= 600),
  latitude     numeric(9,6) check (latitude is null or latitude between -90 and 90),
  longitude    numeric(9,6) check (longitude is null or longitude between -180 and 180),

  is_active    boolean not null default true,
  sort_order   integer not null default 0,

  -- Temporary closure ("Closed" / "Temporarily Unavailable") independent of hours.
  temp_closed            boolean not null default false,
  temp_closed_message_en text check (temp_closed_message_en is null or char_length(temp_closed_message_en) <= 300),
  temp_closed_message_bn text check (temp_closed_message_bn is null or char_length(temp_closed_message_bn) <= 300),
  temp_closed_until      timestamptz,

  -- Behaviour outside opening hours (used by ordering in Phase 2).
  outside_hours_behavior text not null default 'block_orders'
                           check (outside_hours_behavior in ('block_orders','allow_scheduled')),

  -- NULL = inherit the business setting.
  sold_out_display text check (sold_out_display is null or sold_out_display in ('show','hide')),

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  unique (business_id, slug),
  constraint branches_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> '')
);

create index branches_business_idx on public.branches (business_id, sort_order);

create trigger branches_set_updated_at
  before update on public.branches
  for each row execute function public.set_updated_at();

create or replace function public.business_of_branch(p_branch_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select b.business_id from public.branches b where b.id = p_branch_id;
$$;

-- ----------------------------------------------------------------------------
-- branch_hours
--   Weekly rows:       weekday (1 = Monday ... 7 = Sunday), open_time, close_time.
--                      Several rows per weekday = several service periods.
--                      A weekday with no rows is a day off.
--   Special-day rows:  special_date (+ optional special_date_end for a range).
--                      is_closed = true  -> closed for the whole range.
--                      is_closed = false -> custom periods replace the weekly ones.
--   close_time <= open_time means the period runs past midnight.
-- ----------------------------------------------------------------------------
create table public.branch_hours (
  id               uuid primary key default gen_random_uuid(),
  branch_id        uuid not null references public.branches (id) on delete cascade,
  weekday          smallint check (weekday between 1 and 7),
  special_date     date,
  special_date_end date,
  is_closed        boolean not null default false,
  open_time        time,
  close_time       time,
  label_en         text check (label_en is null or char_length(label_en) <= 80),
  label_bn         text check (label_bn is null or char_length(label_bn) <= 80),
  created_at       timestamptz not null default now(),

  constraint branch_hours_kind
    check ((weekday is not null and special_date is null)
        or (weekday is null and special_date is not null)),
  constraint branch_hours_times
    check (is_closed or (open_time is not null and close_time is not null)),
  constraint branch_hours_closed_is_special
    check (not is_closed or special_date is not null),
  constraint branch_hours_range
    check (special_date_end is null or special_date_end >= special_date)
);

create index branch_hours_branch_idx on public.branch_hours (branch_id);

-- ----------------------------------------------------------------------------
-- menu_categories (two levels: category + subcategory)
-- ----------------------------------------------------------------------------
create table public.menu_categories (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.businesses (id) on delete cascade,
  parent_id      uuid references public.menu_categories (id) on delete cascade,
  name_en        text check (name_en is null or char_length(name_en) <= 120),
  name_bn        text check (name_bn is null or char_length(name_bn) <= 120),
  description_en text check (description_en is null or char_length(description_en) <= 500),
  description_bn text check (description_bn is null or char_length(description_bn) <= 500),
  image_url      text,
  icon           text check (icon is null or char_length(icon) <= 40),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  deleted_at     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint menu_categories_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> ''),
  constraint menu_categories_not_self_parent check (parent_id is null or parent_id <> id)
);

create index menu_categories_business_idx
  on public.menu_categories (business_id, parent_id, sort_order)
  where deleted_at is null;

create trigger menu_categories_set_updated_at
  before update on public.menu_categories
  for each row execute function public.set_updated_at();

-- A subcategory must sit directly under a top-level category of the same business.
create or replace function public.check_category_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent public.menu_categories%rowtype;
begin
  if new.parent_id is null then
    return new;
  end if;
  select * into v_parent from public.menu_categories where id = new.parent_id;
  if not found then
    raise exception 'Parent category not found';
  end if;
  if v_parent.business_id <> new.business_id then
    raise exception 'Parent category belongs to another business';
  end if;
  if v_parent.parent_id is not null then
    raise exception 'Subcategories can only be one level deep';
  end if;
  return new;
end;
$$;

create trigger menu_categories_check_parent
  before insert or update of parent_id, business_id on public.menu_categories
  for each row execute function public.check_category_parent();

-- ----------------------------------------------------------------------------
-- menu_items
-- ----------------------------------------------------------------------------
create table public.menu_items (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses (id) on delete cascade,
  category_id   uuid not null references public.menu_categories (id) on delete cascade,

  name_en       text check (name_en is null or char_length(name_en) <= 160),
  name_bn       text check (name_bn is null or char_length(name_bn) <= 160),
  short_description_en text check (short_description_en is null or char_length(short_description_en) <= 200),
  short_description_bn text check (short_description_bn is null or char_length(short_description_bn) <= 200),
  description_en text check (description_en is null or char_length(description_en) <= 2000),
  description_bn text check (description_bn is null or char_length(description_bn) <= 2000),
  ingredients_en text check (ingredients_en is null or char_length(ingredients_en) <= 800),
  ingredients_bn text check (ingredients_bn is null or char_length(ingredients_bn) <= 800),

  price          numeric(12,2) not null default 0 check (price >= 0),
  discount_price numeric(12,2) check (discount_price is null or (discount_price >= 0 and discount_price <= price)),

  prep_time_min  smallint check (prep_time_min is null or prep_time_min between 0 and 600),
  sku            text check (sku is null or char_length(sku) <= 60),

  labels         text[] not null default '{}'
                   check (labels <@ array['vegetarian','vegan','spicy','popular','chefs_special',
                                          'new','recommended','halal','gluten_free','dairy_free']::text[]),
  allergens      text[] not null default '{}'
                   check (allergens <@ array['milk','eggs','peanuts','tree_nuts','gluten','soy',
                                             'fish','shellfish','sesame','mustard']::text[]),
  allergen_note  text check (allergen_note is null or char_length(allergen_note) <= 400),
  dietary_info   text check (dietary_info is null or char_length(dietary_info) <= 400),
  spice_level    smallint check (spice_level is null or spice_level between 0 and 3),
  calories       integer check (calories is null or calories >= 0),
  nutrition      jsonb not null default '{}'::jsonb,

  image_urls     text[] not null default '{}' check (cardinality(image_urls) <= 8),

  is_active      boolean not null default true,   -- hide / show on the menu
  is_featured    boolean not null default false,
  is_sold_out    boolean not null default false,  -- master sold-out switch
  sold_out_until timestamptz,                     -- auto-available again after this time
  sort_order     integer not null default 0,

  deleted_at     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint menu_items_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> '')
);

create index menu_items_business_idx on public.menu_items (business_id) where deleted_at is null;
create index menu_items_category_idx on public.menu_items (category_id, sort_order) where deleted_at is null;
create index menu_items_sku_idx on public.menu_items (business_id, sku) where sku is not null;

create trigger menu_items_set_updated_at
  before update on public.menu_items
  for each row execute function public.set_updated_at();

create or replace function public.business_of_item(p_item_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select i.business_id from public.menu_items i where i.id = p_item_id;
$$;

-- Item belongs to the same business as its category.
create or replace function public.check_item_category()
returns trigger
language plpgsql
as $$
declare
  v_cat_business uuid;
begin
  select c.business_id into v_cat_business from public.menu_categories c where c.id = new.category_id;
  if v_cat_business is null or v_cat_business <> new.business_id then
    raise exception 'Category belongs to another business';
  end if;
  return new;
end;
$$;

create trigger menu_items_check_category
  before insert or update of category_id, business_id on public.menu_items
  for each row execute function public.check_item_category();

-- ----------------------------------------------------------------------------
-- item_schedules: when an item is orderable. No rows = always available.
-- Several rows are alternatives (OR).
-- ----------------------------------------------------------------------------
create table public.item_schedules (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references public.menu_items (id) on delete cascade,
  weekdays    smallint[] not null default '{}'
                check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),   -- empty = every day
  start_time  time,
  end_time    time,                                                       -- both null = all day
  start_date  date,
  end_date    date,
  label       text check (label is null or char_length(label) <= 80),
  created_at  timestamptz not null default now(),
  constraint item_schedules_time_pair check ((start_time is null) = (end_time is null)),
  constraint item_schedules_date_range check (end_date is null or start_date is null or end_date >= start_date)
);

create index item_schedules_item_idx on public.item_schedules (item_id);

-- ----------------------------------------------------------------------------
-- Variants and add-ons
--   item_option_groups: e.g. "Size" (single, required), "Extras" (multiple).
--   price_mode 'additional' -> option price is added to the item price.
--   price_mode 'absolute'   -> option price REPLACES the item price (portions / sizes).
-- ----------------------------------------------------------------------------
create table public.item_option_groups (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references public.menu_items (id) on delete cascade,
  name_en     text check (name_en is null or char_length(name_en) <= 120),
  name_bn     text check (name_bn is null or char_length(name_bn) <= 120),
  select_type text not null default 'single' check (select_type in ('single','multiple')),
  price_mode  text not null default 'additional' check (price_mode in ('additional','absolute')),
  is_required boolean not null default false,
  min_select  smallint not null default 0 check (min_select >= 0),
  max_select  smallint check (max_select is null or max_select >= 1),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint item_option_groups_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> ''),
  constraint item_option_groups_min_max check (max_select is null or min_select <= max_select),
  constraint item_option_groups_single_rules
    check (select_type <> 'single' or (min_select <= 1 and (max_select is null or max_select = 1)))
);

create index item_option_groups_item_idx on public.item_option_groups (item_id, sort_order);

create trigger item_option_groups_set_updated_at
  before update on public.item_option_groups
  for each row execute function public.set_updated_at();

create table public.item_options (
  id             uuid primary key default gen_random_uuid(),
  group_id       uuid not null references public.item_option_groups (id) on delete cascade,
  name_en        text check (name_en is null or char_length(name_en) <= 120),
  name_bn        text check (name_bn is null or char_length(name_bn) <= 120),
  price          numeric(12,2) not null default 0 check (price >= 0),
  discount_price numeric(12,2) check (discount_price is null or (discount_price >= 0 and discount_price <= price)),
  image_url      text,
  is_default     boolean not null default false,
  is_available   boolean not null default true,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now(),
  constraint item_options_name_required
    check (coalesce(btrim(name_en), '') <> '' or coalesce(btrim(name_bn), '') <> '')
);

create index item_options_group_idx on public.item_options (group_id, sort_order);

create or replace function public.business_of_group(p_group_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select i.business_id
  from public.item_option_groups g
  join public.menu_items i on i.id = g.item_id
  where g.id = p_group_id;
$$;

-- ----------------------------------------------------------------------------
-- Per-branch overrides
-- ----------------------------------------------------------------------------
create table public.branch_category_settings (
  branch_id   uuid not null references public.branches (id) on delete cascade,
  category_id uuid not null references public.menu_categories (id) on delete cascade,
  is_active   boolean not null default true,
  primary key (branch_id, category_id)
);

-- If price is set it replaces BOTH the regular and the discounted price at that branch.
create table public.branch_item_settings (
  branch_id      uuid not null references public.branches (id) on delete cascade,
  item_id        uuid not null references public.menu_items (id) on delete cascade,
  is_offered     boolean not null default true,
  price          numeric(12,2) check (price is null or price >= 0),
  discount_price numeric(12,2) check (discount_price is null or (price is not null and discount_price >= 0 and discount_price <= price)),
  is_sold_out    boolean not null default false,
  sold_out_until timestamptz,
  updated_at     timestamptz not null default now(),
  primary key (branch_id, item_id)
);

create index branch_item_settings_item_idx on public.branch_item_settings (item_id);

create trigger branch_item_settings_set_updated_at
  before update on public.branch_item_settings
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- restaurant_tables (Phase 1: name, capacity, zone label; floor plan in Phase 3)
-- ----------------------------------------------------------------------------
create table public.restaurant_tables (
  id          uuid primary key default gen_random_uuid(),
  branch_id   uuid not null references public.branches (id) on delete cascade,
  name        text not null check (btrim(name) <> '' and char_length(name) <= 60),
  capacity    smallint check (capacity is null or capacity between 1 and 100),
  zone        text check (zone is null or char_length(zone) <= 60),
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (branch_id, name)
);

create index restaurant_tables_branch_idx on public.restaurant_tables (branch_id, sort_order);

create trigger restaurant_tables_set_updated_at
  before update on public.restaurant_tables
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- qr_codes
--   kind 'branch'   : general menu for a branch
--   kind 'table'    : dine-in menu bound to a table
--   kind 'takeaway' : takeaway counter / general pickup menu
--   Regenerating deactivates the old row and creates a new token, so printed
--   codes can be revoked without touching the table or branch.
-- ----------------------------------------------------------------------------
create table public.qr_codes (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses (id) on delete cascade,
  branch_id       uuid not null references public.branches (id) on delete cascade,
  table_id        uuid references public.restaurant_tables (id) on delete cascade,
  kind            text not null check (kind in ('branch','table','takeaway')),
  token           text not null unique default public.generate_qr_token(),
  label           text check (label is null or char_length(label) <= 80),
  is_active       boolean not null default true,
  scan_count      bigint not null default 0,
  last_scanned_at timestamptz,
  deactivated_at  timestamptz,
  created_at      timestamptz not null default now(),
  constraint qr_codes_table_required check ((kind = 'table') = (table_id is not null))
);

create unique index qr_one_active_branch   on public.qr_codes (branch_id) where kind = 'branch'   and is_active;
create unique index qr_one_active_takeaway on public.qr_codes (branch_id) where kind = 'takeaway' and is_active;
create unique index qr_one_active_table    on public.qr_codes (table_id)  where kind = 'table'    and is_active;
create index qr_codes_branch_idx on public.qr_codes (branch_id);

-- business_id is always derived from the branch, never trusted from the client.
create or replace function public.qr_codes_fill_business()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.business_id := public.business_of_branch(new.branch_id);
  if new.business_id is null then
    raise exception 'Branch not found';
  end if;
  return new;
end;
$$;

create trigger qr_codes_fill_business_trg
  before insert on public.qr_codes
  for each row execute function public.qr_codes_fill_business();

-- Every new branch gets its branch QR automatically.
create or replace function public.create_default_branch_qr()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.qr_codes (business_id, branch_id, kind, label)
  values (new.business_id, new.id, 'branch', 'Branch menu');
  return new;
end;
$$;

create trigger branches_create_default_qr
  after insert on public.branches
  for each row execute function public.create_default_branch_qr();

-- Every new table gets its table QR automatically.
create or replace function public.create_default_table_qr()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.qr_codes (business_id, branch_id, table_id, kind, label)
  values (public.business_of_branch(new.branch_id), new.branch_id, new.id, 'table', new.name);
  return new;
end;
$$;

create trigger restaurant_tables_create_default_qr
  after insert on public.restaurant_tables
  for each row execute function public.create_default_table_qr();
