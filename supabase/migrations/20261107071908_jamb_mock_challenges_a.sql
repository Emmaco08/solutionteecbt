alter table public.challenges
  add column if not exists style text not null default 'standard' check (style in ('standard', 'jamb_mock')),
  add column if not exists access text not null default 'open' check (access in ('open', 'premium', 'code', 'invite')),
  add column if not exists access_code_hash text,
  add column if not exists duration_minutes smallint check (duration_minutes is null or duration_minutes between 5 and 300),
  add column if not exists max_away_seconds integer check (max_away_seconds is null or max_away_seconds >= 0),
  add column if not exists exit_action text not null default 'flag' check (exit_action in ('flag', 'submit')),
  add column if not exists results text not null default 'instant' check (results in ('instant', 'after_end', 'hidden')),
  add column if not exists mock_subjects jsonb not null default '{"english": true, "student_subjects": true}';

alter table public.challenge_questions
  add column if not exists number smallint,
  add column if not exists section text,
  add column if not exists topic text,
  add column if not exists passage_key text,
  add column if not exists passage_title text,
  add column if not exists passage_body text,
  add column if not exists image_path text;

alter table public.challenge_entries
  add column if not exists subjects smallint[],
  add column if not exists deadline timestamptz,
  add column if not exists away_ms integer not null default 0,
  add column if not exists subject_scores jsonb,
  add column if not exists via text;

create table if not exists public.challenge_invites (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  label text not null check (char_length(label) between 1 and 120),
  code_hash text not null,
  code_hint text,
  user_id uuid references auth.users (id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (challenge_id, code_hash)
);
alter table public.challenge_invites enable row level security;
create policy "staff read" on public.challenge_invites for select to authenticated using (private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff delete" on public.challenge_invites for delete to authenticated using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

create table if not exists public.challenge_access (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  via text not null,
  at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
alter table public.challenge_access enable row level security;
create policy "own or staff" on public.challenge_access for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));

create table if not exists public.challenge_events (
  id bigint generated always as identity primary key,
  entry_id uuid not null references public.challenge_entries (id) on delete cascade,
  kind text not null check (kind in ('leave', 'return', 'screenshot', 'copy', 'rotate', 'warning', 'auto_submit', 'resume')),
  ms integer,
  at timestamptz not null default now()
);
create index if not exists challenge_events_entry on public.challenge_events (entry_id, at);
alter table public.challenge_events enable row level security;
create policy "staff read" on public.challenge_events for select to authenticated using (private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));

create unique index if not exists challenge_answers_one on public.challenge_answers (entry_id, question_id);

create or replace function private.code_hash(p_challenge uuid, p_code text) returns text
language sql immutable set search_path to '' as $$
  select encode(extensions.digest(p_challenge::text || ':' || upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g')), 'sha256'), 'hex');
$$;

create or replace function public.challenge_set_code(p_id uuid, p_code text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_code is not null and char_length(regexp_replace(p_code, '\s', '', 'g')) < 4 then raise exception 'The code needs at least 4 characters.' using errcode = 'P0001'; end if;
  update public.challenges set access_code_hash = case when p_code is null then null else private.code_hash(p_id, p_code) end where id = p_id;
end;
$$;

create or replace function public.challenge_make_invites(p_id uuid, p_labels text[])
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_out jsonb := '[]'; l text; v_code text; v_alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce(cardinality(p_labels), 0) not between 1 and 2000 then raise exception 'Give 1 to 2000 names.' using errcode = 'P0001'; end if;
  foreach l in array p_labels loop
    continue when coalesce(trim(l), '') = '';
    loop
      select string_agg(substr(v_alpha, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1), '') into v_code from generate_series(1, 8);
      begin
        insert into public.challenge_invites (challenge_id, label, code_hash, code_hint)
        values (p_id, left(trim(l), 120), private.code_hash(p_id, v_code), right(v_code, 2));
        exit;
      exception when unique_violation then null;
      end;
    end loop;
    v_out := v_out || jsonb_build_object('label', left(trim(l), 120), 'code', substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4));
  end loop;
  return v_out;
end;
$$;

create or replace function private.mock_allowed(c public.challenges, p_uid uuid) returns boolean
language sql stable security definer set search_path to '' as $$
  select c.access = 'open'
      or (c.access = 'premium' and private.has_premium(p_uid))
      or exists (select 1 from public.challenge_access a where a.challenge_id = c.id and a.user_id = p_uid)
      or private.is_staff();
$$;

create or replace function public.challenge_unlock(p_id uuid, p_code text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; v_hash text; inv record; v_fails integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and published;
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  if private.mock_allowed(c, v_uid) then return jsonb_build_object('ok', true); end if;
  if c.access = 'premium' then return jsonb_build_object('ok', false, 'need', 'premium'); end if;
  select count(*) into v_fails from public.audit_log where actor = v_uid and action = 'challenge_code_wrong' and row_id = p_id::text and at > now() - interval '1 hour';
  if v_fails >= 10 then raise exception 'Too many wrong codes. Try again in an hour.' using errcode = 'P0001'; end if;
  v_hash := private.code_hash(p_id, p_code);
  if c.access = 'code' and c.access_code_hash = v_hash then
    insert into public.challenge_access (challenge_id, user_id, via) values (p_id, v_uid, 'code') on conflict do nothing;
    return jsonb_build_object('ok', true);
  end if;
  if c.access in ('invite', 'code') then
    select * into inv from public.challenge_invites where challenge_id = p_id and code_hash = v_hash for update;
    if found and (inv.user_id is null or inv.user_id = v_uid) then
      update public.challenge_invites set user_id = v_uid, claimed_at = coalesce(claimed_at, now()) where id = inv.id;
      insert into public.challenge_access (challenge_id, user_id, via) values (p_id, v_uid, 'invite:' || inv.label) on conflict do nothing;
      return jsonb_build_object('ok', true, 'label', inv.label);
    elsif found then
      raise exception 'This code has already been used by another student.' using errcode = 'P0001';
    end if;
  end if;
  insert into public.audit_log (actor, action, table_name, row_id) values (v_uid, 'challenge_code_wrong', 'challenges', p_id::text);
  return jsonb_build_object('ok', false, 'need', c.access, 'wrong', true);
end;
$$;

create or replace function public.mock_gate(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare c public.challenges; v_uid uuid := (select auth.uid());
begin
  select * into c from public.challenges where id = p_id and published;
  if not found then return null; end if;
  return jsonb_build_object('style', c.style, 'access', c.access, 'allowed', v_uid is not null and private.mock_allowed(c, v_uid),
    'premium', v_uid is not null and private.has_premium(v_uid), 'duration_minutes', coalesce(c.duration_minutes, 120),
    'allowed_exits', c.allowed_exits, 'max_away_seconds', c.max_away_seconds, 'exit_action', c.exit_action, 'results', c.results,
    'entry', (select jsonb_build_object('status', e.status, 'deadline', e.deadline) from public.challenge_entries e where e.challenge_id = p_id and e.user_id = v_uid));
end;
$$;
revoke execute on function public.mock_gate(uuid) from public, anon;
grant execute on function public.mock_gate(uuid) to authenticated;
