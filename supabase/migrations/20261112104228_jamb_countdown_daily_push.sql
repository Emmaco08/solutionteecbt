-- D-154: a JAMB countdown push every morning at 7:00 (Lagos), while the admin's countdown is on and the date is ahead.
create or replace function private.countdown_notify()
returns boolean language plpgsql security definer set search_path = '' as $$
declare v jsonb; v_day date := (now() at time zone 'Africa/Lagos')::date; v_date date; n integer; v_body text;
begin
  select s.value into v from public.app_settings s where s.key = 'exam_countdown';
  if v is null or not coalesce((v ->> 'on')::boolean, true) or not coalesce((v ->> 'push')::boolean, true) then return false; end if;
  if (v ->> 'last_pushed') = v_day::text then return false; end if;
  v_date := nullif(v -> 'dates' ->> 'JAMB', '')::date;
  if v_date is null or v_date < v_day then return false; end if;
  n := v_date - v_day;
  update public.app_settings set value = value || jsonb_build_object('last_pushed', v_day::text) where key = 'exam_countdown';
  v_body := case
    when n = 0 then 'Today is the day. Stay calm, read each question well. You have got this!'
    when n = 1 then 'Tomorrow is UTME day. Rest well tonight and do one light practice today.'
    when n <= 7 then 'The last week. One full mock today and check your weak topics.'
    when n <= 30 then 'Every day counts now. A timed CBT practice today keeps you sharp.'
    else (array['Small steps every day win big. Do one practice test today.',
                'Keep your streak alive: 20 minutes of practice today.',
                'Your future self will thank you. Practise one subject today.',
                'Students who practise daily score higher. Start today.'])[1 + (extract(doy from v_day)::int % 4)] end;
  insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
  values ('announcements',
          case when n = 0 then 'UTME is today!' when n = 1 then '1 day to JAMB UTME' else n || ' days to JAMB UTME' end,
          v_body, 'all', 'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/home'));
  return true;
end $$;
revoke all on function private.countdown_notify() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'countdown-push';
select cron.schedule('countdown-push', '0 6 * * *', 'select private.countdown_notify()'); -- 06:00 UTC = 07:00 in Lagos
