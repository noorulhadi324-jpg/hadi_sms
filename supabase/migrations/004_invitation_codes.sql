-- Secure parent/teacher invitation foundation.
-- Store only a hash of the code in production.
create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  invitation_type text not null check (invitation_type in ('parent', 'teacher', 'staff')),
  code_hash text not null,
  target_student_id uuid references public.students(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_invitations_school
on public.invitations(school_id);

create index if not exists idx_invitations_hash
on public.invitations(code_hash);

alter table public.invitations enable row level security;

drop policy if exists "invitation_creator_access" on public.invitations;
create policy "invitation_creator_access"
on public.invitations
for select
to authenticated
using (created_by = auth.uid());
