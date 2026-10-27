-- SolutionTee CBT · Phase 2 · rate limits for auth emails (codes, resets, notices)
-- Our server (Next.js API with the secret key) asks the database before every email.
-- Stores only HMAC hashes of email and IP, never the raw values.

create table private.email_send_log (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('signup', 'recovery', 'notice', 'invite', 'test')),
  email_hash text not null,
  ip_hash text,
  at timestamptz not null default now()
);
create index email_send_log_email on private.email_send_log (email_hash, kind, at desc);
create index email_send_log_ip on private.email_send_log (ip_hash, at desc);
create index email_send_log_at on private.email_send_log (at desc);
alter table private.email_send_log enable row level security;

/** Returns 'ok' (and logs the send) or the reason it is refused. Only the server (service role) may call it.
    Limits: one code per email per 60 s, 5 per email per hour, 20 per network per hour, 280 per day in total
    (Brevo free plan = 300/day; the rest is kept for staff invites and notices). */
create or replace function public.email_send_allowed(p_kind text, p_email_hash text, p_ip_hash text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_last timestamptz;
begin
  if p_kind not in ('signup', 'recovery', 'notice', 'invite', 'test') then return 'bad_kind'; end if;
  -- One at a time per email, so two quick requests can't both pass.
  perform pg_advisory_xact_lock(hashtext(p_email_hash));

  select max(l.at) into v_last from private.email_send_log l
  where l.email_hash = p_email_hash and l.kind = p_kind;
  if v_last is not null and v_last > now() - interval '60 seconds' then return 'wait_60s'; end if;

  if (select count(*) from private.email_send_log l
      where l.email_hash = p_email_hash and l.at > now() - interval '1 hour') >= 5 then
    return 'too_many_for_email';
  end if;
  if p_ip_hash is not null and (select count(*) from private.email_send_log l
      where l.ip_hash = p_ip_hash and l.at > now() - interval '1 hour') >= 20 then
    return 'too_many_for_network';
  end if;
  if (select count(*) from private.email_send_log l where l.at > now() - interval '24 hours') >= 280 then
    return 'daily_limit';
  end if;

  insert into private.email_send_log (kind, email_hash, ip_hash) values (p_kind, p_email_hash, p_ip_hash);
  return 'ok';
end;
$$;

/** Emails sent in the last 24 hours (admin Email page). */
create or replace function public.email_sent_last_24h()
returns integer language sql stable security definer set search_path = '' as $$
  select case when private.is_staff() then (select count(*)::int from private.email_send_log l where l.at > now() - interval '24 hours') end;
$$;

revoke execute on function public.email_send_allowed, public.email_sent_last_24h from public, anon, authenticated;
grant execute on function public.email_send_allowed to service_role;
grant execute on function public.email_sent_last_24h to authenticated;
