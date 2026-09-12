-- HADI SMS Phase 4: production attendance foundation.
-- One attendance record per student per calendar date.
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  attendance_date date not null,
  status text not null check (status in ('present', 'absent', 'late', 'leave')),
  remarks text,
  marked_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, attendance_date)
);

create index if not exists idx_attendance_school_date
  on public.attendance(school_id, attendance_date);

create index if not exists idx_attendance_student_date
  on public.attendance(student_id, attendance_date);

alter table public.attendance enable row level security;

drop policy if exists "attendance_school_read" on public.attendance;
create policy "attendance_school_read"
on public.attendance
for select to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);

drop policy if exists "attendance_staff_insert" on public.attendance;
create policy "attendance_staff_insert"
on public.attendance
for insert to authenticated
with check (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'teacher', 'staff')
  )
  and marked_by = auth.uid()
  and exists (
    select 1
    from public.students s
    where s.id = student_id
      and s.school_id = school_id
  )
);

drop policy if exists "attendance_staff_update" on public.attendance;
create policy "attendance_staff_update"
on public.attendance
for update to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'teacher', 'staff')
  )
)
with check (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
  and marked_by = auth.uid()
);

drop policy if exists "attendance_staff_delete" on public.attendance;
create policy "attendance_staff_delete"
on public.attendance
for delete to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal', 'teacher', 'staff')
  )
);
