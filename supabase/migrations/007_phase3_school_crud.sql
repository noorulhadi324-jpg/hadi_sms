-- HADI SMS Phase 3: school-safe CRUD policies for students and school-member profile reads.
-- Run after the existing profile/school/student foundation migrations.

alter table public.students enable row level security;

drop policy if exists "students_school_members" on public.students;
create policy "students_school_members"
on public.students
for select to authenticated
using (
  school_id = (
    select p.school_id from public.profiles p where p.id = auth.uid()
  )
);

drop policy if exists "students_principal_staff_insert" on public.students;
create policy "students_principal_staff_insert"
on public.students
for insert to authenticated
with check (
  school_id = (
    select p.school_id from public.profiles p where p.id = auth.uid()
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'staff')
  )
);

drop policy if exists "students_principal_staff_update" on public.students;
create policy "students_principal_staff_update"
on public.students
for update to authenticated
using (
  school_id = (
    select p.school_id from public.profiles p where p.id = auth.uid()
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'staff')
  )
)
with check (
  school_id = (
    select p.school_id from public.profiles p where p.id = auth.uid()
  )
);

drop policy if exists "students_principal_staff_delete" on public.students;
create policy "students_principal_staff_delete"
on public.students
for delete to authenticated
using (
  school_id = (
    select p.school_id from public.profiles p where p.id = auth.uid()
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'staff')
  )
);

-- Allow principals/staff to read basic profiles within their own school.
-- This is needed for real teacher/parent counts and school administration views.
drop policy if exists "profiles_school_admin_read" on public.profiles;
create policy "profiles_school_admin_read"
on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or (
    school_id = (
      select p.school_id from public.profiles p where p.id = auth.uid()
    )
    and exists (
      select 1 from public.profiles me
      where me.id = auth.uid()
        and me.role in ('principal', 'staff')
    )
  )
);
