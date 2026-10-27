-- SolutionTee CBT · Phase 2 · admin helper RPCs (staff only)

/** Question counts per subject and year for one exam (Exams & years page). */
create or replace function public.admin_year_counts(p_exam smallint)
returns table (subject_id smallint, year smallint, total bigint, published bigint)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not private.is_staff() then raise exception 'not_allowed' using errcode = '42501'; end if;
  return query
    select q.subject_id, q.year, count(*), count(*) filter (where q.status = 'published')
    from public.questions q
    where q.exam_id = p_exam and q.deleted_at is null
    group by q.subject_id, q.year;
end;
$$;

/** Staff list with email, last sign-in and whether 2-step login is set up (Staff page). */
create or replace function public.admin_list_staff()
returns table (user_id uuid, email text, full_name text, role public.staff_role, created_at timestamptz,
               last_sign_in_at timestamptz, has_2fa boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return query
    select s.user_id, u.email::text, p.full_name, s.role, s.created_at, u.last_sign_in_at,
           exists (select 1 from auth.mfa_factors f where f.user_id = s.user_id and f.status = 'verified')
    from public.staff s
    join auth.users u on u.id = s.user_id
    left join public.profiles p on p.id = s.user_id
    order by s.created_at;
end;
$$;

/** One student's details for the Users drawer (admins only). */
create or replace function public.admin_user_detail(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'id', u.id, 'email', u.email, 'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at,
      'email_confirmed', u.email_confirmed_at is not null,
      'profile', to_jsonb(p) - 'id',
      'is_premium', private.has_premium(u.id),
      'entitlements', coalesce((select jsonb_agg(jsonb_build_object(
          'id', e.id, 'source', e.source, 'plan', pl.name, 'starts_at', e.starts_at, 'expires_at', e.expires_at,
          'revoked_at', e.revoked_at, 'reason', e.reason) order by e.created_at desc)
        from public.entitlements e left join public.plans pl on pl.id = e.plan_id where e.user_id = u.id), '[]'::jsonb),
      'staff_role', (select s.role from public.staff s where s.user_id = u.id))
    from auth.users u left join public.profiles p on p.id = u.id
    where u.id = p_user);
end;
$$;

revoke execute on function public.admin_year_counts, public.admin_list_staff, public.admin_user_detail from public, anon;
grant execute on function public.admin_year_counts, public.admin_list_staff, public.admin_user_detail to authenticated;
