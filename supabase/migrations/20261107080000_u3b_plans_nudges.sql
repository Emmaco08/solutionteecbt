-- U3b (D-097): saved 7-day study plans (today's part on Home + a morning reminder) and AI comeback messages.

create table if not exists public.study_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  chat_id uuid references public.ai_chats (id) on delete set null,
  title text not null default 'My 7-day plan',
  starts_on date not null,
  days jsonb not null,            -- [{day, focus, tasks:[…], minutes, action?:{tool, args, label}}]
  done smallint[] not null default '{}',
  reminders boolean not null default true,
  created_at timestamptz not null default now(),
  ended_at timestamptz
);
create index if not exists study_plans_user on public.study_plans (user_id, created_at desc);
alter table public.study_plans enable row level security;
create policy "own plans" on public.study_plans for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));

-- Today's part of the student's active plan (for the Home "Today" card).
create or replace function public.my_today_plan()
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce((
    select jsonb_build_object('plan_id', p.id, 'title', p.title, 'day', d.n, 'of', jsonb_array_length(p.days),
                              'done', d.n = any (p.done), 'reminders', p.reminders, 'item', p.days -> (d.n - 1))
    from public.study_plans p
    cross join lateral (select (private.lagos_today() - p.starts_on) + 1 as n) d
    where p.user_id = (select auth.uid()) and p.ended_at is null
      and d.n between 1 and jsonb_array_length(p.days)
    order by p.created_at desc limit 1), 'null'::jsonb);
$$;

-- Tick a day, switch reminders, or stop the plan (own plans only).
create or replace function public.plan_update(p_plan uuid, p_done_day smallint default null, p_reminders boolean default null, p_stop boolean default false)
returns void language plpgsql security definer set search_path to '' as $$
begin
  update public.study_plans set
    done = case when p_done_day is null or p_done_day = any (done) then done else done || p_done_day end,
    reminders = coalesce(p_reminders, reminders),
    ended_at = case when p_stop then now() else ended_at end
  where id = p_plan and user_id = (select auth.uid());
end;
$$;
revoke execute on function public.my_today_plan() from public, anon;
revoke execute on function public.plan_update(uuid, smallint, boolean, boolean) from public, anon;
grant execute on function public.my_today_plan() to authenticated;
grant execute on function public.plan_update(uuid, smallint, boolean, boolean) to authenticated;

-- Morning reminder with today's plan (hour: app_settings push.plan_hour, default 6 Lagos). Runs every 15 minutes.
create or replace function private.queue_plan_reminders() returns integer
language plpgsql security definer set search_path to '' as $$
declare v_cfg jsonb; v_today date := private.lagos_today(); v_n integer := 0; r record;
begin
  select value into v_cfg from public.app_settings where key = 'push';
  if coalesce((v_cfg ->> 'plan_enabled')::boolean, true) is false then return 0; end if;
  if extract(hour from now() at time zone 'Africa/Lagos') < coalesce((v_cfg ->> 'plan_hour')::integer, 6) then return 0; end if;
  for r in
    select p.id, p.user_id, p.days -> ((v_today - p.starts_on)) as item, (v_today - p.starts_on) + 1 as n, jsonb_array_length(p.days) as total
    from public.study_plans p
    where p.ended_at is null and p.reminders
      and (v_today - p.starts_on) between 0 and jsonb_array_length(p.days) - 1
      and not private.is_banned(p.user_id)
      and not exists (select 1 from public.notification_prefs x where x.user_id = p.user_id and x.topic = 'streak' and not x.enabled)
  loop
    insert into public.notifications (topic, title, body, link, audience, user_id, source, source_ref)
    values ('streak', left('Day ' || r.n || ' of ' || r.total || ': ' || coalesce(r.item ->> 'focus', 'your study plan'), 80),
            left(coalesce((select string_agg(t, ' · ') from jsonb_array_elements_text(coalesce(r.item -> 'tasks', '[]')) t), 'Open SolutionTee to see today''s plan.'), 180),
            jsonb_build_object('type', 'screen', 'target', '/home'), 'user', r.user_id, 'plan', r.id || ':' || v_today)
    on conflict (source, source_ref) where source_ref is not null do nothing;
    if found then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end;
$$;
revoke all on function private.queue_plan_reminders() from public, anon, authenticated;
select cron.schedule('plan-reminders', '*/15 * * * *', $cron$ select private.queue_plan_reminders(); $cron$);

-- Comeback messages written by the AI (Edge Function ai-nudge, once a day). Admin: app_settings ai_nudges.
insert into public.app_settings (key, value, description, is_public, updated_by) values
  ('ai_nudges', '{"enabled": true, "max_per_day": 300, "min_days_away": 2, "max_days_away": 30, "every_days": 3}',
   'AI comeback messages: on/off, how many a day, after how many days away, and at most one per student every N days.', false, null)
on conflict (key) do nothing;

-- Students who have been away a while (service role only): own facts for a personal message, no other students.
create or replace function public.ai_nudge_candidates(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare v_cfg jsonb; v_out jsonb;
begin
  select value into v_cfg from public.app_settings where key = 'ai_nudges';
  if coalesce((v_cfg ->> 'enabled')::boolean, false) is false then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(x), '[]') into v_out from (
    select u.user_id,
           left(regexp_replace(split_part(coalesce(pr.full_name, ''), ' ', 1), '[^[:alpha:]''-]', '', 'g'), 30) as first_name,
           (private.lagos_today() - u.last_day) as days_away,
           coalesce(pr.target_exams[1], 'JAMB') as exam,
           (select w ->> 'topic' from jsonb_array_elements(public.ai_weak_topics(u.user_id, 1)) w limit 1) as weak_topic,
           (select w ->> 'subject' from jsonb_array_elements(public.ai_weak_topics(u.user_id, 1)) w limit 1) as weak_subject,
           (select s.longest_days from private.streak(u.user_id) s) as best_streak
    from (
      select a.user_id, max((a.submitted_at at time zone 'Africa/Lagos')::date) as last_day
      from public.attempts a where a.status = 'submitted' group by a.user_id
    ) u
    join public.profiles pr on pr.id = u.user_id
    where (private.lagos_today() - u.last_day) between coalesce((v_cfg ->> 'min_days_away')::int, 2) and coalesce((v_cfg ->> 'max_days_away')::int, 30)
      and exists (select 1 from public.push_tokens t where t.user_id = u.user_id)
      and not private.is_banned(u.user_id)
      and not exists (select 1 from public.notification_prefs x where x.user_id = u.user_id and x.topic = 'streak' and not x.enabled)
      and not exists (select 1 from public.notifications n where n.user_id = u.user_id and n.source = 'nudge'
                      and n.created_at > now() - make_interval(days => coalesce((v_cfg ->> 'every_days')::int, 3)))
    order by u.last_day desc
    limit least(greatest(coalesce(p_limit, 100), 1), coalesce((v_cfg ->> 'max_per_day')::int, 300), 500)
  ) x;
  return v_out;
end;
$$;
revoke execute on function public.ai_nudge_candidates(integer) from public, anon, authenticated;
grant execute on function public.ai_nudge_candidates(integer) to service_role;

-- The nudge function checks pg_cron's token like the push function does.
select cron.schedule('ai-nudges', '41 15 * * *', $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/ai-nudge',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"run":"daily"}'::jsonb,
    timeout_milliseconds := 120000);
$cron$);

-- Notifications from the AI tutor: study-plan mornings, comeback messages, and "your answer is ready".
-- (applied as migration u3b_notification_sources)
alter table public.notifications drop constraint notifications_source_check;
alter table public.notifications add constraint notifications_source_check
  check (source = any (array['admin', 'news', 'year', 'streak', 'premium', 'challenge', 'referral', 'ban', 'plan', 'nudge', 'ai']));
