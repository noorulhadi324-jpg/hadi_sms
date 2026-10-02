-- HADI SMS: harden auth tenant assignment.
-- Never trust raw_user_meta_data for role/school authorization.
-- Public signups default to principal; privileged account provisioning uses app_metadata.
create or replace function public.handle_new_school_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_role text;
  user_fullname text;
  user_school_id integer;
begin
  user_role := lower(trim(coalesce(new.raw_app_meta_data->>'role','principal')));
  if user_role = 'admin' then user_role := 'principal'; end if;
  if user_role not in ('principal','teacher','parent','staff') then user_role := 'principal'; end if;

  user_fullname := coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', '');

  begin
    user_school_id := nullif(trim(coalesce(new.raw_app_meta_data->>'school_id','')), '')::integer;
  exception when others then
    user_school_id := null;
  end;

  if user_role <> 'principal' and user_school_id is null then
    raise exception 'School account must be created by an authorized school administrator';
  end if;

  if user_school_id is not null and not exists (select 1 from public.schools where id = user_school_id) then
    raise exception 'Invalid school_id';
  end if;

  insert into public.profiles (id,email,role,full_name,phone,school_id,subject,assigned_class,assigned_section,gender,staff_role,is_active)
  values (
    new.id,new.email,user_role,user_fullname,
    nullif(trim(coalesce(new.raw_user_meta_data->>'phone','')), ''),
    user_school_id,
    nullif(trim(coalesce(new.raw_user_meta_data->>'subject','')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data->>'assigned_class','')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data->>'assigned_section','')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data->>'gender','')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data->>'staff_role','')), ''),
    true
  )
  on conflict (id) do update set
    email=excluded.email,
    full_name=coalesce(nullif(excluded.full_name,''),public.profiles.full_name),
    phone=coalesce(excluded.phone,public.profiles.phone),
    role=excluded.role,
    school_id=coalesce(excluded.school_id,public.profiles.school_id),
    subject=coalesce(excluded.subject,public.profiles.subject),
    assigned_class=coalesce(excluded.assigned_class,public.profiles.assigned_class),
    assigned_section=coalesce(excluded.assigned_section,public.profiles.assigned_section),
    gender=coalesce(excluded.gender,public.profiles.gender),
    staff_role=coalesce(excluded.staff_role,public.profiles.staff_role),
    is_active=coalesce(public.profiles.is_active,true);

  return new;
end;
$$;

revoke all on function public.handle_new_school_signup() from public;
grant execute on function public.handle_new_school_signup() to service_role;
