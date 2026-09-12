-- HADI SMS: secure atomic school registration.
-- The Flutter client creates the Auth user first, then calls this RPC while
-- authenticated. The function uses auth.uid() and creates the school/profile
-- together so the client never has to guess which school ownership column to use.

create or replace function public.register_school(
  p_school_name text,
  p_registration_number text,
  p_email text,
  p_address text,
  p_phone_number text,
  p_logo_url text,
  p_principal_name text,
  p_principal_email text,
  p_principal_phone text
)
returns table (school_id integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_school_id integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to register a school';
  end if;

  insert into public.schools (
    school_name,
    registration_number,
    email,
    address,
    phone_number,
    principal_id,
    logo_url
  )
  values (
    trim(p_school_name),
    trim(p_registration_number),
    lower(trim(p_email)),
    nullif(trim(p_address), ''),
    nullif(trim(p_phone_number), ''),
    v_user_id,
    p_logo_url
  )
  returning id into v_school_id;

  insert into public.profiles (
    id,
    full_name,
    email,
    phone,
    role,
    school_id
  )
  values (
    v_user_id,
    trim(p_principal_name),
    lower(trim(p_principal_email)),
    nullif(trim(p_principal_phone), ''),
    'principal',
    v_school_id
  )
  on conflict (id) do update
  set full_name = excluded.full_name,
      email = excluded.email,
      phone = excluded.phone,
      role = 'principal',
      school_id = v_school_id;

  return query select v_school_id;
end;
$$;

revoke all on function public.register_school(text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.register_school(text, text, text, text, text, text, text, text, text) to authenticated;
