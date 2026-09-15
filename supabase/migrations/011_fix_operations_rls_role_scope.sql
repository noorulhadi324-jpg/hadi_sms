-- Tighten write policies for operational modules.
-- The original dynamic policy compared p.school_id to itself after name resolution.
-- Explicitly require the current active principal/staff profile to belong to
-- the same school returned by get_my_school_id().

do $$
declare
  t text;
begin
  foreach t in array array['payroll_records','transport_vehicles','inventory_items','hostel_rooms'] loop
    execute format('drop policy if exists %I on public.%I', t || '_insert_admin', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (school_id = public.get_my_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.school_id = public.get_my_school_id() and lower(coalesce(p.role, '''')) in (''principal'',''staff'') and coalesce(p.is_active, true)))',
      t || '_insert_admin', t
    );

    execute format('drop policy if exists %I on public.%I', t || '_update_admin', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (school_id = public.get_my_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.school_id = public.get_my_school_id() and lower(coalesce(p.role, '''')) in (''principal'',''staff'') and coalesce(p.is_active, true))) with check (school_id = public.get_my_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.school_id = public.get_my_school_id() and lower(coalesce(p.role, '''')) in (''principal'',''staff'') and coalesce(p.is_active, true)))',
      t || '_update_admin', t
    );

    execute format('drop policy if exists %I on public.%I', t || '_delete_admin', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated using (school_id = public.get_my_school_id() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.school_id = public.get_my_school_id() and lower(coalesce(p.role, '''')) in (''principal'',''staff'') and coalesce(p.is_active, true)))',
      t || '_delete_admin', t
    );
  end loop;
end $$;
