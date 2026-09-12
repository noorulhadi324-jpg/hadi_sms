-- HADI SMS
-- Compatible with the current database:
-- schools.id = integer
-- profiles.id = uuid -> auth.users.id
-- profiles.school_id = integer -> schools.id

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

alter table public.profiles
drop constraint if exists profiles_id_fkey;

alter table public.profiles
add constraint profiles_id_fkey
foreign key (id)
references auth.users(id)
on delete cascade;

alter table public.profiles
drop constraint if exists profiles_role_check;

alter table public.profiles
add constraint profiles_role_check
check (role in ('principal', 'teacher', 'parent', 'staff'));

create index if not exists idx_profiles_school_id
on public.profiles(school_id);
