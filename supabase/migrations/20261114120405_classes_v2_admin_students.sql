-- Admin: who is enrolled in a programme, and money per programme.
create or replace function public.admin_program_students(p_program uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(p.full_name, 'Student'), 'email', u.email, 'enrolled_at', e.created_at,
           'paid', e.payment_id is not null) order by e.created_at), '[]'::jsonb)
  from public.class_enrollments e join public.profiles p on p.id = e.user_id left join auth.users u on u.id = e.user_id
  where e.program_id = p_program and (select private.is_staff());
$$;

create or replace function public.admin_program_stats()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not (select private.is_staff()) then '{}'::jsonb else coalesce(jsonb_object_agg(x.program_id, jsonb_build_object(
    'enrolled', x.enrolled, 'paid', x.paid, 'revenue_kobo', x.revenue)), '{}'::jsonb) end
  from (select e.program_id, count(*) enrolled, count(e.payment_id) paid, coalesce(sum(pay.list_kobo), 0) revenue
        from public.class_enrollments e left join public.payments pay on pay.id = e.payment_id
        group by e.program_id) x;
$$;
