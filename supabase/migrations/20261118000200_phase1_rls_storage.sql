-- =============================================================================
-- EZ Menu - Phase 1: Row Level Security, storage buckets and grants
--
-- Access model
--   * Dashboard users reach their business data directly through PostgREST,
--     limited by the policies below (membership + role).
--   * Anonymous visitors (customers) get NO direct table access. They use the
--     get_public_menu() RPC, which returns only publishable fields.
-- =============================================================================

-- Lock everything down first; policies then open exactly what is needed.
alter table public.profiles                enable row level security;
alter table public.businesses              enable row level security;
alter table public.business_members        enable row level security;
alter table public.branches                enable row level security;
alter table public.branch_hours            enable row level security;
alter table public.menu_categories         enable row level security;
alter table public.menu_items              enable row level security;
alter table public.item_schedules          enable row level security;
alter table public.item_option_groups      enable row level security;
alter table public.item_options            enable row level security;
alter table public.branch_category_settings enable row level security;
alter table public.branch_item_settings    enable row level security;
alter table public.restaurant_tables       enable row level security;
alter table public.qr_codes                enable row level security;

revoke all on all tables in schema public from anon;

-- ----------------------------------------------------------------------------
-- profiles: each user manages their own row
-- ----------------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ----------------------------------------------------------------------------
-- businesses
-- ----------------------------------------------------------------------------
-- owner_id is checked as well because INSERT ... RETURNING evaluates this policy
-- before the AFTER INSERT trigger has created the owner membership row.
create policy businesses_select_member on public.businesses
  for select to authenticated
  using (owner_id = auth.uid() or public.is_business_member(id));
create policy businesses_insert_owner on public.businesses
  for insert to authenticated with check (owner_id = auth.uid());
create policy businesses_update_managers on public.businesses
  for update to authenticated
  using (public.can_manage_business(id))
  with check (public.can_manage_business(id));
-- Deleting a business is intentionally not allowed from the client in Phase 1.

-- ----------------------------------------------------------------------------
-- business_members: read-only from the client (staff invites arrive in Phase 3)
-- ----------------------------------------------------------------------------
create policy business_members_select on public.business_members
  for select to authenticated
  using (user_id = auth.uid() or public.can_manage_business(business_id));

-- ----------------------------------------------------------------------------
-- branches
-- ----------------------------------------------------------------------------
create policy branches_select_member on public.branches
  for select to authenticated using (public.is_business_member(business_id));
create policy branches_insert_managers on public.branches
  for insert to authenticated with check (public.can_manage_business(business_id));
create policy branches_update_managers on public.branches
  for update to authenticated
  using (public.can_manage_business(business_id))
  with check (public.can_manage_business(business_id));
create policy branches_delete_managers on public.branches
  for delete to authenticated using (public.can_manage_business(business_id));

-- ----------------------------------------------------------------------------
-- branch_hours
-- ----------------------------------------------------------------------------
create policy branch_hours_select on public.branch_hours
  for select to authenticated
  using (public.is_business_member(public.business_of_branch(branch_id)));
create policy branch_hours_write on public.branch_hours
  for all to authenticated
  using (public.can_manage_operations(public.business_of_branch(branch_id)))
  with check (public.can_manage_operations(public.business_of_branch(branch_id)));

-- ----------------------------------------------------------------------------
-- menu_categories / menu_items
-- ----------------------------------------------------------------------------
create policy menu_categories_select on public.menu_categories
  for select to authenticated using (public.is_business_member(business_id));
create policy menu_categories_write on public.menu_categories
  for all to authenticated
  using (public.can_manage_operations(business_id))
  with check (public.can_manage_operations(business_id));

create policy menu_items_select on public.menu_items
  for select to authenticated using (public.is_business_member(business_id));
create policy menu_items_write on public.menu_items
  for all to authenticated
  using (public.can_manage_operations(business_id))
  with check (public.can_manage_operations(business_id));

-- ----------------------------------------------------------------------------
-- item_schedules / option groups / options
-- ----------------------------------------------------------------------------
create policy item_schedules_select on public.item_schedules
  for select to authenticated
  using (public.is_business_member(public.business_of_item(item_id)));
create policy item_schedules_write on public.item_schedules
  for all to authenticated
  using (public.can_manage_operations(public.business_of_item(item_id)))
  with check (public.can_manage_operations(public.business_of_item(item_id)));

create policy item_option_groups_select on public.item_option_groups
  for select to authenticated
  using (public.is_business_member(public.business_of_item(item_id)));
create policy item_option_groups_write on public.item_option_groups
  for all to authenticated
  using (public.can_manage_operations(public.business_of_item(item_id)))
  with check (public.can_manage_operations(public.business_of_item(item_id)));

create policy item_options_select on public.item_options
  for select to authenticated
  using (public.is_business_member(public.business_of_group(group_id)));
create policy item_options_write on public.item_options
  for all to authenticated
  using (public.can_manage_operations(public.business_of_group(group_id)))
  with check (public.can_manage_operations(public.business_of_group(group_id)));

-- ----------------------------------------------------------------------------
-- per-branch overrides
-- ----------------------------------------------------------------------------
create policy branch_category_settings_select on public.branch_category_settings
  for select to authenticated
  using (public.is_business_member(public.business_of_branch(branch_id)));
create policy branch_category_settings_write on public.branch_category_settings
  for all to authenticated
  using (public.can_manage_operations(public.business_of_branch(branch_id)))
  with check (public.can_manage_operations(public.business_of_branch(branch_id)));

create policy branch_item_settings_select on public.branch_item_settings
  for select to authenticated
  using (public.is_business_member(public.business_of_branch(branch_id)));
create policy branch_item_settings_write on public.branch_item_settings
  for all to authenticated
  using (public.can_manage_operations(public.business_of_branch(branch_id)))
  with check (public.can_manage_operations(public.business_of_branch(branch_id)));

-- ----------------------------------------------------------------------------
-- tables and QR codes
-- ----------------------------------------------------------------------------
create policy restaurant_tables_select on public.restaurant_tables
  for select to authenticated
  using (public.is_business_member(public.business_of_branch(branch_id)));
create policy restaurant_tables_write on public.restaurant_tables
  for all to authenticated
  using (public.can_manage_operations(public.business_of_branch(branch_id)))
  with check (public.can_manage_operations(public.business_of_branch(branch_id)));

create policy qr_codes_select on public.qr_codes
  for select to authenticated using (public.is_business_member(business_id));
create policy qr_codes_write on public.qr_codes
  for all to authenticated
  using (public.can_manage_operations(business_id))
  with check (public.can_manage_operations(business_id));

-- ----------------------------------------------------------------------------
-- Storage
--   brand-assets : logos and cover images
--   menu-images  : category, item and variant images
--   Public read (images appear on the public menu). Writes are limited to
--   members who can manage operations, and only inside "<business_id>/...".
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('brand-assets', 'brand-assets', true, 5242880,
   array['image/jpeg','image/png','image/webp']),
  ('menu-images',  'menu-images',  true, 5242880,
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "ez_images_public_read" on storage.objects
  for select
  using (bucket_id in ('brand-assets', 'menu-images'));

create policy "ez_images_member_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('brand-assets', 'menu-images')
    and public.can_manage_operations(((storage.foldername(name))[1])::uuid)
  );

create policy "ez_images_member_update" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('brand-assets', 'menu-images')
    and public.can_manage_operations(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id in ('brand-assets', 'menu-images')
    and public.can_manage_operations(((storage.foldername(name))[1])::uuid)
  );

create policy "ez_images_member_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('brand-assets', 'menu-images')
    and public.can_manage_operations(((storage.foldername(name))[1])::uuid)
  );
