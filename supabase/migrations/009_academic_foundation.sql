-- HADI SMS Phase 5: Academic foundation
-- Sessions, classes, sections and subjects with school-level RLS.

create extension if not exists pgcrypto;

create table if not exists public.academic_sessions (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  session_name text not null,
  start_date date not null,
  end_date date not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academic_session_dates check (end_date >= start_date),
  unique (school_id, session_name)
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  class_name text not null,
  numeric_level integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, class_name)
);

create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  section_name text not null,
  room_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, section_name)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  subject_name text not null,
  subject_code text not null,
  subject_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, subject_code)
);

create index if not exists idx_academic_sessions_school on public.academic_sessions(school_id);
create index if not exists idx_classes_school on public.classes(school_id);
create index if not exists idx_sections_class on public.sections(class_id);
create index if not exists idx_subjects_school on public.subjects(school_id);

alter table public.academic_sessions enable row level security;
alter table public.classes enable row level security;
alter table public.sections enable row level security;
alter table public.subjects enable row level security;

drop policy if exists "academic_sessions_school_read" on public.academic_sessions;
create policy "academic_sessions_school_read" on public.academic_sessions
for select to authenticated
using (school_id = (select p.school_id from public.profiles p where p.id = auth.uid()));

drop policy if exists "academic_sessions_school_write" on public.academic_sessions;
create policy "academic_sessions_school_write" on public.academic_sessions
for all to authenticated
using (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
)
with check (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
);

drop policy if exists "classes_school_read" on public.classes;
create policy "classes_school_read" on public.classes
for select to authenticated
using (school_id = (select p.school_id from public.profiles p where p.id = auth.uid()));

drop policy if exists "classes_school_write" on public.classes;
create policy "classes_school_write" on public.classes
for all to authenticated
using (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
)
with check (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
);

drop policy if exists "sections_school_read" on public.sections;
create policy "sections_school_read" on public.sections
for select to authenticated
using (
  exists (
    select 1 from public.classes c
    where c.id = class_id
      and c.school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  )
);

drop policy if exists "sections_school_write" on public.sections;
create policy "sections_school_write" on public.sections
for all to authenticated
using (
  exists (
    select 1 from public.classes c
    where c.id = class_id
      and c.school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
)
with check (
  exists (
    select 1 from public.classes c
    where c.id = class_id
      and c.school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
);

drop policy if exists "subjects_school_read" on public.subjects;
create policy "subjects_school_read" on public.subjects
for select to authenticated
using (school_id = (select p.school_id from public.profiles p where p.id = auth.uid()));

drop policy if exists "subjects_school_write" on public.subjects;
create policy "subjects_school_write" on public.subjects
for all to authenticated
using (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
)
with check (
  school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('principal','school_admin','admin')
  )
);
