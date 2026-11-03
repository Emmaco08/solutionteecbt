-- SolutionTee CBT · Milestone 4E2 · challenges & events, fair play, prize claims, winners wall (D-028 to D-030, D-033, D-070)
-- The server does everything that matters: it sends one question at a time (never the answers), marks each answer,
-- times it, counts exits, ranks (score, then time, then who started earlier), closes at the end time and saves winners.
-- No paid entry (D-070): entry is free until a lawyer confirms paid entry is allowed.

-- ================================================================ tables
create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 80),
  subtitle text check (char_length(subtitle) <= 160),
  kind text not null default 'cash' check (kind in ('cash', 'event', 'practice')),
  icon text not null default 'trophy' check (icon in ('trophy', 'function', 'atom', 'book-open-text', 'flask', 'globe', 'lightning', 'star')),
  exam_code text check (exam_code in ('JAMB', 'WAEC', 'NECO')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  seconds_per_question smallint not null default 30 check (seconds_per_question between 10 and 300),
  prizes integer[] not null default '{}' check (cardinality(prizes) <= 10 and 0 < all (prizes)),   -- naira, 1st, 2nd, …
  reward_text text check (char_length(reward_text) <= 160),          -- e.g. "30 days of Premium for the top 10"
  premium_days smallint not null default 0 check (premium_days between 0 and 366),
  premium_top smallint not null default 0 check (premium_top between 0 and 100),
  allowed_exits smallint not null default 0 check (allowed_exits between 0 and 3),
  published boolean not null default false,
  announced_at timestamptz,
  closed_at timestamptz,
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (kind <> 'cash' or cardinality(prizes) >= 1)
);
create index challenges_time on public.challenges (starts_at, ends_at) where published;

create table public.challenge_questions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  position smallint not null default 1,
  body text not null check (char_length(body) between 1 and 4000),
  options jsonb not null check (jsonb_typeof(options) = 'object' and options ?& array['A', 'B', 'C', 'D']),
  answer text not null check (answer in ('A', 'B', 'C', 'D', 'E')),
  explanation text check (char_length(explanation) <= 8000),
  source_question_id uuid references public.questions (id) on delete set null,
  created_at timestamptz not null default now(),
  check (options ? answer)
);
create index challenge_questions_challenge on public.challenge_questions (challenge_id, position);

create table public.challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'playing' check (status in ('playing', 'finished', 'disqualified')),
  question_order uuid[] not null,
  current smallint not null default 0,          -- index (0-based) of the question being answered
  served_at timestamptz,                         -- when the current question was sent
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  score smallint not null default 0,
  time_ms integer not null default 0,
  exits smallint not null default 0,
  dq_reason text,
  device_hash text check (char_length(device_hash) <= 128),
  device_flags text[] not null default '{}',
  flags text[] not null default '{}',            -- fair-play review signals worked out at the end
  review text check (review in ('ok', 'dq')),    -- staff decision
  rank integer,                                  -- frozen at close
  prize integer,                                 -- naira, frozen at close
  premium_given boolean not null default false,
  unique (challenge_id, user_id)
);
create index challenge_entries_rank on public.challenge_entries (challenge_id, status, score desc, time_ms, started_at);
create index challenge_entries_user on public.challenge_entries (user_id);

create table public.challenge_answers (
  entry_id uuid not null references public.challenge_entries (id) on delete cascade,
  question_id uuid not null references public.challenge_questions (id) on delete cascade,
  choice text check (choice in ('A', 'B', 'C', 'D', 'E')),
  correct boolean not null default false,
  time_ms integer not null,
  answered_at timestamptz not null default now(),
  primary key (entry_id, question_id)
);

create table public.prize_claims (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null unique references public.challenge_entries (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount integer not null,
  adult boolean not null,
  guardian_name text check (char_length(guardian_name) <= 120),
  guardian_phone text check (guardian_phone ~ '^\+?[0-9 ]{7,20}$'),
  bank_name text not null check (char_length(bank_name) between 2 and 80),
  account_number text not null check (account_number ~ '^[0-9]{10}$'),
  account_name text not null check (char_length(account_name) between 3 and 120),
  status text not null default 'submitted' check (status in ('submitted', 'paid', 'rejected')),
  admin_note text check (char_length(admin_note) <= 500),
  paid_at timestamptz,
  paid_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  check (adult or (guardian_name is not null and guardian_phone is not null))
);

create table public.winners_wall (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid unique references public.prize_claims (id) on delete set null,
  challenge_title text not null check (char_length(challenge_title) <= 120),
  name text not null check (char_length(name) <= 60),        -- first name + initial (minors: first name only)
  state text check (char_length(state) <= 40),
  place text not null check (char_length(place) <= 40),       -- e.g. "1st place"
  amount integer not null check (amount > 0),
  receipt_path text check (receipt_path ~ '^public/winners/[A-Za-z0-9/_.-]+$'),
  note text check (char_length(note) <= 300),
  published boolean not null default true,
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now()
);

-- ================================================================ RLS
alter table public.challenges enable row level security;
alter table public.challenge_questions enable row level security;
alter table public.challenge_entries enable row level security;
alter table public.challenge_answers enable row level security;
alter table public.prize_claims enable row level security;
alter table public.winners_wall enable row level security;

create policy "staff read" on public.challenges for select to authenticated using (private.is_staff());
create policy "content edit" on public.challenges for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff read" on public.challenge_questions for select to authenticated using (private.is_staff());
create policy "content edit" on public.challenge_questions for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "own or staff" on public.challenge_entries for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());
create policy "admins review" on public.challenge_entries for update to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "own or staff" on public.challenge_answers for select to authenticated
  using (exists (select 1 from public.challenge_entries e where e.id = entry_id and (e.user_id = (select auth.uid()) or private.is_staff())));
-- Bank details: the winner and money admins only.
create policy "own or money admins" on public.prize_claims for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "money admins" on public.prize_claims for update to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "everyone reads published" on public.winners_wall for select to anon, authenticated
  using (published or private.is_staff());
create policy "money admins" on public.winners_wall for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

revoke all on public.challenges, public.challenge_questions, public.challenge_entries, public.challenge_answers, public.prize_claims from anon;
revoke insert, delete on public.challenge_entries, public.challenge_answers, public.prize_claims from authenticated;
revoke update on public.challenge_answers from authenticated;
revoke update on public.challenge_entries from authenticated;
grant update (review) on public.challenge_entries to authenticated;
revoke update on public.prize_claims from authenticated;
grant update (status, admin_note, paid_at, paid_by) on public.prize_claims to authenticated;

create trigger challenges_touch before update on public.challenges for each row execute function private.touch_updated_at();
do $$
declare t text;
begin
  foreach t in array array['challenges', 'challenge_questions', 'prize_claims', 'winners_wall'] loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.audit_row()', t || '_audit', t);
  end loop;
end $$;
create trigger challenge_entries_review_audit after update of review on public.challenge_entries
  for each row when (old.review is distinct from new.review) execute function private.audit_row();

-- Notifications from challenges
alter table public.notifications drop constraint if exists notifications_source_check;
alter table public.notifications add constraint notifications_source_check
  check (source in ('admin', 'news', 'year', 'streak', 'premium', 'challenge'));

-- ================================================================ helpers
create or replace function private.challenge_status(c public.challenges)
returns text language sql stable set search_path = '' as $$
  select case when c.closed_at is not null or now() >= c.ends_at then 'ended'
              when now() >= c.starts_at then 'live' else 'upcoming' end;
$$;

/** Public card of a challenge (no questions, no answers). */
create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'starts_at', c.starts_at, 'ends_at', c.ends_at, 'status', private.challenge_status(c),
    'questions', (select count(*) from public.challenge_questions q where q.challenge_id = c.id),
    'seconds', c.seconds_per_question, 'prizes', to_jsonb(c.prizes), 'reward', c.reward_text,
    'premium_days', c.premium_days, 'premium_top', c.premium_top, 'allowed_exits', c.allowed_exits,
    'joined', (select count(*) from public.challenge_entries e where e.challenge_id = c.id),
    'mine', (select jsonb_build_object('status', e.status, 'score', e.score, 'time_ms', e.time_ms, 'rank', e.rank,
                                       'prize', e.prize, 'started_at', e.started_at, 'answered', e.current, 'dq_reason', e.dq_reason)
             from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid));
$$;

/** Entries in ranking order: best score, then fastest, then who started earlier. Disqualified ones are left out. */
create or replace function private.challenge_ranked(p_challenge uuid)
returns table (entry_id uuid, user_id uuid, score smallint, time_ms integer, started_at timestamptz, rnk integer)
language sql stable security definer set search_path = '' as $$
  select e.id, e.user_id, e.score, e.time_ms, e.started_at,
         row_number() over (order by e.score desc, e.time_ms asc, e.started_at asc)::int
  from public.challenge_entries e
  join public.profiles p on p.id = e.user_id
  where e.challenge_id = p_challenge and e.status = 'finished' and e.review is distinct from 'dq' and p.banned_at is null;
$$;

/** The question an entry must answer now, with options shuffled for this student; null when finished. */
create or replace function private.challenge_serve(p_entry uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare e record; c record; q record; v_opts jsonb;
begin
  select * into e from public.challenge_entries where id = p_entry;
  select * into c from public.challenges where id = e.challenge_id;
  if e.status <> 'playing' or e.current >= cardinality(e.question_order) then return null; end if;
  select * into q from public.challenge_questions where id = e.question_order[e.current + 1];
  select jsonb_agg(jsonb_build_object('key', k, 'text', q.options ->> k) order by md5(p_entry::text || q.id::text || k)) into v_opts
  from jsonb_object_keys(q.options) k;
  if e.served_at is null then
    update public.challenge_entries set served_at = now() where id = p_entry;
  end if;
  return jsonb_build_object('entry_id', e.id, 'index', e.current, 'total', cardinality(e.question_order),
    'question_id', q.id, 'body', q.body, 'options', v_opts, 'seconds', c.seconds_per_question,
    'served_at', coalesce(e.served_at, now()), 'allowed_exits', c.allowed_exits, 'exits', e.exits);
end;
$$;

/** Ends an entry: works out fair-play flags from the answer times and the phone. */
create or replace function private.challenge_finish(p_entry uuid, p_status text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare e record; v_avg numeric; v_sd numeric; v_n integer; v_flags text[] := '{}';
begin
  select * into e from public.challenge_entries where id = p_entry for update;
  if e.status <> 'playing' then return; end if;
  select count(*), avg(a.time_ms), stddev_pop(a.time_ms) into v_n, v_avg, v_sd
  from public.challenge_answers a where a.entry_id = p_entry and a.choice is not null;
  if v_n >= 3 and v_avg < 2000 then v_flags := array_append(v_flags, 'Answers under 2 seconds on average'::text); end if;
  if v_n >= 5 and v_sd < 250 then v_flags := array_append(v_flags, 'Answer times almost the same every time'::text); end if;
  if e.device_hash is not null and exists (select 1 from public.challenge_entries x where x.challenge_id = e.challenge_id
       and x.device_hash = e.device_hash and x.user_id <> e.user_id) then
    v_flags := array_append(v_flags, 'Same phone as another entry'::text);
  end if;
  if cardinality(e.device_flags) > 0 then v_flags := v_flags || e.device_flags; end if;
  update public.challenge_entries
  set status = p_status, finished_at = now(), dq_reason = p_reason, served_at = null, flags = v_flags,
      score = (select count(*) from public.challenge_answers a where a.entry_id = p_entry and a.correct),
      time_ms = (select coalesce(sum(a.time_ms), 0) from public.challenge_answers a where a.entry_id = p_entry)
  where id = p_entry;
end;
$$;

-- ================================================================ student RPCs
/** Live, coming up and recent (with their top 3). */
create or replace function public.challenges_list()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'challenges_enabled'), true) then
    return jsonb_build_object('on', false);
  end if;
  return jsonb_build_object('on', true,
    'items', coalesce((select jsonb_agg(private.challenge_card(c, v_uid) order by c.starts_at)
                       from public.challenges c where c.published and c.closed_at is null and c.ends_at > now()), '[]'::jsonb),
    'past', coalesce((select jsonb_agg(x order by (x ->> 'ends_at') desc) from (
        select private.challenge_card(c, v_uid) || jsonb_build_object('winners', (
          select coalesce(jsonb_agg(jsonb_build_object('rank', e.rank, 'name', private.lb_name(p.full_name, 'first-initial'), 'state', p.state,
                 'score', e.score, 'time_ms', e.time_ms, 'prize', e.prize) order by e.rank), '[]'::jsonb)
          from public.challenge_entries e join public.profiles p on p.id = e.user_id
          where e.challenge_id = c.id and e.rank is not null and e.rank <= 3)) as x
        from public.challenges c where c.published and (c.closed_at is not null or c.ends_at <= now())
        order by c.ends_at desc limit 10) t), '[]'::jsonb));
end;
$$;

create or replace function public.challenge_detail(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and (published or private.is_staff());
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  return private.challenge_card(c, v_uid);
end;
$$;

/** Start (or come back to) the challenge. One entry per student. Coming back to a running entry counts as leaving
    the screen. p_device_flags: what the phone noticed (e.g. emulator). Returns {status, question?, result?}. */
create or replace function public.challenge_start(p_id uuid, p_device text default null, p_device_flags text[] default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; e record; v_ids uuid[];
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'challenges_enabled'), true) then
    raise exception 'Challenges are switched off right now.' using errcode = 'P0001';
  end if;
  select * into c from public.challenges where id = p_id and published;
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  if found then
    if e.status = 'playing' then
      if private.challenge_status(c) = 'ended' then
        perform private.challenge_finish(e.id, 'finished');
        return jsonb_build_object('status', 'finished');
      end if;
      return public.challenge_exit(e.id, 'The app was closed or restarted during the challenge');
    end if;
    return jsonb_build_object('status', e.status);
  end if;
  if private.challenge_status(c) <> 'live' then raise exception 'This challenge is not live.' using errcode = 'P0001'; end if;
  select array_agg(q.id order by md5(v_uid::text || q.id::text)) into v_ids from public.challenge_questions q where q.challenge_id = p_id;
  if v_ids is null then raise exception 'This challenge has no questions yet.' using errcode = 'P0001'; end if;
  insert into public.challenge_entries (challenge_id, user_id, question_order, device_hash, device_flags)
  values (p_id, v_uid, v_ids, left(p_device, 128), coalesce(p_device_flags[1:5], '{}'))
  returning * into e;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;

/** Answer the current question (or p_choice null when its timer ran out). Marks it on the server and sends the
    next one. Too late (time + 3 s grace) counts as no answer. */
create or replace function public.challenge_answer(p_entry uuid, p_question uuid, p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); e record; c public.challenges; q record; v_ms integer; v_late boolean;
begin
  select * into e from public.challenge_entries where id = p_entry and user_id = v_uid for update;
  if not found then raise exception 'Not allowed' using errcode = '42501'; end if;
  if e.status <> 'playing' then return jsonb_build_object('status', e.status); end if;
  select * into c from public.challenges where id = e.challenge_id;
  if private.challenge_status(c) = 'ended' then
    perform private.challenge_finish(e.id, 'finished');
    return jsonb_build_object('status', 'finished');
  end if;
  if p_question is distinct from e.question_order[e.current + 1] then
    -- An old or a future question: just send the current one again.
    return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
  end if;
  select * into q from public.challenge_questions where id = p_question;
  v_ms := greatest(0, least(extract(epoch from (now() - coalesce(e.served_at, now()))) * 1000, c.seconds_per_question * 1000))::int;
  v_late := now() > coalesce(e.served_at, now()) + make_interval(secs => c.seconds_per_question + 3);
  insert into public.challenge_answers (entry_id, question_id, choice, correct, time_ms)
  values (e.id, q.id, case when v_late or p_choice is null or not (q.options ? p_choice) then null else p_choice end,
          not v_late and p_choice is not null and p_choice = q.answer, v_ms)
  on conflict (entry_id, question_id) do nothing;
  update public.challenge_entries set current = current + 1, served_at = null where id = e.id;
  if e.current + 1 >= cardinality(e.question_order) then
    perform private.challenge_finish(e.id, 'finished');
    return jsonb_build_object('status', 'finished');
  end if;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;

/** The app reports leaving the challenge screen. Past the allowed exits the entry is submitted and disqualified. */
create or replace function public.challenge_exit(p_entry uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); e record; c record;
begin
  select * into e from public.challenge_entries where id = p_entry and user_id = v_uid for update;
  if not found then raise exception 'Not allowed' using errcode = '42501'; end if;
  if e.status <> 'playing' then return jsonb_build_object('status', e.status); end if;
  select * into c from public.challenges where id = e.challenge_id;
  update public.challenge_entries set exits = exits + 1 where id = e.id;
  if e.exits + 1 > c.allowed_exits then
    perform private.challenge_finish(e.id, 'disqualified', left(coalesce(p_reason, 'You left the challenge screen'), 200));
    return jsonb_build_object('status', 'disqualified');
  end if;
  return jsonb_build_object('status', 'playing', 'warning', format('You left the challenge screen. %s more and you are disqualified.',
    case when c.allowed_exits - e.exits - 1 = 0 then 'Once' else (c.allowed_exits - e.exits)::text || ' times' end),
    'question', private.challenge_serve(e.id));
end;
$$;

/** My result, my live rank and the top 10 (first name + initial, state, score, time, start time). */
create or replace function public.challenge_result(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; v_me jsonb; v_top jsonb; v_claim jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and (published or private.is_staff());
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  with r as (select * from private.challenge_ranked(p_id))
  select
    (select coalesce(jsonb_agg(jsonb_build_object('rank', coalesce(e.rank, r.rnk), 'name', private.lb_name(p.full_name, 'first-initial'),
            'state', p.state, 'score', r.score, 'time_ms', r.time_ms, 'started_at', r.started_at, 'me', r.user_id = v_uid,
            'prize', e.prize) order by coalesce(e.rank, r.rnk)), '[]'::jsonb)
     from r join public.profiles p on p.id = r.user_id join public.challenge_entries e on e.id = r.entry_id
     where coalesce(e.rank, r.rnk) <= 10),
    (select jsonb_build_object('rank', coalesce(e.rank, r.rnk), 'entry_id', e.id) from public.challenge_entries e
       left join r on r.entry_id = e.id where e.challenge_id = p_id and e.user_id = v_uid)
    into v_top, v_me;
  select jsonb_build_object('status', pc.status, 'created_at', pc.created_at, 'paid_at', pc.paid_at) into v_claim
  from public.prize_claims pc join public.challenge_entries e on e.id = pc.entry_id
  where e.challenge_id = p_id and e.user_id = v_uid;
  return private.challenge_card(c, v_uid) || jsonb_build_object('top', v_top, 'my_rank', v_me -> 'rank', 'claim', v_claim,
    'claim_until', case when c.closed_at is not null then c.closed_at + interval '7 days' end,
    'ranked', (select count(*) from private.challenge_ranked(p_id)));
end;
$$;

/** A winner sends the account to pay (within 7 days of the close). Never a PIN, card or password. */
create or replace function public.prize_claim(p_id uuid, p_adult boolean, p_bank text, p_account_number text, p_account_name text,
                                              p_guardian_name text default null, p_guardian_phone text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); e record; c record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  select * into c from public.challenges where id = p_id;
  if e.id is null or coalesce(e.prize, 0) <= 0 then raise exception 'Only winners can claim a prize.' using errcode = '42501'; end if;
  if c.closed_at is null or now() > c.closed_at + interval '7 days' then
    raise exception 'The 7 days to send your account details have passed. Contact support.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.prize_claims pc where pc.entry_id = e.id) then
    raise exception 'You have already sent your account details.' using errcode = 'P0001';
  end if;
  if p_account_number !~ '^[0-9]{10}$' then raise exception 'Enter the 10-digit account number.' using errcode = '22023'; end if;
  if not p_adult and (coalesce(btrim(p_guardian_name), '') = '' or coalesce(btrim(p_guardian_phone), '') = '') then
    raise exception 'Under 18: add your parent or guardian''s name and phone number.' using errcode = '22023';
  end if;
  insert into public.prize_claims (entry_id, user_id, amount, adult, guardian_name, guardian_phone, bank_name, account_number, account_name)
  values (e.id, v_uid, e.prize, p_adult, nullif(btrim(p_guardian_name), ''), nullif(btrim(p_guardian_phone), ''),
          btrim(p_bank), p_account_number, btrim(p_account_name));
  return jsonb_build_object('ok', true);
end;
$$;

/** My winnings: prizes and rewards, with how far each payment is. */
create or replace function public.my_winnings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'total', coalesce((select sum(e.prize) from public.challenge_entries e where e.user_id = (select auth.uid()) and e.prize > 0), 0),
    'paid', coalesce((select sum(pc.amount) from public.prize_claims pc where pc.user_id = (select auth.uid()) and pc.status = 'paid'), 0),
    'items', coalesce((select jsonb_agg(jsonb_build_object('challenge_id', c.id, 'title', c.title, 'rank', e.rank, 'prize', e.prize,
               'premium_days', case when e.premium_given then c.premium_days end, 'closed_at', c.closed_at,
               'claim', (select pc.status from public.prize_claims pc where pc.entry_id = e.id),
               'bank', (select pc.bank_name || ' ••••' || right(pc.account_number, 4) from public.prize_claims pc where pc.entry_id = e.id))
             order by c.closed_at desc)
       from public.challenge_entries e join public.challenges c on c.id = e.challenge_id
       where e.user_id = (select auth.uid()) and (e.prize > 0 or e.premium_given)), '[]'::jsonb));
$$;

create or replace function public.winners_wall_list()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'total', coalesce((select sum(w.amount) from public.winners_wall w where w.published), 0),
    'count', (select count(*) from public.winners_wall w where w.published),
    'items', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'title', w.challenge_title, 'name', w.name, 'state', w.state,
               'place', w.place, 'amount', w.amount, 'receipt', w.receipt_path, 'note', w.note, 'at', w.created_at) order by w.created_at desc)
       from public.winners_wall w where w.published), '[]'::jsonb));
$$;

-- ================================================================ closing, notices and the schedule
/** Ranks a closed challenge and saves winners (also used again after an admin review changes an entry). */
create or replace function private.challenge_rank(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c record; r record;
begin
  select * into c from public.challenges where id = p_id;
  update public.challenge_entries set rank = null, prize = null where challenge_id = p_id and not exists (
    select 1 from public.prize_claims pc where pc.entry_id = challenge_entries.id);
  for r in select * from private.challenge_ranked(p_id) loop
    update public.challenge_entries set rank = r.rnk,
      prize = case when r.rnk <= cardinality(c.prizes) then c.prizes[r.rnk] end
    where id = r.entry_id and not exists (select 1 from public.prize_claims pc where pc.entry_id = r.entry_id);
  end loop;
  -- Premium reward for the top N (once per entry)
  if c.premium_days > 0 and c.premium_top > 0 then
    insert into public.entitlements (user_id, plan_id, source, reason, starts_at, expires_at, granted_by)
    select e.user_id, null, 'prize', 'Challenge reward: ' || c.title, now(), now() + make_interval(days => c.premium_days), null
    from public.challenge_entries e where e.challenge_id = p_id and e.rank <= c.premium_top and not e.premium_given;
    update public.challenge_entries set premium_given = true where challenge_id = p_id and rank <= c.premium_top;
  end if;
end;
$$;

/** Every minute: announce challenges that just started, close the ones that ended (winners + messages). */
create or replace function private.challenges_tick()
returns integer language plpgsql security definer set search_path = '' as $$
declare c record; e record; v_n integer := 0;
begin
  for c in select * from public.challenges where published and announced_at is null and starts_at <= now() and ends_at > now() loop
    update public.challenges set announced_at = now() where id = c.id;
    insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
    values ('challenges', left(c.title || ' is live', 80),
            left(case when cardinality(c.prizes) > 0 then 'Win ₦' || to_char(c.prizes[1], 'FM999,999,999') || '. ' else '' end
                 || 'Tap to play before it closes.', 240),
            'all', 'scheduled', now(), 'challenge', jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id));
  end loop;
  for c in select * from public.challenges where published and closed_at is null and ends_at <= now() loop
    for e in select id from public.challenge_entries where challenge_id = c.id and status = 'playing' loop
      perform private.challenge_finish(e.id, 'finished');
    end loop;
    update public.challenges set closed_at = now() where id = c.id;
    perform private.challenge_rank(c.id);
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    select 'challenges', left('You won ₦' || to_char(x.prize, 'FM999,999,999') || '!', 80),
           left('You are #' || x.rank || ' in ' || c.title || '. Send your account details within 7 days.', 240),
           'user', x.user_id, 'scheduled', now(), 'challenge', jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id || '/winners')
    from public.challenge_entries x where x.challenge_id = c.id and x.prize > 0;
    insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
    values ('challenges', left('Winners of ' || c.title, 80), 'See the winners and your place.', 'all', 'scheduled', now(), 'challenge',
            jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id || '/winners'));
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke execute on function private.challenges_tick(), private.challenge_rank(uuid), private.challenge_finish(uuid, text, text),
  private.challenge_serve(uuid), private.challenge_ranked(uuid), private.challenge_card(public.challenges, uuid) from public, anon, authenticated;

select cron.schedule('challenges-tick', '* * * * *', $$select private.challenges_tick()$$);

-- ================================================================ admin RPCs
/** Admin: close now (winners at once). */
create or replace function public.admin_challenge_close(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.challenges set ends_at = least(ends_at, now()) where id = p_id and closed_at is null;
  perform private.challenges_tick();
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: keep an entry disqualified / reinstate it, then rank again (winners already paid keep their place). */
create or replace function public.admin_challenge_review(p_entry uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare e record;
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_decision not in ('ok', 'dq', 'reinstate') then raise exception 'Unknown decision' using errcode = '22023'; end if;
  select * into e from public.challenge_entries where id = p_entry;
  if p_decision = 'reinstate' then
    update public.challenge_entries set status = 'finished', review = 'ok' where id = p_entry and status = 'disqualified';
  else
    update public.challenge_entries set review = p_decision where id = p_entry;
  end if;
  if (select closed_at from public.challenges where id = e.challenge_id) is not null then perform private.challenge_rank(e.challenge_id); end if;
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: every entry of a challenge with score, time, exits, flags and claim. */
create or replace function public.admin_challenge_entries(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', e.id, 'name', p.full_name, 'state', p.state, 'status', e.status, 'score', e.score,
             'answered', e.current, 'time_ms', e.time_ms, 'exits', e.exits, 'dq_reason', e.dq_reason, 'flags', to_jsonb(e.flags),
             'review', e.review, 'rank', e.rank, 'prize', e.prize, 'started_at', e.started_at, 'finished_at', e.finished_at,
             'claim', (select pc.status from public.prize_claims pc where pc.entry_id = e.id))
           order by e.rank nulls last, e.score desc, e.time_ms)
    from public.challenge_entries e join public.profiles p on p.id = e.user_id where e.challenge_id = p_id), '[]'::jsonb);
end;
$$;

/** Admin: winners to pay, with their claims (money admins only see bank details). */
create or replace function public.admin_prize_claims()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('entry_id', e.id, 'challenge', c.title, 'closed_at', c.closed_at, 'rank', e.rank, 'prize', e.prize,
             'name', p.full_name, 'state', p.state, 'flags', to_jsonb(e.flags), 'review', e.review,
             'claim', (select to_jsonb(pc) - 'user_id' from public.prize_claims pc where pc.entry_id = e.id),
             'on_wall', exists (select 1 from public.winners_wall w join public.prize_claims pc on pc.id = w.claim_id where pc.entry_id = e.id))
           order by c.closed_at desc, e.rank)
    from public.challenge_entries e join public.challenges c on c.id = e.challenge_id join public.profiles p on p.id = e.user_id
    where e.prize > 0), '[]'::jsonb);
end;
$$;

revoke execute on function public.challenges_list(), public.challenge_detail(uuid), public.challenge_start(uuid, text, text[]),
  public.challenge_answer(uuid, uuid, text), public.challenge_exit(uuid, text), public.challenge_result(uuid),
  public.prize_claim(uuid, boolean, text, text, text, text, text), public.my_winnings(), public.admin_challenge_close(uuid),
  public.admin_challenge_review(uuid, text), public.admin_challenge_entries(uuid), public.admin_prize_claims() from public, anon;
grant execute on function public.challenges_list(), public.challenge_detail(uuid), public.challenge_start(uuid, text, text[]),
  public.challenge_answer(uuid, uuid, text), public.challenge_exit(uuid, text), public.challenge_result(uuid),
  public.prize_claim(uuid, boolean, text, text, text, text, text), public.my_winnings(), public.admin_challenge_close(uuid),
  public.admin_challenge_review(uuid, text), public.admin_challenge_entries(uuid), public.admin_prize_claims() to authenticated;
grant execute on function public.winners_wall_list() to anon, authenticated;
