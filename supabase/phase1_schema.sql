-- BUSI Phase 1 shared database schema for Supabase
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique,
  full_name text not null,
  email text unique not null,
  role text not null check (role in ('founder', 'coordinator', 'volunteer', 'viewer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  case_number text unique not null,
  person_name text,
  contact_email text,
  contact_phone text,
  city text not null,
  need_type text not null,
  request_notes text,
  status text not null default 'Pending Review' check (status in ('Pending Review', 'Approved', 'In Progress', 'Completed', 'Pending', 'Active', 'On Hold')),
  volunteers_needed integer not null default 0,
  funding_goal numeric(12,2) not null default 0,
  funding_raised numeric(12,2) not null default 0,
  is_public boolean not null default false,
  agreement_accepted boolean not null default false,
  agreement_accepted_at timestamptz,
  before_photo_url text,
  after_photo_url text,
  story_summary text,
  community_story boolean not null default false,
  payment_arrangement_documented boolean not null default false,
  sliding_scale_approved boolean not null default false,
  priority text default 'Normal' check (priority in ('Low', 'Normal', 'High', 'Urgent')),
  assigned_to uuid references public.users(id),
  created_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.cases add column if not exists contact_email text;
alter table public.cases add column if not exists contact_phone text;
alter table public.cases add column if not exists request_notes text;
alter table public.cases add column if not exists agreement_accepted boolean not null default false;
alter table public.cases add column if not exists agreement_accepted_at timestamptz;
alter table public.cases add column if not exists before_photo_url text;
alter table public.cases add column if not exists after_photo_url text;
alter table public.cases add column if not exists story_summary text;
alter table public.cases add column if not exists community_story boolean not null default false;
alter table public.cases add column if not exists payment_arrangement_documented boolean not null default false;
alter table public.cases add column if not exists sliding_scale_approved boolean not null default false;
alter table public.cases add column if not exists is_public boolean not null default false;

do $$
declare current_constraint text;
begin
  select conname into current_constraint
  from pg_constraint
  where conrelid = 'public.cases'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%status%';

  if current_constraint is not null then
    execute format('alter table public.cases drop constraint %I', current_constraint);
  end if;

  alter table public.cases
    add constraint cases_status_check
    check (status in ('Pending Review', 'Approved', 'In Progress', 'Completed', 'Pending', 'Active', 'On Hold'));
end $$;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  city text not null,
  budget_goal numeric(12,2) default 0,
  status text not null default 'Active' check (status in ('Active', 'Completed', 'Paused')),
  case_id uuid references public.cases(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.volunteers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text unique,
  phone text,
  skills text,
  availability text,
  city text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users(id),
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.donations_log (
  id uuid primary key default gen_random_uuid(),
  source text,
  amount numeric(12,2),
  donor_name text,
  donor_email text,
  case_id uuid references public.cases(id),
  note text,
  created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
before update on public.users
for each row execute function public.touch_updated_at();

drop trigger if exists trg_cases_updated_at on public.cases;
create trigger trg_cases_updated_at
before update on public.cases
for each row execute function public.touch_updated_at();

drop trigger if exists trg_projects_updated_at on public.projects;
create trigger trg_projects_updated_at
before update on public.projects
for each row execute function public.touch_updated_at();

drop trigger if exists trg_volunteers_updated_at on public.volunteers;
create trigger trg_volunteers_updated_at
before update on public.volunteers
for each row execute function public.touch_updated_at();

alter table public.users enable row level security;
alter table public.cases enable row level security;
alter table public.projects enable row level security;
alter table public.volunteers enable row level security;
alter table public.activity_log enable row level security;
alter table public.donations_log enable row level security;

create or replace function public.current_role()
returns text
language sql
stable
as $$
  select role from public.users where lower(email) = lower(auth.jwt() ->> 'email') limit 1;
$$;

drop policy if exists users_founder_all on public.users;
create policy users_founder_all on public.users
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists cases_founder_all on public.cases;
create policy cases_founder_all on public.cases
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists projects_founder_all on public.projects;
create policy projects_founder_all on public.projects
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists volunteers_founder_all on public.volunteers;
create policy volunteers_founder_all on public.volunteers
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists activity_founder_all on public.activity_log;
create policy activity_founder_all on public.activity_log
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists donations_founder_all on public.donations_log;
create policy donations_founder_all on public.donations_log
for all
using (public.current_role() = 'founder')
with check (public.current_role() = 'founder');

drop policy if exists cases_coordinator_read on public.cases;
create policy cases_coordinator_read on public.cases
for select
using (public.current_role() in ('founder', 'coordinator'));

drop policy if exists cases_coordinator_write on public.cases;
create policy cases_coordinator_write on public.cases
for update
using (public.current_role() in ('founder', 'coordinator'))
with check (public.current_role() in ('founder', 'coordinator'));

drop policy if exists projects_coordinator_read on public.projects;
create policy projects_coordinator_read on public.projects
for select
using (public.current_role() in ('founder', 'coordinator'));

drop policy if exists projects_coordinator_write on public.projects;
create policy projects_coordinator_write on public.projects
for update
using (public.current_role() in ('founder', 'coordinator'))
with check (public.current_role() in ('founder', 'coordinator'));

drop policy if exists cases_read_basic on public.cases;
create policy cases_read_basic on public.cases
for select
using (public.current_role() in ('founder', 'coordinator', 'volunteer', 'viewer'));

drop policy if exists projects_read_basic on public.projects;
create policy projects_read_basic on public.projects
for select
using (public.current_role() in ('founder', 'coordinator', 'volunteer', 'viewer'));

drop policy if exists volunteers_read_basic on public.volunteers;
create policy volunteers_read_basic on public.volunteers
for select
using (public.current_role() in ('founder', 'coordinator'));

-- Website public access (anon key) for live shared pages
drop policy if exists cases_public_read on public.cases;
create policy cases_public_read on public.cases
for select
to anon
using (is_public = true and status in ('Approved', 'In Progress', 'Completed', 'Active'));

drop policy if exists cases_public_intake_insert on public.cases;
create policy cases_public_intake_insert on public.cases
for insert
to anon
with check (
  case_number is not null
  and need_type is not null
  and city is not null
  and agreement_accepted = true
  and status in ('Pending Review', 'Approved', 'In Progress', 'Completed', 'Pending', 'Active', 'On Hold')
);

insert into public.cases (case_number, city, need_type, status)
values
('BUSI-006', 'San Antonio', 'Tree Removal', 'Completed'),
('BUSI-007', 'San Antonio', 'Lawn Care', 'Active'),
('BUSI-008', 'San Antonio', 'Vehicle Assistance', 'Pending')
on conflict (case_number) do nothing;

-- Curriculum access verification RPC
-- Allows public-side verification without returning private case details.
create or replace function public.verify_curriculum_access(
  p_case_number text,
  p_email text
)
returns table(allowed boolean, access_level text, message text)
language plpgsql
security definer
set search_path = public
as $$
declare
  matched_status text;
  matched_agreement boolean;
begin
  if coalesce(trim(p_case_number), '') = '' or coalesce(trim(p_email), '') = '' then
    return query select false, 'preview'::text, 'Case ID and email are required.'::text;
    return;
  end if;

  select c.status, c.agreement_accepted
    into matched_status, matched_agreement
  from public.cases c
  where lower(c.case_number) = lower(trim(p_case_number))
    and lower(coalesce(c.contact_email, '')) = lower(trim(p_email))
  limit 1;

  if matched_status is null then
    return query select false, 'preview'::text, 'No matching active participant record found.'::text;
    return;
  end if;

  if matched_agreement is distinct from true then
    return query select false, 'preview'::text, 'Participant agreement is not yet completed.'::text;
    return;
  end if;

  if matched_status in ('Approved', 'In Progress', 'Active') then
    return query select true, 'full'::text, 'Participant access approved.'::text;
    return;
  end if;

  return query select false, 'preview'::text, 'Case is not currently active for full curriculum access.'::text;
end;
$$;

grant execute on function public.verify_curriculum_access(text, text) to anon, authenticated;
