-- HADI SMS: compatible with the existing schema observed in the project.
-- Existing schools.id and profiles.school_id are INTEGER.

create extension if not exists pgcrypto;

-- Profiles must point to Supabase Auth users.
alter table public.profiles
drop constraint if exists profiles_id_fkey;

alter table public.profiles
add constraint profiles_id_fkey
foreign key (id) references auth.users(id) on delete cascade;

-- School relationship.
alter table public.profiles
drop constraint if exists profiles_school_id_fkey;

alter table public.profiles
add constraint profiles_school_id_fkey
foreign key (school_id) references public.schools(id) on delete set null;

create index if not exists idx_profiles_school_id on public.profiles(school_id);

-- Controlled application roles.
alter table public.profiles
drop constraint if exists profiles_role_check;

alter table public.profiles
add constraint profiles_role_check
check (role in ('principal', 'teacher', 'parent', 'staff'));

-- Schools security.
alter table public.schools enable row level security;

revoke all on public.schools from anon;
grant select, insert, update on public.schools to authenticated;

drop policy if exists "Authenticated users can create own school" on public.schools;
create policy "Authenticated users can create own school"
on public.schools
for insert to authenticated
with check (principal_id = auth.uid());

drop policy if exists "Principals can view own school" on public.schools;
create policy "Principals can view own school"
on public.schools
for select to authenticated
using (principal_id = auth.uid());

drop policy if exists "Principals can update own school" on public.schools;
create policy "Principals can update own school"
on public.schools
for update to authenticated
using (principal_id = auth.uid())
with check (principal_id = auth.uid());

-- Existing profile policies are kept, but ensure the table is protected.
alter table public.profiles enable row level security;

-- Parent/child foundation. Run this after the student's main table exists.
-- The application expects public.parent_student_links(parent_id, student_id).
