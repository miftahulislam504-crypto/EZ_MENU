-- =============================================================================
-- EZ Menu - Phase 1: Functions (RPC)
--
--   Public (anon + authenticated)
--     get_public_menu()          customer menu payload in ONE round trip
--     branch_status()            open / closed / temporarily closed
--
--   Dashboard (authenticated, run with the caller's rights so RLS applies)
--     is_business_slug_available, is_branch_slug_available
--     reorder_menu_categories, reorder_menu_items
--     bulk_adjust_prices
--     duplicate_menu_item, duplicate_menu_category, copy_option_groups
--     soft_delete_category, restore_category, restore_menu_item
--     import_menu_items
--     create_qr_code, regenerate_qr_code
--     get_menu_stats, seed_sample_menu
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Business hours
-- ----------------------------------------------------------------------------

-- Service periods that apply to one calendar date.
-- Special-day rows (if any cover the date) REPLACE the weekly rows; a special
-- row marked closed therefore yields no periods at all.
create or replace function public.branch_periods_for(p_branch_id uuid, p_date date)
returns table (period_open time, period_close time, period_label_en text, period_label_bn text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.branch_hours h
    where h.branch_id = p_branch_id
      and h.special_date is not null
      and p_date between h.special_date and coalesce(h.special_date_end, h.special_date)
  ) then
    return query
      select h.open_time, h.close_time, h.label_en, h.label_bn
      from public.branch_hours h
      where h.branch_id = p_branch_id
        and h.special_date is not null
        and p_date between h.special_date and coalesce(h.special_date_end, h.special_date)
        and not h.is_closed
      order by h.open_time;
  else
    return query
      select h.open_time, h.close_time, h.label_en, h.label_bn
      from public.branch_hours h
      where h.branch_id = p_branch_id
        and h.weekday = extract(isodow from p_date)::int
      order by h.open_time;
  end if;
end;
$$;

-- Current status of a branch in the BUSINESS time zone.
-- status: 'open' | 'closed' | 'temporarily_closed'
create or replace function public.branch_status(p_branch_id uuid, p_at timestamptz default now())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b        public.branches%rowtype;
  biz      public.businesses%rowtype;
  v_local  timestamp;
  v_date   date;
  v_time   time;
  v_open   boolean := false;
  v_closes time;
  v_opens  time;
  r        record;
begin
  select * into b from public.branches where id = p_branch_id;
  if not found then
    return jsonb_build_object('status', 'closed', 'is_open', false);
  end if;
  select * into biz from public.businesses where id = b.business_id;

  if b.temp_closed and (b.temp_closed_until is null or b.temp_closed_until > p_at) then
    return jsonb_build_object(
      'status', 'temporarily_closed',
      'is_open', false,
      'until', b.temp_closed_until
    );
  end if;

  v_local := p_at at time zone biz.timezone;
  v_date  := v_local::date;
  v_time  := v_local::time;

  -- Periods that start today.
  for r in select * from public.branch_periods_for(b.id, v_date) loop
    if r.period_open < r.period_close then
      if v_time >= r.period_open and v_time < r.period_close then
        v_open := true;
        v_closes := r.period_close;
      end if;
    else
      -- Runs past midnight (close <= open).
      if v_time >= r.period_open then
        v_open := true;
        v_closes := r.period_close;
      end if;
    end if;
    if r.period_open > v_time and (v_opens is null or r.period_open < v_opens) then
      v_opens := r.period_open;
    end if;
  end loop;

  -- Overnight periods that started yesterday and are still running.
  if not v_open then
    for r in select * from public.branch_periods_for(b.id, v_date - 1) loop
      if r.period_close <= r.period_open and v_time < r.period_close then
        v_open := true;
        v_closes := r.period_close;
      end if;
    end loop;
  end if;

  return jsonb_build_object(
    'status', case when v_open then 'open' else 'closed' end,
    'is_open', v_open,
    'closes_at', case when v_open then v_closes else null end,
    'opens_at', case when v_open then null else v_opens end
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Availability helpers
-- ----------------------------------------------------------------------------

-- True when the item has no schedule, or at least one schedule row matches.
create or replace function public.item_in_schedule(p_item_id uuid, p_local_date date, p_local_time time)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    not exists (select 1 from public.item_schedules s where s.item_id = p_item_id)
    or exists (
      select 1
      from public.item_schedules s
      where s.item_id = p_item_id
        and (cardinality(s.weekdays) = 0 or extract(isodow from p_local_date)::int = any (s.weekdays))
        and (s.start_date is null or p_local_date >= s.start_date)
        and (s.end_date   is null or p_local_date <= s.end_date)
        and (
          s.start_time is null
          or (s.start_time <  s.end_time and p_local_time >= s.start_time and p_local_time < s.end_time)
          or (s.start_time >= s.end_time and (p_local_time >= s.start_time or p_local_time < s.end_time))
        )
    );
$$;

-- Categories visible on a branch's customer menu.
create or replace function public.visible_menu_categories(p_business_id uuid, p_branch_id uuid)
returns setof public.menu_categories
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.menu_categories c
  where c.business_id = p_business_id
    and c.deleted_at is null
    and c.is_active
    and not exists (
      select 1 from public.branch_category_settings s
      where s.branch_id = p_branch_id and s.category_id = c.id and not s.is_active
    )
    and (
      c.parent_id is null
      or exists (
        select 1
        from public.menu_categories p
        where p.id = c.parent_id
          and p.deleted_at is null
          and p.is_active
          and not exists (
            select 1 from public.branch_category_settings s2
            where s2.branch_id = p_branch_id and s2.category_id = p.id and not s2.is_active
          )
      )
    );
$$;

-- ----------------------------------------------------------------------------
-- get_public_menu: the whole customer menu in one call.
--   Resolve either by QR token, or by business slug (+ optional branch slug).
--   Returns {"error": "..."} instead of raising, so the app can show a
--   friendly screen:  not_found | qr_inactive | table_inactive |
--                     branch_inactive | unpublished
--   p_preview lets signed-in members preview an unpublished menu.
-- ----------------------------------------------------------------------------
create or replace function public.get_public_menu(
  p_business_slug text default null,
  p_branch_slug   text default null,
  p_qr_token      text default null,
  p_preview       boolean default false
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_qr        public.qr_codes%rowtype;
  v_biz       public.businesses%rowtype;
  v_branch    public.branches%rowtype;
  v_table     public.restaurant_tables%rowtype;
  v_kind      text := 'menu';
  v_now       timestamptz := now();
  v_local     timestamp;
  v_date      date;
  v_time      time;
  v_hide      boolean;
  v_member    boolean := false;
  v_categories jsonb;
  v_items      jsonb;
  v_branches   jsonb;
  v_weekly     jsonb;
  v_special    jsonb;
begin
  if p_qr_token is not null then
    select * into v_qr from public.qr_codes where token = btrim(p_qr_token);
    if not found or not v_qr.is_active then
      return jsonb_build_object('error', 'qr_inactive');
    end if;
    select * into v_branch from public.branches where id = v_qr.branch_id;
    select * into v_biz from public.businesses where id = v_branch.business_id;
    v_kind := v_qr.kind;
    if v_qr.table_id is not null then
      select * into v_table from public.restaurant_tables where id = v_qr.table_id;
      if not found or not v_table.is_active then
        return jsonb_build_object('error', 'table_inactive');
      end if;
    end if;
  else
    if p_business_slug is null then
      return jsonb_build_object('error', 'not_found');
    end if;
    select * into v_biz from public.businesses where slug = lower(btrim(p_business_slug));
    if not found then
      return jsonb_build_object('error', 'not_found');
    end if;
    if p_branch_slug is null or btrim(p_branch_slug) = '' then
      select * into v_branch
      from public.branches
      where business_id = v_biz.id and is_active
      order by sort_order, created_at
      limit 1;
    else
      select * into v_branch
      from public.branches
      where business_id = v_biz.id and slug = lower(btrim(p_branch_slug)) and is_active;
    end if;
    if not found then
      return jsonb_build_object('error', 'not_found');
    end if;
  end if;

  if not v_branch.is_active then
    return jsonb_build_object('error', 'branch_inactive');
  end if;

  v_member := p_preview and public.is_business_member(v_biz.id);
  if not v_biz.menu_published and not v_member then
    return jsonb_build_object('error', 'unpublished');
  end if;

  if p_qr_token is not null and not v_member then
    update public.qr_codes
       set scan_count = scan_count + 1, last_scanned_at = v_now
     where id = v_qr.id;
  end if;

  v_local := v_now at time zone v_biz.timezone;
  v_date  := v_local::date;
  v_time  := v_local::time;
  v_hide  := coalesce(v_branch.sold_out_display, v_biz.sold_out_display) = 'hide';

  -- Categories
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id,
           'parent_id', c.parent_id,
           'name_en', c.name_en,
           'name_bn', c.name_bn,
           'description_en', c.description_en,
           'description_bn', c.description_bn,
           'image_url', c.image_url,
           'icon', c.icon,
           'sort_order', c.sort_order
         ) order by c.sort_order, c.created_at), '[]'::jsonb)
    into v_categories
    from public.visible_menu_categories(v_biz.id, v_branch.id) c;

  -- Items (with effective price and availability for THIS branch)
  select coalesce(jsonb_agg(t.item_json order by t.cat_sort, t.item_sort, t.created_at), '[]'::jsonb)
    into v_items
  from (
    select
      jsonb_build_object(
        'id', i.id,
        'category_id', i.category_id,
        'name_en', i.name_en,
        'name_bn', i.name_bn,
        'short_description_en', i.short_description_en,
        'short_description_bn', i.short_description_bn,
        'description_en', i.description_en,
        'description_bn', i.description_bn,
        'ingredients_en', i.ingredients_en,
        'ingredients_bn', i.ingredients_bn,
        'price', x.eff_price,
        'discount_price', x.eff_discount,
        'prep_time_min', i.prep_time_min,
        'labels', to_jsonb(i.labels),
        'allergens', to_jsonb(i.allergens),
        'allergen_note', i.allergen_note,
        'dietary_info', i.dietary_info,
        'spice_level', i.spice_level,
        'calories', i.calories,
        'nutrition', i.nutrition,
        'image_urls', to_jsonb(i.image_urls),
        'is_featured', i.is_featured,
        'sort_order', i.sort_order,
        'availability', case
                          when x.eff_sold_out then 'sold_out'
                          when not x.in_schedule then 'scheduled'
                          else 'available'
                        end,
        'schedules', (
          select coalesce(jsonb_agg(jsonb_build_object(
                   'weekdays', to_jsonb(s.weekdays),
                   'start_time', s.start_time,
                   'end_time', s.end_time,
                   'start_date', s.start_date,
                   'end_date', s.end_date
                 )), '[]'::jsonb)
          from public.item_schedules s
          where s.item_id = i.id
        ),
        'option_groups', (
          select coalesce(jsonb_agg(jsonb_build_object(
                   'id', g.id,
                   'name_en', g.name_en,
                   'name_bn', g.name_bn,
                   'select_type', g.select_type,
                   'price_mode', g.price_mode,
                   'is_required', g.is_required,
                   'min_select', g.min_select,
                   'max_select', g.max_select,
                   'options', (
                     select coalesce(jsonb_agg(jsonb_build_object(
                              'id', o.id,
                              'name_en', o.name_en,
                              'name_bn', o.name_bn,
                              'price', o.price,
                              'discount_price', o.discount_price,
                              'image_url', o.image_url,
                              'is_default', o.is_default,
                              'is_available', o.is_available
                            ) order by o.sort_order, o.created_at), '[]'::jsonb)
                     from public.item_options o
                     where o.group_id = g.id
                   )
                 ) order by g.sort_order, g.created_at), '[]'::jsonb)
          from public.item_option_groups g
          where g.item_id = i.id
        )
      ) as item_json,
      c.sort_order as cat_sort,
      i.sort_order as item_sort,
      i.created_at
    from public.visible_menu_categories(v_biz.id, v_branch.id) c
    join public.menu_items i on i.category_id = c.id
    left join public.branch_item_settings bis
           on bis.branch_id = v_branch.id and bis.item_id = i.id
    cross join lateral (
      select
        case when bis.price is not null then bis.price else i.price end as eff_price,
        case when bis.price is not null then bis.discount_price else i.discount_price end as eff_discount,
        (
          (i.is_sold_out and (i.sold_out_until is null or i.sold_out_until > v_now))
          or (coalesce(bis.is_sold_out, false) and (bis.sold_out_until is null or bis.sold_out_until > v_now))
        ) as eff_sold_out,
        public.item_in_schedule(i.id, v_date, v_time) as in_schedule
    ) x
    where i.business_id = v_biz.id
      and i.deleted_at is null
      and i.is_active
      and coalesce(bis.is_offered, true)
      and not (v_hide and (x.eff_sold_out or not x.in_schedule))
  ) t;

  -- Other active branches (for the branch switcher)
  select coalesce(jsonb_agg(jsonb_build_object(
           'slug', b.slug,
           'name_en', b.name_en,
           'name_bn', b.name_bn,
           'area', b.area
         ) order by b.sort_order, b.created_at), '[]'::jsonb)
    into v_branches
    from public.branches b
   where b.business_id = v_biz.id and b.is_active;

  -- Opening hours
  select coalesce(jsonb_agg(jsonb_build_object(
           'weekday', h.weekday,
           'open_time', h.open_time,
           'close_time', h.close_time,
           'label_en', h.label_en,
           'label_bn', h.label_bn
         ) order by h.weekday, h.open_time), '[]'::jsonb)
    into v_weekly
    from public.branch_hours h
   where h.branch_id = v_branch.id and h.weekday is not null;

  select coalesce(jsonb_agg(jsonb_build_object(
           'date', h.special_date,
           'end_date', h.special_date_end,
           'is_closed', h.is_closed,
           'open_time', h.open_time,
           'close_time', h.close_time,
           'label_en', h.label_en,
           'label_bn', h.label_bn
         ) order by h.special_date, h.open_time), '[]'::jsonb)
    into v_special
    from public.branch_hours h
   where h.branch_id = v_branch.id
     and h.special_date is not null
     and coalesce(h.special_date_end, h.special_date) >= v_date;

  return jsonb_build_object(
    'generated_at', v_now,
    'is_preview', v_member,
    'business', jsonb_build_object(
      'id', v_biz.id,
      'slug', v_biz.slug,
      'name_en', v_biz.name_en,
      'name_bn', v_biz.name_bn,
      'business_type', v_biz.business_type,
      'logo_url', v_biz.logo_url,
      'cover_url', v_biz.cover_url,
      'phone', v_biz.phone,
      'email', v_biz.email,
      'address', v_biz.address,
      'map_url', v_biz.map_url,
      'description_en', v_biz.description_en,
      'description_bn', v_biz.description_bn,
      'website_url', v_biz.website_url,
      'facebook_url', v_biz.facebook_url,
      'instagram_url', v_biz.instagram_url,
      'tiktok_url', v_biz.tiktok_url,
      'youtube_url', v_biz.youtube_url,
      'whatsapp_number', v_biz.whatsapp_number,
      'currency', v_biz.currency,
      'default_language', v_biz.default_language,
      'timezone', v_biz.timezone,
      'brand_color', v_biz.brand_color,
      'menu_theme', v_biz.menu_theme,
      'menu_layout', v_biz.menu_layout,
      'welcome_message_en', v_biz.welcome_message_en,
      'welcome_message_bn', v_biz.welcome_message_bn,
      'terms_en', v_biz.terms_en,
      'terms_bn', v_biz.terms_bn,
      'refund_policy_en', v_biz.refund_policy_en,
      'refund_policy_bn', v_biz.refund_policy_bn,
      'allergen_notice_en', v_biz.allergen_notice_en,
      'allergen_notice_bn', v_biz.allergen_notice_bn
    ),
    'branch', jsonb_build_object(
      'id', v_branch.id,
      'slug', v_branch.slug,
      'name_en', v_branch.name_en,
      'name_bn', v_branch.name_bn,
      'address', v_branch.address,
      'area', v_branch.area,
      'phone', v_branch.phone,
      'email', v_branch.email,
      'map_url', v_branch.map_url,
      'latitude', v_branch.latitude,
      'longitude', v_branch.longitude,
      'temp_closed_message_en', v_branch.temp_closed_message_en,
      'temp_closed_message_bn', v_branch.temp_closed_message_bn,
      'outside_hours_behavior', v_branch.outside_hours_behavior
    ),
    'branches', v_branches,
    'status', public.branch_status(v_branch.id, v_now),
    'hours', jsonb_build_object('weekly', v_weekly, 'special', v_special),
    'context', jsonb_build_object(
      'kind', v_kind,
      'qr_token', p_qr_token,
      'table_id', v_table.id,
      'table_name', v_table.name
    ),
    'categories', v_categories,
    'items', v_items
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Slug availability
-- ----------------------------------------------------------------------------
create or replace function public.is_business_slug_available(
  p_slug text,
  p_exclude_business uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    and char_length(p_slug) between 3 and 60
    and p_slug <> all (array['www','app','api','admin','dashboard','login','register','menu','m','q',
                             'static','assets','support','help','ezmenu','ez-menu','preview','public'])
    and not exists (
      select 1 from public.businesses b
      where b.slug = p_slug and (p_exclude_business is null or b.id <> p_exclude_business)
    );
$$;

create or replace function public.is_branch_slug_available(
  p_business_id uuid,
  p_slug text,
  p_exclude_branch uuid default null
)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select
    p_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    and char_length(p_slug) between 2 and 60
    and not exists (
      select 1 from public.branches b
      where b.business_id = p_business_id
        and b.slug = p_slug
        and (p_exclude_branch is null or b.id <> p_exclude_branch)
    );
$$;

-- ----------------------------------------------------------------------------
-- Ordering
-- ----------------------------------------------------------------------------
create or replace function public.reorder_menu_categories(p_ids uuid[])
returns void
language sql
security invoker
set search_path = public
as $$
  update public.menu_categories c
     set sort_order = x.ord::int
    from unnest(p_ids) with ordinality as x(id, ord)
   where c.id = x.id;
$$;

create or replace function public.reorder_menu_items(p_ids uuid[])
returns void
language sql
security invoker
set search_path = public
as $$
  update public.menu_items i
     set sort_order = x.ord::int
    from unnest(p_ids) with ordinality as x(id, ord)
   where i.id = x.id;
$$;

-- ----------------------------------------------------------------------------
-- Bulk price changes
--   p_mode   : percent_increase | percent_decrease | fixed_increase |
--              fixed_decrease | set
--   p_target : price | discount | both
--   p_branch_id given -> changes that branch's price override instead of the
--   base price (a branch price replaces BOTH regular and discounted price).
--   A discount is dropped whenever it would no longer be below the price.
-- ----------------------------------------------------------------------------
create or replace function public._adjust_amount(
  p_amount numeric,
  p_mode text,
  p_value numeric,
  p_round_whole boolean
)
returns numeric
language sql
immutable
as $$
  select round(
           greatest(
             0,
             case p_mode
               when 'percent_increase' then p_amount * (1 + p_value / 100)
               when 'percent_decrease' then p_amount * (1 - p_value / 100)
               when 'fixed_increase'   then p_amount + p_value
               when 'fixed_decrease'   then p_amount - p_value
               when 'set'              then p_value
               else p_amount
             end
           ),
           case when p_round_whole then 0 else 2 end
         );
$$;

create or replace function public.bulk_adjust_prices(
  p_item_ids    uuid[],
  p_mode        text,
  p_value       numeric,
  p_target      text default 'price',
  p_round_whole boolean default false,
  p_branch_id   uuid default null
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if p_mode not in ('percent_increase','percent_decrease','fixed_increase','fixed_decrease','set') then
    raise exception 'Invalid price change mode: %', p_mode;
  end if;
  if p_target not in ('price','discount','both') then
    raise exception 'Invalid price target: %', p_target;
  end if;
  if p_value is null or p_value < 0 then
    raise exception 'Value must be zero or greater';
  end if;
  if p_mode = 'set' and p_target = 'discount' and p_branch_id is not null then
    raise exception 'Set a branch price instead of a branch discount only';
  end if;

  if p_branch_id is null then
    with calc as (
      select i.id,
             case when p_target in ('price','both')
                  then public._adjust_amount(i.price, p_mode, p_value, p_round_whole)
                  else i.price end as np,
             case when p_target in ('discount','both') and i.discount_price is not null
                  then public._adjust_amount(i.discount_price, p_mode, p_value, p_round_whole)
                  else i.discount_price end as nd
        from public.menu_items i
       where i.id = any (p_item_ids) and i.deleted_at is null
    )
    update public.menu_items m
       set price = c.np,
           discount_price = case when c.nd is not null and c.nd >= c.np then null else c.nd end
      from calc c
     where m.id = c.id;
    get diagnostics v_count = row_count;
  else
    with src as (
      select i.id as item_id,
             case when bis.price is not null then bis.price else i.price end as cur_price,
             case when bis.price is not null then bis.discount_price else i.discount_price end as cur_discount
        from public.menu_items i
        left join public.branch_item_settings bis
               on bis.item_id = i.id and bis.branch_id = p_branch_id
       where i.id = any (p_item_ids) and i.deleted_at is null
    ),
    calc as (
      select s.item_id,
             case when p_target in ('price','both')
                  then public._adjust_amount(s.cur_price, p_mode, p_value, p_round_whole)
                  else s.cur_price end as np,
             case when p_target in ('discount','both') and s.cur_discount is not null
                  then public._adjust_amount(s.cur_discount, p_mode, p_value, p_round_whole)
                  else s.cur_discount end as nd
        from src s
    )
    insert into public.branch_item_settings (branch_id, item_id, price, discount_price)
    select p_branch_id, c.item_id, c.np,
           case when c.nd is not null and c.nd >= c.np then null else c.nd end
      from calc c
    on conflict (branch_id, item_id) do update
      set price = excluded.price,
          discount_price = excluded.discount_price;
    get diagnostics v_count = row_count;
  end if;

  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- Duplicate / copy
-- ----------------------------------------------------------------------------
create or replace function public._copy_option_groups(p_from_item uuid, p_to_item uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  g record;
  v_new_group uuid;
  v_offset integer;
begin
  select coalesce(max(sort_order), 0) into v_offset
    from public.item_option_groups where item_id = p_to_item;

  for g in
    select * from public.item_option_groups where item_id = p_from_item order by sort_order, created_at
  loop
    insert into public.item_option_groups
      (item_id, name_en, name_bn, select_type, price_mode, is_required, min_select, max_select, sort_order)
    values
      (p_to_item, g.name_en, g.name_bn, g.select_type, g.price_mode, g.is_required,
       g.min_select, g.max_select, v_offset + g.sort_order + 1)
    returning id into v_new_group;

    insert into public.item_options
      (group_id, name_en, name_bn, price, discount_price, image_url, is_default, is_available, sort_order)
    select v_new_group, o.name_en, o.name_bn, o.price, o.discount_price, o.image_url,
           o.is_default, o.is_available, o.sort_order
      from public.item_options o
     where o.group_id = g.id;
  end loop;
end;
$$;

create or replace function public.copy_option_groups(p_from_item uuid, p_to_item uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_from_item = p_to_item then
    raise exception 'Choose a different item to copy from';
  end if;
  if not exists (select 1 from public.menu_items where id = p_from_item and deleted_at is null)
     or not exists (select 1 from public.menu_items where id = p_to_item and deleted_at is null) then
    raise exception 'Item not found';
  end if;
  perform public._copy_option_groups(p_from_item, p_to_item);
end;
$$;

create or replace function public._duplicate_item_into(
  p_item_id uuid,
  p_category_id uuid,
  p_mark_copy boolean
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_new uuid;
  v_sort integer;
begin
  select coalesce(max(sort_order), 0) + 1 into v_sort
    from public.menu_items where category_id = p_category_id and deleted_at is null;

  insert into public.menu_items (
    business_id, category_id, name_en, name_bn,
    short_description_en, short_description_bn, description_en, description_bn,
    ingredients_en, ingredients_bn, price, discount_price, prep_time_min, sku,
    labels, allergens, allergen_note, dietary_info, spice_level, calories, nutrition,
    image_urls, is_active, is_featured, is_sold_out, sold_out_until, sort_order
  )
  select
    i.business_id, p_category_id,
    case when p_mark_copy and i.name_en is not null then left(i.name_en, 150) || ' (Copy)' else i.name_en end,
    case when p_mark_copy and i.name_bn is not null then left(i.name_bn, 150) || ' (কপি)' else i.name_bn end,
    i.short_description_en, i.short_description_bn, i.description_en, i.description_bn,
    i.ingredients_en, i.ingredients_bn, i.price, i.discount_price, i.prep_time_min, null,
    i.labels, i.allergens, i.allergen_note, i.dietary_info, i.spice_level, i.calories, i.nutrition,
    i.image_urls, i.is_active, i.is_featured, i.is_sold_out, i.sold_out_until, v_sort
  from public.menu_items i
  where i.id = p_item_id and i.deleted_at is null
  returning id into v_new;

  if v_new is null then
    raise exception 'Item not found';
  end if;

  insert into public.item_schedules (item_id, weekdays, start_time, end_time, start_date, end_date, label)
  select v_new, s.weekdays, s.start_time, s.end_time, s.start_date, s.end_date, s.label
    from public.item_schedules s where s.item_id = p_item_id;

  perform public._copy_option_groups(p_item_id, v_new);
  return v_new;
end;
$$;

create or replace function public.duplicate_menu_item(p_item_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_category uuid;
begin
  select category_id into v_category from public.menu_items where id = p_item_id and deleted_at is null;
  if v_category is null then
    raise exception 'Item not found';
  end if;
  return public._duplicate_item_into(p_item_id, v_category, true);
end;
$$;

create or replace function public._duplicate_category_row(
  p_category_id uuid,
  p_parent_id uuid,
  p_include_items boolean
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_new uuid;
  v_sort integer;
  v_item record;
begin
  select coalesce(max(sort_order), 0) + 1 into v_sort
    from public.menu_categories
   where business_id = (select business_id from public.menu_categories where id = p_category_id)
     and parent_id is not distinct from p_parent_id
     and deleted_at is null;

  insert into public.menu_categories
    (business_id, parent_id, name_en, name_bn, description_en, description_bn,
     image_url, icon, sort_order, is_active)
  select c.business_id, p_parent_id,
         case when c.name_en is not null then left(c.name_en, 110) || ' (Copy)' else null end,
         case when c.name_bn is not null then left(c.name_bn, 110) || ' (কপি)' else null end,
         c.description_en, c.description_bn, c.image_url, c.icon, v_sort, c.is_active
    from public.menu_categories c
   where c.id = p_category_id and c.deleted_at is null
  returning id into v_new;

  if v_new is null then
    raise exception 'Category not found';
  end if;

  if p_include_items then
    for v_item in
      select id from public.menu_items
       where category_id = p_category_id and deleted_at is null
       order by sort_order, created_at
    loop
      perform public._duplicate_item_into(v_item.id, v_new, false);
    end loop;
  end if;
  return v_new;
end;
$$;

create or replace function public.duplicate_menu_category(
  p_category_id uuid,
  p_include_items boolean default true
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_parent uuid;
  v_new uuid;
  v_child record;
  v_new_child uuid;
begin
  select parent_id into v_parent from public.menu_categories where id = p_category_id and deleted_at is null;
  if not found then
    raise exception 'Category not found';
  end if;

  v_new := public._duplicate_category_row(p_category_id, v_parent, p_include_items);

  -- Subcategories come along when the category is a top-level one.
  if v_parent is null then
    for v_child in
      select id from public.menu_categories
       where parent_id = p_category_id and deleted_at is null
       order by sort_order, created_at
    loop
      v_new_child := public._duplicate_category_row(v_child.id, v_new, p_include_items);
      -- Children keep their own names (no "Copy" suffix under a copied parent).
      update public.menu_categories c
         set name_en = o.name_en, name_bn = o.name_bn
        from public.menu_categories o
       where c.id = v_new_child and o.id = v_child.id;
    end loop;
  end if;
  return v_new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Trash (soft delete) with recovery
-- ----------------------------------------------------------------------------
create or replace function public.soft_delete_category(p_category_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  if not exists (select 1 from public.menu_categories where id = p_category_id and deleted_at is null) then
    raise exception 'Category not found';
  end if;

  update public.menu_items
     set deleted_at = v_now
   where deleted_at is null
     and category_id in (
       select id from public.menu_categories
        where id = p_category_id or parent_id = p_category_id
     );

  update public.menu_categories
     set deleted_at = v_now
   where deleted_at is null
     and (id = p_category_id or parent_id = p_category_id);
end;
$$;

create or replace function public.restore_category(p_category_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_ts timestamptz;
  v_parent uuid;
  v_parent_deleted timestamptz;
begin
  select deleted_at, parent_id into v_ts, v_parent
    from public.menu_categories where id = p_category_id;
  if v_ts is null then
    return;
  end if;

  if v_parent is not null then
    select deleted_at into v_parent_deleted from public.menu_categories where id = v_parent;
    if v_parent_deleted is not null then
      raise exception 'Restore the parent category first';
    end if;
  end if;

  update public.menu_items
     set deleted_at = null
   where deleted_at = v_ts
     and category_id in (
       select id from public.menu_categories
        where id = p_category_id or (parent_id = p_category_id and deleted_at = v_ts)
     );

  update public.menu_categories
     set deleted_at = null
   where (id = p_category_id or (parent_id = p_category_id and deleted_at = v_ts));
end;
$$;

create or replace function public.restore_menu_item(p_item_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_cat_deleted timestamptz;
  v_cat uuid;
begin
  select category_id into v_cat from public.menu_items where id = p_item_id;
  if v_cat is null then
    raise exception 'Item not found';
  end if;
  select deleted_at into v_cat_deleted from public.menu_categories where id = v_cat;
  if v_cat_deleted is not null then
    raise exception 'Restore the category first';
  end if;
  update public.menu_items set deleted_at = null where id = p_item_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- CSV / spreadsheet import
--   p_rows: array of objects (the app parses and validates the file):
--     category_en, category_bn, name_en, name_bn, short_description_en,
--     short_description_bn, description_en, description_bn, price,
--     discount_price, prep_time_min, sku, labels (array), is_sold_out,
--     is_active, is_featured
--   Categories are matched by name (created when missing). Items are matched by
--   SKU when given, otherwise by name inside the category.
--   Returns { created, updated, skipped, errors: [{row, message}] }.
-- ----------------------------------------------------------------------------
create or replace function public.import_menu_items(
  p_business_id uuid,
  p_rows jsonb,
  p_update_existing boolean default true
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row        jsonb;
  v_idx        integer := 0;
  v_created    integer := 0;
  v_updated    integer := 0;
  v_skipped    integer := 0;
  v_errors     jsonb := '[]'::jsonb;
  v_cat_id     uuid;
  v_item_id    uuid;
  v_cat_en     text;
  v_cat_bn     text;
  v_name_en    text;
  v_name_bn    text;
  v_sku        text;
  v_price      numeric;
  v_discount   numeric;
  v_labels     text[];
  v_sort       integer;
  v_allowed    text[] := array['vegetarian','vegan','spicy','popular','chefs_special',
                               'new','recommended','halal','gluten_free','dairy_free'];
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'Rows must be an array';
  end if;
  if jsonb_array_length(p_rows) > 1000 then
    raise exception 'Import at most 1000 rows at a time';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_idx := v_idx + 1;
    begin
      v_cat_en  := nullif(btrim(v_row ->> 'category_en'), '');
      v_cat_bn  := nullif(btrim(v_row ->> 'category_bn'), '');
      v_name_en := nullif(btrim(v_row ->> 'name_en'), '');
      v_name_bn := nullif(btrim(v_row ->> 'name_bn'), '');
      v_sku     := nullif(btrim(v_row ->> 'sku'), '');
      v_price   := coalesce(nullif(btrim(v_row ->> 'price'), '')::numeric, 0);
      v_discount := nullif(btrim(v_row ->> 'discount_price'), '')::numeric;

      if v_name_en is null and v_name_bn is null then
        raise exception 'Item name is required';
      end if;
      if v_cat_en is null and v_cat_bn is null then
        raise exception 'Category is required';
      end if;
      if v_price < 0 then
        raise exception 'Price cannot be negative';
      end if;
      if v_discount is not null and v_discount > v_price then
        raise exception 'Discount price must not exceed the price';
      end if;

      v_labels := array(
        select l from jsonb_array_elements_text(
          case when jsonb_typeof(v_row -> 'labels') = 'array' then v_row -> 'labels' else '[]'::jsonb end
        ) l
        where l = any (v_allowed)
      );

      -- Category: match by name, else create.
      select c.id into v_cat_id
        from public.menu_categories c
       where c.business_id = p_business_id
         and c.parent_id is null
         and c.deleted_at is null
         and (
           (v_cat_en is not null and lower(c.name_en) = lower(v_cat_en))
           or (v_cat_bn is not null and c.name_bn = v_cat_bn)
         )
       order by c.created_at
       limit 1;

      if v_cat_id is null then
        select coalesce(max(sort_order), 0) + 1 into v_sort
          from public.menu_categories
         where business_id = p_business_id and parent_id is null and deleted_at is null;
        insert into public.menu_categories (business_id, name_en, name_bn, sort_order)
        values (p_business_id, v_cat_en, v_cat_bn, v_sort)
        returning id into v_cat_id;
      end if;

      -- Existing item: by SKU first, else by name within the category.
      v_item_id := null;
      if v_sku is not null then
        select i.id into v_item_id
          from public.menu_items i
         where i.business_id = p_business_id and i.sku = v_sku and i.deleted_at is null
         limit 1;
      end if;
      if v_item_id is null then
        select i.id into v_item_id
          from public.menu_items i
         where i.business_id = p_business_id
           and i.category_id = v_cat_id
           and i.deleted_at is null
           and (
             (v_name_en is not null and lower(i.name_en) = lower(v_name_en))
             or (v_name_bn is not null and i.name_bn = v_name_bn)
           )
         limit 1;
      end if;

      if v_item_id is not null then
        if p_update_existing then
          update public.menu_items
             set category_id = v_cat_id,
                 name_en = coalesce(v_name_en, name_en),
                 name_bn = coalesce(v_name_bn, name_bn),
                 short_description_en = coalesce(nullif(btrim(v_row ->> 'short_description_en'), ''), short_description_en),
                 short_description_bn = coalesce(nullif(btrim(v_row ->> 'short_description_bn'), ''), short_description_bn),
                 description_en = coalesce(nullif(btrim(v_row ->> 'description_en'), ''), description_en),
                 description_bn = coalesce(nullif(btrim(v_row ->> 'description_bn'), ''), description_bn),
                 price = v_price,
                 discount_price = v_discount,
                 prep_time_min = coalesce(nullif(btrim(v_row ->> 'prep_time_min'), '')::smallint, prep_time_min),
                 sku = coalesce(v_sku, sku),
                 labels = case when jsonb_typeof(v_row -> 'labels') = 'array' then v_labels else labels end,
                 is_sold_out = coalesce((v_row ->> 'is_sold_out')::boolean, is_sold_out),
                 is_active = coalesce((v_row ->> 'is_active')::boolean, is_active),
                 is_featured = coalesce((v_row ->> 'is_featured')::boolean, is_featured)
           where id = v_item_id;
          v_updated := v_updated + 1;
        else
          v_skipped := v_skipped + 1;
        end if;
      else
        select coalesce(max(sort_order), 0) + 1 into v_sort
          from public.menu_items where category_id = v_cat_id and deleted_at is null;
        insert into public.menu_items (
          business_id, category_id, name_en, name_bn,
          short_description_en, short_description_bn, description_en, description_bn,
          price, discount_price, prep_time_min, sku, labels,
          is_sold_out, is_active, is_featured, sort_order
        ) values (
          p_business_id, v_cat_id, v_name_en, v_name_bn,
          nullif(btrim(v_row ->> 'short_description_en'), ''),
          nullif(btrim(v_row ->> 'short_description_bn'), ''),
          nullif(btrim(v_row ->> 'description_en'), ''),
          nullif(btrim(v_row ->> 'description_bn'), ''),
          v_price, v_discount,
          nullif(btrim(v_row ->> 'prep_time_min'), '')::smallint,
          v_sku, v_labels,
          coalesce((v_row ->> 'is_sold_out')::boolean, false),
          coalesce((v_row ->> 'is_active')::boolean, true),
          coalesce((v_row ->> 'is_featured')::boolean, false),
          v_sort
        );
        v_created := v_created + 1;
      end if;
    exception when others then
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('row', v_idx, 'message', sqlerrm)
      );
    end;
  end loop;

  return jsonb_build_object(
    'created', v_created,
    'updated', v_updated,
    'skipped', v_skipped,
    'errors', v_errors
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- QR codes
-- ----------------------------------------------------------------------------
create or replace function public.create_qr_code(
  p_branch_id uuid,
  p_kind text,
  p_table_id uuid default null,
  p_label text default null
)
returns public.qr_codes
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.qr_codes;
begin
  if p_kind not in ('branch','table','takeaway') then
    raise exception 'Invalid QR kind';
  end if;
  if p_kind = 'table' and p_table_id is null then
    raise exception 'A table is required for a table QR code';
  end if;
  insert into public.qr_codes (business_id, branch_id, table_id, kind, label)
  values (public.business_of_branch(p_branch_id), p_branch_id,
          case when p_kind = 'table' then p_table_id else null end,
          p_kind, p_label)
  returning * into v_row;
  return v_row;
end;
$$;

-- Replace a QR code: the old token stops working, a new one takes its place.
create or replace function public.regenerate_qr_code(p_qr_id uuid)
returns public.qr_codes
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_old public.qr_codes;
  v_new public.qr_codes;
begin
  select * into v_old from public.qr_codes where id = p_qr_id;
  if not found then
    raise exception 'QR code not found';
  end if;

  update public.qr_codes
     set is_active = false, deactivated_at = now()
   where id = p_qr_id and is_active;

  insert into public.qr_codes (business_id, branch_id, table_id, kind, label)
  values (v_old.business_id, v_old.branch_id, v_old.table_id, v_old.kind, v_old.label)
  returning * into v_new;
  return v_new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Dashboard numbers for Home
-- ----------------------------------------------------------------------------
create or replace function public.get_menu_stats(p_business_id uuid, p_branch_id uuid default null)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'categories', (select count(*) from public.menu_categories
                    where business_id = p_business_id and deleted_at is null),
    'items', (select count(*) from public.menu_items
               where business_id = p_business_id and deleted_at is null),
    'visible_items', (select count(*) from public.menu_items
                       where business_id = p_business_id and deleted_at is null and is_active),
    'sold_out_items', (
      select count(*) from public.menu_items i
       where i.business_id = p_business_id and i.deleted_at is null
         and (
           (i.is_sold_out and (i.sold_out_until is null or i.sold_out_until > now()))
           or exists (
             select 1 from public.branch_item_settings s
              where s.item_id = i.id and p_branch_id is not null and s.branch_id = p_branch_id
                and s.is_sold_out and (s.sold_out_until is null or s.sold_out_until > now())
           )
         )
    ),
    'items_without_image', (select count(*) from public.menu_items
                             where business_id = p_business_id and deleted_at is null
                               and cardinality(image_urls) = 0),
    'branches', (select count(*) from public.branches where business_id = p_business_id and is_active),
    'tables', (select count(*) from public.restaurant_tables t
                join public.branches b on b.id = t.branch_id
               where b.business_id = p_business_id and t.is_active
                 and (p_branch_id is null or t.branch_id = p_branch_id)),
    'qr_scans', (select coalesce(sum(scan_count), 0) from public.qr_codes
                  where business_id = p_business_id
                    and (p_branch_id is null or branch_id = p_branch_id)),
    'trash', (
      (select count(*) from public.menu_items where business_id = p_business_id and deleted_at is not null)
      + (select count(*) from public.menu_categories where business_id = p_business_id and deleted_at is not null)
    )
  );
$$;

-- ----------------------------------------------------------------------------
-- Sample menu (optional, from onboarding)
-- ----------------------------------------------------------------------------
create or replace function public.seed_sample_menu(p_business_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_starters uuid;
  v_rice uuid;
  v_burgers uuid;
  v_drinks uuid;
  v_desserts uuid;
  v_burger uuid;
  v_size uuid;
  v_extras uuid;
  v_base integer;
begin
  select coalesce(max(sort_order), 0) into v_base
    from public.menu_categories where business_id = p_business_id and parent_id is null and deleted_at is null;

  insert into public.menu_categories (business_id, name_en, name_bn, icon, sort_order)
  values (p_business_id, 'Starters', 'স্টার্টার', 'tapas', v_base + 1) returning id into v_starters;
  insert into public.menu_categories (business_id, name_en, name_bn, icon, sort_order)
  values (p_business_id, 'Rice & Curry', 'ভাত ও তরকারি', 'rice_bowl', v_base + 2) returning id into v_rice;
  insert into public.menu_categories (business_id, name_en, name_bn, icon, sort_order)
  values (p_business_id, 'Burgers', 'বার্গার', 'lunch_dining', v_base + 3) returning id into v_burgers;
  insert into public.menu_categories (business_id, name_en, name_bn, icon, sort_order)
  values (p_business_id, 'Drinks', 'পানীয়', 'local_cafe', v_base + 4) returning id into v_drinks;
  insert into public.menu_categories (business_id, name_en, name_bn, icon, sort_order)
  values (p_business_id, 'Desserts', 'ডেজার্ট', 'icecream', v_base + 5) returning id into v_desserts;

  insert into public.menu_items
    (business_id, category_id, name_en, name_bn, short_description_en, short_description_bn,
     price, discount_price, prep_time_min, labels, allergens, sort_order)
  values
    (p_business_id, v_starters, 'Crispy Chicken Wings (8 pcs)', 'ক্রিস্পি চিকেন উইংস (৮ পিস)',
     'Golden fried wings with house dip', 'বিশেষ ডিপসহ গোল্ডেন ফ্রাইড উইংস', 320, 290, 15, array['popular'], array['gluten'], 1),
    (p_business_id, v_starters, 'French Fries', 'ফ্রেঞ্চ ফ্রাইজ',
     'Salted and crispy', 'লবণ মাখানো কচকচে ফ্রাইজ', 160, null, 10, array['vegetarian'], array[]::text[], 2),
    (p_business_id, v_rice, 'Kacchi Biryani', 'কাচ্চি বিরিয়ানি',
     'Slow-cooked mutton and fragrant rice', 'ধীরে রান্না করা খাসির মাংস ও সুগন্ধি চাল', 380, null, 20, array['popular','spicy','halal'], array['milk'], 1),
    (p_business_id, v_rice, 'Chicken Roast with Polao', 'চিকেন রোস্ট ও পোলাও',
     'Sweet-savoury roast with buttery polao', 'মিষ্টি-ঝাল রোস্ট ও ঘিয়ে ভাজা পোলাও', 280, null, 20, array['halal'], array['milk'], 2),
    (p_business_id, v_rice, 'Beef Tehari', 'বিফ তেহারি',
     'Mustard-oil tehari with tender beef', 'সরিষার তেলে রান্না কোমল গরুর মাংসের তেহারি', 260, null, 15, array['spicy','halal'], array['mustard'], 3),
    (p_business_id, v_drinks, 'Mango Lassi', 'ম্যাংগো লাচ্ছি',
     'Chilled yogurt and ripe mango', 'ঠান্ডা দই ও পাকা আমের লাচ্ছি', 120, null, 5, array['vegetarian','new'], array['milk'], 1),
    (p_business_id, v_drinks, 'Borhani', 'বোরহানি',
     'Spiced yogurt drink', 'মসলাদার দইয়ের পানীয়', 80, null, 3, array['halal'], array['milk'], 2),
    (p_business_id, v_desserts, 'Firni', 'ফিরনি',
     'Creamy rice pudding with pistachio', 'পেস্তা দিয়ে ক্রিমি চালের পুডিং', 90, null, 5, array['vegetarian'], array['milk','tree_nuts'], 1),
    (p_business_id, v_desserts, 'Gulab Jamun (2 pcs)', 'গোলাপ জামুন (২ পিস)',
     'Warm syrup-soaked dumplings', 'গরম সিরাপে ভেজানো গোলাপ জামুন', 100, null, 5, array['vegetarian'], array['milk','gluten'], 2);

  insert into public.menu_items
    (business_id, category_id, name_en, name_bn, short_description_en, short_description_bn,
     description_en, description_bn, price, prep_time_min, labels, allergens, is_featured, sort_order)
  values
    (p_business_id, v_burgers, 'Classic Beef Burger', 'ক্লাসিক বিফ বার্গার',
     'Grilled patty, cheese, house sauce', 'গ্রিল করা প্যাটি, চিজ ও হাউস সস',
     'A juicy grilled beef patty with melted cheese, lettuce, tomato and our house sauce in a toasted bun.',
     'রসালো গ্রিলড বিফ প্যাটি, গলানো চিজ, লেটুস, টমেটো ও হাউস সস— টোস্ট করা বানে।',
     350, 15, array['popular','chefs_special'], array['gluten','milk','eggs','sesame'], true, 1)
  returning id into v_burger;

  insert into public.item_option_groups
    (item_id, name_en, name_bn, select_type, price_mode, is_required, min_select, max_select, sort_order)
  values (v_burger, 'Size', 'সাইজ', 'single', 'absolute', true, 1, 1, 1)
  returning id into v_size;
  insert into public.item_options (group_id, name_en, name_bn, price, is_default, sort_order)
  values (v_size, 'Regular', 'রেগুলার', 350, true, 1),
         (v_size, 'Large', 'লার্জ', 450, false, 2);

  insert into public.item_option_groups
    (item_id, name_en, name_bn, select_type, price_mode, is_required, min_select, max_select, sort_order)
  values (v_burger, 'Extras', 'এক্সট্রা', 'multiple', 'additional', false, 0, 3, 2)
  returning id into v_extras;
  insert into public.item_options (group_id, name_en, name_bn, price, sort_order)
  values (v_extras, 'Extra Cheese', 'এক্সট্রা চিজ', 40, 1),
         (v_extras, 'Fried Egg', 'ডিম ভাজা', 20, 2),
         (v_extras, 'Bacon', 'বেকন', 80, 3);
end;
$$;

-- ----------------------------------------------------------------------------
-- Grants
--   Supabase grants EXECUTE on new functions to anon/authenticated by default;
--   tighten that explicitly. Later migrations must do the same for their own
--   functions.
-- ----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant  execute on all functions in schema public to authenticated;

-- Internal helpers only ever called from SECURITY DEFINER functions.
revoke execute on function public.branch_periods_for(uuid, date)            from authenticated;
revoke execute on function public.visible_menu_categories(uuid, uuid)       from authenticated;
revoke execute on function public.item_in_schedule(uuid, date, time)        from authenticated;

-- The customer menu is public.
grant execute on function public.get_public_menu(text, text, text, boolean) to anon, authenticated;
grant execute on function public.branch_status(uuid, timestamptz)           to anon, authenticated;
