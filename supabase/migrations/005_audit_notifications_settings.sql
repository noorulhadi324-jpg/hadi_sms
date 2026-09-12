create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  school_id integer references public.schools(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_school_time
on public.audit_logs(school_id, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  school_id integer references public.schools(id) on delete cascade,
  recipient_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_recipient
on public.notifications(recipient_id, created_at desc);

create table if not exists public.school_settings (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null unique references public.schools(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.audit_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.school_settings enable row level security;

drop policy if exists "audit_logs_school_read" on public.audit_logs;
create policy "audit_logs_school_read"
on public.audit_logs
for select
to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);

drop policy if exists "notifications_own_read" on public.notifications;
create policy "notifications_own_read"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

drop policy if exists "settings_school_read" on public.school_settings;
create policy "settings_school_read"
on public.school_settings
for select
to authenticated
using (
  school_id = (
    select p.school_id
    from public.profiles p
    where p.id = auth.uid()
  )
);
