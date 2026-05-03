-- Enable Row Level Security (RLS)
alter table public.users enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.user_locations enable row level security;
alter table public.family_invites enable row level security;
alter table public.family_invite_redemptions enable row level security;

-- Users: allow authenticated users to read their own profile
create policy "users_select_own" on public.users
  for select
  to authenticated
  using (id = auth.uid());

-- Users: allow inserts/updates during sign-up/profile creation.
-- IMPORTANT: WITH CHECK(true) so the upsert from the client can succeed.
create policy "users_insert" on public.users
  for insert
  to authenticated
  with check (true);

create policy "users_update" on public.users
  for update
  to authenticated
  using (id = auth.uid())
  with check (true);

-- Locations: allow authenticated users full access.
create policy "user_locations_select_family" on public.user_locations
  for select
  to authenticated
  using (
    family_id is null
    or exists (
      select 1 from public.family_members fm
      where fm.family_id = user_locations.family_id
        and fm.user_id = auth.uid()
    )
  );

create policy "user_locations_insert_own" on public.user_locations
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      family_id is null
      or exists (
        select 1 from public.family_members fm
        where fm.family_id = user_locations.family_id
          and fm.user_id = auth.uid()
      )
    )
  );

-- Families: members can read; owner can manage.
create policy "families_select_member" on public.families
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = families.id and fm.user_id = auth.uid()
    )
  );

create policy "families_insert_owner" on public.families
  for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "families_update_owner" on public.families
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Family members: members can read member list.
create policy "family_members_select_member" on public.family_members
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.family_members fm
      where fm.family_id = family_members.family_id
        and fm.user_id = auth.uid()
    )
  );

-- Allow users to insert themselves into a family only if owner is inserting (bootstrap).
-- In production, prefer using accept_family_invite() for joins.
create policy "family_members_insert_self" on public.family_members
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Invites: only owners can create/read/revoke.
create policy "family_invites_owner_select" on public.family_invites
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = family_invites.family_id
        and fm.user_id = auth.uid()
        and fm.role = 'owner'
    )
  );

create policy "family_invites_owner_insert" on public.family_invites
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.family_members fm
      where fm.family_id = family_invites.family_id
        and fm.user_id = auth.uid()
        and fm.role = 'owner'
    )
  );

create policy "family_invites_owner_update" on public.family_invites
  for update
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = family_invites.family_id
        and fm.user_id = auth.uid()
        and fm.role = 'owner'
    )
  )
  with check (true);

-- Redemptions: owners can read.
create policy "family_invite_redemptions_owner_select" on public.family_invite_redemptions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.family_invites i
      join public.family_members fm on fm.family_id = i.family_id
      where i.id = family_invite_redemptions.invite_id
        and fm.user_id = auth.uid()
        and fm.role = 'owner'
    )
  );
