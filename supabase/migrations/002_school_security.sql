-- Tenant-safe school access.
-- A principal may access only the school assigned to their profile.
-- Registration itself should be performed through a protected backend/RPC
-- in a production deployment.

alter table public.schools enable row level security;

drop policy if exists "schools_select_own" on public.schools;
drop policy if exists "schools_update_principal" on public.schools;

create policy "schools_select_own"
on public.schools
for select
to authenticated
using (
  id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);

create policy "schools_update_principal"
on public.schools
for update
to authenticated
using (
  id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'principal'
  )
)
with check (
  id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);
