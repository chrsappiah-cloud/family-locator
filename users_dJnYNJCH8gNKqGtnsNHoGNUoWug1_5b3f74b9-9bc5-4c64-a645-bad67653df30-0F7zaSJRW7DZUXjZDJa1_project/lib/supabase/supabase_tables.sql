-- Initial schema for Family Cockpit (Supabase)

-- Extensions
create extension if not exists pgcrypto;

-- User profiles (1:1 with auth.users)
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  active_family_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Families
create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.users
  add constraint if not exists users_active_family_fk
  foreign key (active_family_id) references public.families(id) on delete set null;

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists idx_family_members_user_id on public.family_members (user_id);

-- Latest location samples for each user (append-only)
create table if not exists public.user_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  family_id uuid,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  heading_deg double precision,
  speed_mps double precision,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_locations
  add constraint if not exists user_locations_family_fk
  foreign key (family_id) references public.families(id) on delete set null;

create index if not exists idx_user_locations_user_id_recorded_at
  on public.user_locations (user_id, recorded_at desc);

create index if not exists idx_user_locations_family_id_recorded_at
  on public.user_locations (family_id, recorded_at desc);

-- Invites (codes and/or email-targeted)
create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete cascade,
  code text not null,
  email text,
  role text not null default 'member',
  expires_at timestamptz,
  max_uses int not null default 1,
  uses_count int not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint family_invites_code_unique unique (code)
);

create index if not exists idx_family_invites_family_id on public.family_invites (family_id, created_at desc);
create index if not exists idx_family_invites_email on public.family_invites (email);

create table if not exists public.family_invite_redemptions (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.family_invites(id) on delete cascade,
  redeemed_by uuid not null references public.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  constraint family_invite_redemptions_unique unique (invite_id, redeemed_by)
);

-- Secure redemption function (atomic-ish server-side logic)
create or replace function public.accept_family_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.family_invites%rowtype;
  v_uid uuid;
  v_already_member boolean;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_invite
  from public.family_invites
  where code = upper(trim(p_code))
    and revoked_at is null
    and (expires_at is null or expires_at > now())
    and uses_count < max_uses
  limit 1;

  if not found then
    raise exception 'invalid_or_expired_invite';
  end if;

  select exists(
    select 1 from public.family_members
    where family_id = v_invite.family_id and user_id = v_uid
  ) into v_already_member;

  if not v_already_member then
    insert into public.family_members (family_id, user_id, role)
    values (v_invite.family_id, v_uid, v_invite.role)
    on conflict do nothing;

    update public.family_invites
      set uses_count = uses_count + 1,
          updated_at = now()
      where id = v_invite.id;

    insert into public.family_invite_redemptions (invite_id, redeemed_by)
    values (v_invite.id, v_uid)
    on conflict do nothing;
  end if;

  update public.users set active_family_id = v_invite.family_id, updated_at = now()
    where id = v_uid;

  return v_invite.family_id;
end;
$$;

revoke all on function public.accept_family_invite(text) from public;
grant execute on function public.accept_family_invite(text) to authenticated;
