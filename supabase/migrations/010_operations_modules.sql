-- HADI SMS Phase 6: operational modules.
-- Transport, hostel, inventory, payroll, accounting and classroom records.
-- Every table is school scoped and protected by the same RLS shape used by the
-- academic foundation: any member of the school can read, only admin roles write.

create extension if not exists pgcrypto;

create table if not exists public.transport_routes (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  route_name text not null,
  vehicle_number text not null,
  driver_name text not null,
  driver_phone text,
  capacity integer not null default 0 check (capacity >= 0),
  occupied_seats integer not null default 0 check (occupied_seats >= 0),
  monthly_fee numeric(12, 2),
  status text not null default 'active'
    check (status in ('active', 'maintenance', 'inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, route_name)
);

create table if not exists public.hostel_rooms (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  room_number text not null,
  block_name text not null,
  room_type text not null default 'boys'
    check (room_type in ('boys', 'girls', 'staff')),
  capacity integer not null default 0 check (capacity >= 0),
  occupied integer not null default 0 check (occupied >= 0),
  warden_name text,
  monthly_fee numeric(12, 2),
  status text not null default 'available'
    check (status in ('available', 'full', 'maintenance')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, block_name, room_number)
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  item_name text not null,
  category text not null default 'other'
    check (category in ('furniture', 'stationery', 'electronics', 'sports', 'other')),
  quantity integer not null default 0 check (quantity >= 0),
  reorder_level integer check (reorder_level >= 0),
  unit_price numeric(12, 2),
  location text,
  supplier text,
  purchased_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payroll_records (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  employee_name text not null,
  designation text,
  pay_period text not null,
  basic_salary numeric(12, 2) not null default 0,
  allowances numeric(12, 2) not null default 0,
  deductions numeric(12, 2) not null default 0,
  paid_on date,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'on_hold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.accounting_entries (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  description text not null,
  entry_type text not null check (entry_type in ('income', 'expense')),
  category text not null,
  amount numeric(12, 2) not null check (amount >= 0),
  entry_date date not null default current_date,
  payment_method text check (payment_method in ('cash', 'bank', 'cheque', 'online')),
  reference_no text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  school_id integer not null references public.schools(id) on delete cascade,
  room_name text not null,
  building text,
  floor text,
  capacity integer not null default 0 check (capacity >= 0),
  room_type text not null default 'classroom'
    check (room_type in ('classroom', 'lab', 'library', 'hall', 'office')),
  assigned_class text,
  facilities text,
  status text not null default 'available'
    check (status in ('available', 'occupied', 'maintenance')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, room_name)
);

create index if not exists idx_transport_routes_school on public.transport_routes(school_id);
create index if not exists idx_hostel_rooms_school on public.hostel_rooms(school_id);
create index if not exists idx_inventory_items_school on public.inventory_items(school_id);
create index if not exists idx_payroll_records_school on public.payroll_records(school_id, pay_period);
create index if not exists idx_accounting_entries_school on public.accounting_entries(school_id, entry_date);
create index if not exists idx_classrooms_school on public.classrooms(school_id);

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'transport_routes',
    'hostel_rooms',
    'inventory_items',
    'payroll_records',
    'accounting_entries',
    'classrooms'
  ]
  loop
    execute format('alter table public.%I enable row level security', target_table);

    execute format('drop policy if exists %I on public.%I', target_table || '_school_read', target_table);
    execute format($policy$
      create policy %I on public.%I
      for select to authenticated
      using (school_id = (select p.school_id from public.profiles p where p.id = auth.uid()))
    $policy$, target_table || '_school_read', target_table);

    execute format('drop policy if exists %I on public.%I', target_table || '_school_write', target_table);
    execute format($policy$
      create policy %I on public.%I
      for all to authenticated
      using (
        school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
        and exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role in ('principal', 'school_admin', 'admin')
        )
      )
      with check (
        school_id = (select p.school_id from public.profiles p where p.id = auth.uid())
        and exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role in ('principal', 'school_admin', 'admin')
        )
      )
    $policy$, target_table || '_school_write', target_table);
  end loop;
end
$$;
