-- Age gate and parent/guardian notice (lawyer's decisions of 8 Nov 2026 + owner's flow, D-109).
-- Under 13: no account (the server refuses the birth year; the app deletes the new account at once).
-- 13 to 17: the student gives a parent's or guardian's email; we email them a welcome, a plain summary of the Privacy
-- Policy and Terms, and a button to turn the account off. Seeing the email is enough; they only act to withdraw.
-- 18 and over: normal account.

alter table public.profiles add column if not exists paused_at timestamptz;
alter table public.profiles add column if not exists paused_reason text;

create table if not exists public.guardian_consents (
  user_id uuid primary key references auth.users (id) on delete cascade,
  guardian_email text not null check (guardian_email ~ '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$'),
  child_birth_year smallint not null,
  method text not null default 'email_notice' check (method in ('email_notice', 'email_confirm')),
  policy_version text not null,
  token_hash text not null unique,
  sent_at timestamptz,
  send_count integer not null default 0,
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.guardian_consents enable row level security;
create policy "own guardian notice" on public.guardian_consents for select to authenticated using (user_id = (select auth.uid()));
create policy "staff read guardian notices" on public.guardian_consents for select to authenticated using (private.is_staff());

insert into public.app_settings (key, value, is_public)
values ('guardian', '{"mode": "notice", "policy_version": "2026-11-08", "min_age": 13, "adult_age": 18}', true)
on conflict (key) do nothing;

-- Birth year: under 13 is refused (nothing is stored).
create or replace function public.set_birth_year(p_year integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_now integer := extract(year from now())::int;
begin
  if (select auth.uid()) is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_year < v_now - 80 or p_year > v_now then return jsonb_build_object('ok', false, 'why', 'year'); end if;
  if v_now - p_year < 13 then return jsonb_build_object('ok', false, 'why', 'under_13'); end if;
  update public.profiles set birth_year = p_year where id = (select auth.uid()) and birth_year is null;
  return jsonb_build_object('ok', true);
end;
$$;

-- What the app must do about age for the signed-in student.
-- status: unknown (no birth year yet) | under_13 | guardian_needed | ok | paused
create or replace function public.age_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p record; g record; v_age integer;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select birth_year, paused_at, paused_reason into p from public.profiles where id = v_uid;
  if p.paused_at is not null then return jsonb_build_object('status', 'paused', 'reason', p.paused_reason); end if;
  if exists (select 1 from public.staff s where s.user_id = v_uid) then return jsonb_build_object('status', 'ok', 'staff', true); end if;
  if p.birth_year is null then return jsonb_build_object('status', 'unknown'); end if;
  v_age := extract(year from now())::int - p.birth_year;
  if v_age < 13 then return jsonb_build_object('status', 'under_13', 'age', v_age); end if;
  if v_age >= 18 then return jsonb_build_object('status', 'ok', 'age', v_age); end if;
  select guardian_email, sent_at, withdrawn_at into g from public.guardian_consents where user_id = v_uid;
  if g.withdrawn_at is not null then return jsonb_build_object('status', 'paused', 'reason', 'guardian'); end if;
  if g.sent_at is null then return jsonb_build_object('status', 'guardian_needed', 'age', v_age); end if;
  return jsonb_build_object('status', 'ok', 'age', v_age, 'guardian', regexp_replace(g.guardian_email, '^(.).*(@.*)$', '\1•••\2'));
end;
$$;
revoke all on function public.age_status() from public, anon;
grant execute on function public.age_status() to authenticated;

-- Accounts a parent or guardian turned off are deleted 30 days later (unless support restored them first).
select cron.unschedule('guardian-withdrawn-delete') where exists (select 1 from cron.job where jobname = 'guardian-withdrawn-delete');
select cron.schedule('guardian-withdrawn-delete', '40 1 * * *', $cron$
  delete from auth.users u using public.guardian_consents g
  where g.user_id = u.id and g.withdrawn_at < now() - interval '30 days'
    and not exists (select 1 from public.staff s where s.user_id = u.id);
$cron$);
