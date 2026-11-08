-- D-111: official JAMB, WAEC and NECO logos only after written permission. Admin switch app_settings.exam_logos.on
-- (default off): the app shows its own exam badge (icon + the exam name in plain text) instead.
insert into public.app_settings (key, value, is_public)
values ('exam_logos', '{"on": false}', true)
on conflict (key) do nothing;

-- No cash prizes while they are switched off (D-110): onboarding promises Premium and XP rewards instead.
update public.onboarding_slides
set title = 'Weekly challenges',
    body = 'Answer fast and right to climb the leaderboard and win Premium days and XP. Free and Premium students can join.'
where title = 'Win cash prizes every week';

-- D-110: personalised ads only for adults (18+) who said yes in Settings. Off by default (NDPA: consent is a clear yes).
alter table public.profiles add column if not exists ads_consent boolean not null default false;
alter table public.profiles add column if not exists ads_consent_at timestamptz;

create or replace function public.set_ads_consent(p_on boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_on and coalesce(private.user_age(v_uid), 0) < 18 then
    return jsonb_build_object('ok', false, 'why', 'adults_only');
  end if;
  update public.profiles set ads_consent = coalesce(p_on, false), ads_consent_at = now() where id = v_uid;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_ads_consent(boolean) from public, anon;
grant execute on function public.set_ads_consent(boolean) to authenticated;
