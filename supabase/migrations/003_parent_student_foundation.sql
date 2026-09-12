-- Parent/student relationship foundation.
-- This is deliberately separate from Guest Demo data.

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  admission_number text not null,
  full_name text not null,
  class_name text,
  section_name text,
  date_of_birth date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, admission_number)
);

create table if not exists public.parent_student_links (
  id uuid primary key default gen_random_uuid(),
  parent_profile_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  relationship text not null default 'Parent',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (parent_profile_id, student_id)
);

create index if not exists idx_students_school_id
on public.students(school_id);

create index if not exists idx_parent_student_parent
on public.parent_student_links(parent_profile_id);

create index if not exists idx_parent_student_student
on public.parent_student_links(student_id);

alter table public.students enable row level security;
alter table public.parent_student_links enable row level security;

drop policy if exists "students_school_members" on public.students;
create policy "students_school_members"
on public.students
for select
to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);

drop policy if exists "parent_links_own" on public.parent_student_links;
create policy "parent_links_own"
on public.parent_student_links
for select
to authenticated
using (parent_profile_id = auth.uid());
