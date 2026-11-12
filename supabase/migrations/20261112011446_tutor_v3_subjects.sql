-- Tutor v3 (D-153): a request can name up to 4 subjects (from the student's combination); the receipt on the success screen.
alter table public.tutor_requests add column if not exists subject_ids smallint[] check (cardinality(subject_ids) <= 4);

create or replace function private.tutor_subject_names(p_ids smallint[], p_one smallint)
returns text language sql stable security definer set search_path = '' as $$
  select nullif(string_agg(s.name, ', ' order by array_position(coalesce(p_ids, array[p_one]), s.id)), '')
  from public.subjects s where s.id = any(coalesce(nullif(p_ids, '{}'), array[p_one]));
$$;
revoke all on function private.tutor_subject_names(smallint[], smallint) from public, anon;

drop function if exists public.tutor_request_create(smallint, text, text, text);
create or replace function public.tutor_request_create(p_subject smallint, p_level text, p_goals text, p_times text, p_subjects smallint[] default null)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare v_uid uuid := (select auth.uid()); v_id uuid; v_ids smallint[];
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if exists (select 1 from public.tutor_requests r where r.user_id = v_uid and r.status in ('new', 'quoted', 'paid', 'matched')) then
    return jsonb_build_object('ok', false, 'error', 'open');
  end if;
  if (select count(*) from public.tutor_requests r where r.user_id = v_uid and r.created_at > now() - interval '1 day') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  if char_length(btrim(coalesce(p_goals, ''))) < 5 then return jsonb_build_object('ok', false, 'error', 'goals'); end if;
  select array_agg(s.id order by array_position(p_subjects, s.id)) into v_ids
  from public.subjects s where s.id = any(coalesce(p_subjects, '{}'::smallint[]));
  if cardinality(v_ids) > 4 then return jsonb_build_object('ok', false, 'error', 'subjects'); end if;
  update public.tutor_requests set status = 'closed', updated_at = now() where user_id = v_uid and status = 'ended';
  insert into public.tutor_requests (user_id, subject_id, subject_ids, level, goals, times)
  values (v_uid, coalesce(v_ids[1], p_subject), v_ids, case when p_level in ('jamb', 'waec', 'neco', 'post_utme') then p_level else 'other' end,
          left(btrim(p_goals), 1000), left(btrim(coalesce(p_times, '')), 300))
  returning id into v_id;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
  values (v_id, true, null, 'system', 'Request received. Choose a plan to get your tutor, or ask for a custom plan.');
  return jsonb_build_object('ok', true, 'id', v_id);
end $function$;
revoke all on function public.tutor_request_create(smallint, text, text, text, smallint[]) from public, anon;
grant execute on function public.tutor_request_create(smallint, text, text, text, smallint[]) to authenticated;

create or replace function public.tutor_overview()
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_sub jsonb;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  update public.tutor_requests x set status = 'ended', updated_at = now()
  where x.user_id = v_uid and x.status = 'matched'
    and not exists (select 1 from public.tutor_subscriptions s where s.user_id = v_uid and s.ends_at > now());
  select * into r from public.tutor_requests x where x.user_id = v_uid and x.status <> 'closed' order by x.created_at desc limit 1;
  select jsonb_build_object('plan', coalesce(pl.name, 'Custom'), 'ends_at', s.ends_at, 'starts_at', s.starts_at, 'sessions', pl.sessions, 'days', pl.days,
           'reference', py.reference, 'amount_kobo', py.amount_kobo, 'paid_at', py.verified_at)
    into v_sub
  from public.tutor_subscriptions s left join public.tutor_plans pl on pl.id = s.plan_id left join public.payments py on py.id = s.payment_id
  where s.user_id = v_uid and s.ends_at > now() order by s.ends_at desc limit 1;
  return jsonb_build_object(
    'request', case when r.id is null then null else jsonb_build_object('id', r.id, 'subject_id', r.subject_id, 'subject_ids', r.subject_ids,
      'subjects', private.tutor_subject_names(r.subject_ids, r.subject_id), 'level', r.level, 'goals', r.goals,
      'times', r.times, 'status', r.status, 'created_at', r.created_at, 'paid_at', r.paid_at, 'assigned_at', r.assigned_at, 'custom_note', r.custom_note,
      'custom_price_kobo', r.custom_price_kobo, 'custom_days', r.custom_days) end,
    'messages', coalesce((select jsonb_agg(private.tutor_msg_json(m) order by m.id)
                          from (select * from public.tutor_messages x where x.request_id = r.id order by x.id desc limit 300) m), '[]'::jsonb),
    'plans', coalesce((select jsonb_agg(jsonb_build_object('id', pl.id, 'name', pl.name, 'description', pl.description, 'price_kobo', pl.price_kobo,
                         'days', pl.days, 'sessions', pl.sessions, 'play_product_id', pl.play_product_id) order by pl.sort, pl.price_kobo)
                       from public.tutor_plans pl where pl.active), '[]'::jsonb),
    'subscription', v_sub,
    'tutor', case when r.tutor_id is not null and r.status in ('matched', 'ended') then private.tutor_card(r.tutor_id) end,
    'unread', (select count(*) from public.tutor_messages m where m.request_id = r.id and m.sender_role in ('tutor', 'admin') and m.read_at is null and m.deleted_at is null));
end $function$;

-- The tutor desk and admin lists show every subject.
do $$ declare d text; begin
  d := pg_get_functiondef('public.tutor_chats(text)'::regprocedure);
  d := replace(d, '''subject'', s.name', '''subject'', private.tutor_subject_names(r.subject_ids, r.subject_id)');
  execute d;
  d := pg_get_functiondef('public.admin_tutor_requests(text)'::regprocedure);
  d := replace(d, '''subject'', s.name', '''subject'', private.tutor_subject_names(r.subject_ids, r.subject_id)');
  execute d;
  d := pg_get_functiondef('public.tutor_student_profile(uuid)'::regprocedure);
  d := replace(d, '''subject'', (select s.name from public.subjects s where s.id = r.subject_id)', '''subject'', private.tutor_subject_names(r.subject_ids, r.subject_id)');
  execute d;
end $$;
