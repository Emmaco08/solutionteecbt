-- Games (C14, D-150): Speed Quiz Duel (against the SolutionTee bot or a friend), Beat the AI Tutor, and the Live Exam
-- Arena (up to 50 students, the same question at the same time, a live board). Questions come only from years the
-- student can open (games with other people use years open on the free plan, so everyone can see them). Answers are
-- checked and scored on the server; the correct option is only sent after the student has answered.
insert into public.app_settings (key, value) values ('games', jsonb_build_object(
  'on', true, 'questions', 10, 'seconds', 15, 'daily_games', 40, 'daily_xp', 100,
  'xp', jsonb_build_object('play', 5, 'win', 15, 'beat_ai', 25, 'arena_play', 5, 'arena_top', jsonb_build_array(30, 20, 10))))
on conflict (key) do nothing;

alter table public.notifications drop constraint notifications_source_check;
alter table public.notifications add constraint notifications_source_check check (source = any (array['admin','news','year','streak','premium',
  'challenge','referral','ban','plan','nudge','ai','leaderboard','badge','game']));

create table public.games (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('duel_ai', 'duel_friend', 'beat_ai')),
  host uuid not null references public.profiles(id) on delete cascade,
  code text unique check (code is null or code ~ '^[A-Z0-9]{6}$'),
  exam_id smallint not null references public.exam_bodies(id),
  subject_id smallint not null references public.subjects(id),
  question_ids uuid[] not null,
  seconds smallint not null default 15 check (seconds between 5 and 60),
  bot jsonb,
  status text not null default 'playing' check (status in ('waiting', 'playing', 'done', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '1 day'
);
create index games_host_idx on public.games (host, created_at desc);
create table public.game_players (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  cur smallint not null default 0,
  served_at timestamptz,
  score integer not null default 0,
  correct smallint not null default 0,
  finished_at timestamptz,
  xp integer not null default 0,
  primary key (game_id, user_id)
);
create index game_players_user_idx on public.game_players (user_id, joined_at desc);
create table public.game_answers (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null,
  idx smallint not null,
  choice text,
  correct boolean not null,
  ms integer not null,
  points integer not null,
  primary key (game_id, user_id, idx)
);

create table public.arenas (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 80),
  exam_id smallint not null references public.exam_bodies(id),
  subject_id smallint references public.subjects(id),
  starts_at timestamptz not null,
  q_count smallint not null default 20 check (q_count between 5 and 60),
  seconds smallint not null default 20 check (seconds between 8 and 60),
  gap smallint not null default 5 check (gap between 3 and 15),
  max_players smallint not null default 50 check (max_players between 2 and 500),
  status text not null default 'draft' check (status in ('draft', 'published', 'cancelled')),
  question_ids uuid[],
  reminded_at timestamptz,
  rewarded_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index arenas_start_idx on public.arenas (starts_at);
create table public.arena_players (
  arena_id uuid not null references public.arenas(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  score integer not null default 0,
  correct smallint not null default 0,
  xp integer not null default 0,
  primary key (arena_id, user_id)
);
create table public.arena_answers (
  arena_id uuid not null references public.arenas(id) on delete cascade,
  user_id uuid not null,
  idx smallint not null,
  choice text,
  correct boolean not null,
  ms integer not null,
  points integer not null,
  primary key (arena_id, user_id, idx)
);

alter table public.games enable row level security;
alter table public.game_players enable row level security;
alter table public.game_answers enable row level security;
alter table public.arenas enable row level security;
alter table public.arena_players enable row level security;
alter table public.arena_answers enable row level security;
-- Students use the functions below only. Admins manage arenas and read game numbers.
create policy "editors" on public.arenas for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::public.staff_role[])) with check (private.can_edit(array['super_admin','admin','editor']::public.staff_role[]));
create policy "staff read" on public.games for select to authenticated using (private.is_staff());
create policy "staff read" on public.game_players for select to authenticated using (private.is_staff());
create policy "staff read" on public.arena_players for select to authenticated using (private.is_staff());
grant select, insert, update, delete on public.arenas to authenticated;
grant select on public.games, public.game_players, public.arena_players to authenticated;
create trigger arenas_audit after insert or update or delete on public.arenas for each row execute function private.audit_row();

create or replace function private.games_settings() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select value from public.app_settings where key = 'games'), '{}'::jsonb);
$$;

-- XP from games, inside both the games daily cap and the normal daily XP cap.
create or replace function private.game_xp(p_uid uuid, p_amount integer, p_reason text, p_ref text, p_key text) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_cap integer := coalesce((private.games_settings() ->> 'daily_xp')::int, 100); v_today integer;
begin
  if coalesce(p_amount, 0) <= 0 then return 0; end if;
  select coalesce(sum(amount), 0) into v_today from public.xp_ledger
  where user_id = p_uid and kind = 'earned' and reason like 'game%' and created_at >= private.lagos_day_start();
  return private.xp_add(p_uid, least(p_amount, greatest(v_cap - v_today, 0)), 'earned', p_reason, p_ref, p_key, true);
end $$;

-- Picks plain questions (no passage or picture) from the years open to this student, or open on the free plan.
create or replace function private.game_pick(p_exam smallint, p_subject smallint, p_n integer, p_free_only boolean, p_hard boolean default false)
returns uuid[] language plpgsql security definer set search_path = '' as $$
declare v_years smallint[]; v_ids uuid[];
begin
  select array_agg(distinct y.year) into v_years from public.exam_years y
  where y.exam_id = p_exam and y.status = 'published'
    and case when p_free_only then private.tier_year_open('free', p_exam, y.year) else private.year_open(p_exam, y.year) end;
  if v_years is null then return '{}'; end if;
  select array_agg(id) into v_ids from (
    select q.id from public.questions q
    where q.exam_id = p_exam and q.subject_id = p_subject and q.year = any (v_years) and q.status = 'published' and q.deleted_at is null
      and q.passage_id is null and q.image_path is null and jsonb_typeof(q.options) = 'object' and q.options ? q.answer
    order by case when p_hard and q.difficulty = 'hard' then 0 when p_hard and q.difficulty = 'medium' then 1 else 2 end, random()
    limit p_n) t;
  return coalesce(v_ids, '{}');
end $$;

create or replace function private.game_points(p_ok boolean, p_ms integer, p_seconds integer) returns integer language sql immutable as $$
  select case when p_ok then 100 + round(50 * greatest(0, 1 - p_ms::numeric / (p_seconds * 1000)))::int else 0 end;
$$;

-- A first name for boards and duels (never the email).
create or replace function private.game_name(p_uid uuid) returns text language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(split_part(btrim(p.full_name), ' ', 1), ''), 'Student') from public.profiles p where p.id = p_uid;
$$;

-- New game. Duel vs bot and Beat the AI start at once; a friend duel waits for a friend with the 6-letter code.
create or replace function public.game_create(p_mode text, p_exam smallint, p_subject smallint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.games_settings(); v_n integer; v_sec integer; v_ids uuid[];
  v_code text; v_id uuid; v_bot jsonb; v_acc numeric; v_i integer;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if coalesce((s ->> 'on')::boolean, true) is false then return jsonb_build_object('ok', false, 'error', 'off'); end if;
  if p_mode not in ('duel_ai', 'duel_friend', 'beat_ai') then return jsonb_build_object('ok', false, 'error', 'mode'); end if;
  if (select count(*) from public.game_players gp where gp.user_id = v_uid and gp.joined_at >= private.lagos_day_start())
     >= coalesce((s ->> 'daily_games')::int, 40) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  v_n := least(greatest(coalesce((s ->> 'questions')::int, 10), 5), 20);
  v_sec := least(greatest(coalesce((s ->> 'seconds')::int, 15), 5), 60);
  v_ids := private.game_pick(p_exam, p_subject, v_n, p_mode = 'duel_friend', p_mode = 'beat_ai');
  if cardinality(v_ids) < 5 then return jsonb_build_object('ok', false, 'error', 'no_questions'); end if;
  if p_mode <> 'duel_friend' then
    -- The bot: about 55-75% right for a duel; the AI tutor gets about 80-90% (hard to beat, but possible).
    v_acc := case when p_mode = 'beat_ai' then 0.8 + random() * 0.1 else 0.55 + random() * 0.2 end;
    select jsonb_agg(jsonb_build_object('c', ok, 'ms', ms, 'p', private.game_points(ok, ms, v_sec)) order by i) into v_bot
    from (select i, random() < v_acc as ok, (2500 + random() * (v_sec * 1000 * 0.7))::int as ms from generate_series(1, cardinality(v_ids)) i) b;
  else
    loop
      v_code := upper(substr(translate(encode(gen_random_bytes(8), 'base64'), '+/=0O1IL', ''), 1, 6));
      exit when char_length(v_code) = 6 and not exists (select 1 from public.games g where g.code = v_code);
    end loop;
  end if;
  insert into public.games (mode, host, code, exam_id, subject_id, question_ids, seconds, bot, status)
  values (p_mode, v_uid, v_code, p_exam, p_subject, v_ids, v_sec, v_bot, case when p_mode = 'duel_friend' then 'waiting' else 'playing' end)
  returning id into v_id;
  insert into public.game_players (game_id, user_id) values (v_id, v_uid);
  return jsonb_build_object('ok', true, 'id', v_id, 'code', v_code);
end $$;

-- A friend joins with the code (one friend per duel, within a day).
create or replace function public.game_join(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); g public.games;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into g from public.games where code = upper(btrim(p_code)) for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if exists (select 1 from public.game_players gp where gp.game_id = g.id and gp.user_id = v_uid) then return jsonb_build_object('ok', true, 'id', g.id); end if;
  if g.expires_at < now() or g.status in ('done', 'expired') then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
  if (select count(*) from public.game_players gp where gp.game_id = g.id) >= 2 then return jsonb_build_object('ok', false, 'error', 'full'); end if;
  insert into public.game_players (game_id, user_id) values (g.id, v_uid);
  update public.games set status = 'playing' where id = g.id;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('challenges'::public.notif_topic, private.game_name(v_uid) || ' took your duel', 'Play your 10 questions and see who wins.', 'user', g.host,
          'scheduled', now(), 'game', jsonb_build_object('type', 'screen', 'target', '/games/play/' || g.id));
  return jsonb_build_object('ok', true, 'id', g.id);
end $$;

-- Result for one player: scores, who won (null while the friend has not finished) and XP.
create or replace function private.game_result(p_game uuid, p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare g public.games; me public.game_players; o public.game_players; v_bot integer; v_total integer;
begin
  select * into g from public.games where id = p_game;
  select * into me from public.game_players where game_id = p_game and user_id = p_uid;
  v_total := cardinality(g.question_ids);
  if g.mode = 'duel_friend' then
    select * into o from public.game_players where game_id = p_game and user_id <> p_uid;
    return jsonb_build_object('mode', g.mode, 'total', v_total, 'score', me.score, 'correct', me.correct, 'xp', me.xp, 'finished', me.finished_at is not null,
      'opp', case when o.user_id is null then null else jsonb_build_object('name', private.game_name(o.user_id), 'score', o.score, 'correct', o.correct,
        'cur', o.cur, 'finished', o.finished_at is not null) end,
      'won', case when me.finished_at is null or o.finished_at is null then null else me.score > o.score end,
      'draw', me.finished_at is not null and o.finished_at is not null and me.score = o.score);
  end if;
  select coalesce(sum((b ->> 'p')::int), 0), count(*) filter (where (b ->> 'c')::boolean) into v_bot, v_total
  from jsonb_array_elements(g.bot) with ordinality x(b, i) where x.i <= case when me.finished_at is null then me.cur else cardinality(g.question_ids) end;
  return jsonb_build_object('mode', g.mode, 'total', cardinality(g.question_ids), 'score', me.score, 'correct', me.correct, 'xp', me.xp,
    'finished', me.finished_at is not null,
    'opp', jsonb_build_object('name', case when g.mode = 'beat_ai' then 'AI Tutor' else 'SolutionTee Bot' end, 'score', v_bot, 'correct', v_total,
      'cur', case when me.finished_at is null then me.cur else cardinality(g.question_ids) end, 'finished', me.finished_at is not null),
    'won', case when me.finished_at is null then null else me.score > v_bot end, 'draw', me.finished_at is not null and me.score = v_bot);
end $$;

-- End of a player's game: XP for playing, and for winning once the result is known.
create or replace function private.game_finish(p_game uuid, p_uid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare g public.games; s jsonb := private.games_settings() -> 'xp'; r jsonb; o public.game_players; v_xp integer; v_won uuid;
begin
  select * into g from public.games where id = p_game for update;
  v_xp := private.game_xp(p_uid, coalesce((s ->> 'play')::int, 5), 'game_play', g.id::text, 'game:' || g.id || ':' || p_uid || ':play');
  update public.game_players set xp = xp + v_xp where game_id = g.id and user_id = p_uid;
  r := private.game_result(g.id, p_uid);
  if g.mode <> 'duel_friend' then
    if (r ->> 'won')::boolean then
      v_xp := private.game_xp(p_uid, coalesce((s ->> case when g.mode = 'beat_ai' then 'beat_ai' else 'win' end)::int, 15), 'game_win', g.id::text, 'game:' || g.id || ':win');
      update public.game_players set xp = xp + v_xp where game_id = g.id and user_id = p_uid;
    end if;
    update public.games set status = 'done' where id = g.id;
    return;
  end if;
  select * into o from public.game_players where game_id = g.id and user_id <> p_uid;
  if o.user_id is null or o.finished_at is null then return; end if;
  update public.games set status = 'done' where id = g.id;
  select gp.user_id into v_won from public.game_players gp where gp.game_id = g.id order by gp.score desc limit 1;
  if (select count(distinct gp.score) from public.game_players gp where gp.game_id = g.id) = 2 then
    v_xp := private.game_xp(v_won, coalesce((s ->> 'win')::int, 15), 'game_win', g.id::text, 'game:' || g.id || ':win');
    update public.game_players set xp = xp + v_xp where game_id = g.id and user_id = v_won;
  end if;
  -- Tell the friend who finished first.
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('challenges'::public.notif_topic, 'Your duel result is in', private.game_name(p_uid) || ' has played. See who won.', 'user', o.user_id,
          'scheduled', now(), 'game', jsonb_build_object('type', 'screen', 'target', '/games/play/' || g.id));
end $$;

-- Records one answer (or a timeout when p_choice is null) for the player's current question.
create or replace function private.game_record(p_game uuid, p_uid uuid, p_choice text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare g public.games; p public.game_players; q record; v_ms integer; v_late boolean; v_ok boolean; v_pts integer; v_last boolean;
begin
  select * into g from public.games where id = p_game;
  select * into p from public.game_players where game_id = p_game and user_id = p_uid for update;
  if p.cur >= cardinality(g.question_ids) then return null; end if;
  select id, answer, options into q from public.questions where id = g.question_ids[p.cur + 1];
  v_ms := greatest(0, least(extract(epoch from (now() - coalesce(p.served_at, now()))) * 1000, g.seconds * 1000))::int;
  v_late := p.served_at is null or now() > p.served_at + make_interval(secs => g.seconds + 3);
  v_ok := not v_late and p_choice is not null and p_choice = q.answer;
  v_pts := private.game_points(v_ok, v_ms, g.seconds);
  v_last := p.cur + 1 >= cardinality(g.question_ids);
  insert into public.game_answers (game_id, user_id, idx, choice, correct, ms, points)
  values (g.id, p_uid, p.cur, case when q.options ? coalesce(p_choice, '') then p_choice end, v_ok, v_ms, v_pts) on conflict do nothing;
  update public.game_players set cur = cur + 1, served_at = null, score = score + v_pts, correct = correct + v_ok::int,
    finished_at = case when v_last then now() end
  where game_id = g.id and user_id = p_uid;
  if v_last then perform private.game_finish(g.id, p_uid); end if;
  return jsonb_build_object('correct', v_ok, 'answer', q.answer, 'choice', p_choice, 'points', v_pts, 'score', p.score + v_pts,
    'late', v_late and p_choice is not null, 'bot', case when g.bot is null then null else g.bot -> p.cur::int end, 'finished', v_last);
end $$;

-- The current question for me (options in a fixed shuffled order, no answer), or the result when I am done.
create or replace function public.game_next(p_game uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); g public.games; p public.game_players; q record; v_opts jsonb;
begin
  select * into g from public.games where id = p_game;
  select * into p from public.game_players where game_id = p_game and user_id = v_uid;
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  if g.status = 'waiting' then
    return jsonb_build_object('status', 'waiting', 'code', g.code, 'mode', g.mode, 'subject_id', g.subject_id, 'expires_at', g.expires_at);
  end if;
  -- A question left open too long counts as missed.
  while p.served_at is not null and now() > p.served_at + make_interval(secs => g.seconds + 3) and p.cur < cardinality(g.question_ids) loop
    perform private.game_record(g.id, v_uid, null);
    select * into p from public.game_players where game_id = p_game and user_id = v_uid;
  end loop;
  if p.cur >= cardinality(g.question_ids) then
    return jsonb_build_object('status', 'finished', 'mode', g.mode, 'subject_id', g.subject_id, 'result', private.game_result(g.id, v_uid));
  end if;
  select id, body, options into q from public.questions where id = g.question_ids[p.cur + 1];
  select jsonb_agg(jsonb_build_object('key', k, 'text', q.options ->> k) order by md5(g.id::text || q.id::text || k)) into v_opts from jsonb_object_keys(q.options) k;
  if p.served_at is null then
    update public.game_players set served_at = now() where game_id = g.id and user_id = v_uid returning * into p;
  end if;
  return jsonb_build_object('status', 'playing', 'mode', g.mode, 'subject_id', g.subject_id, 'index', p.cur, 'total', cardinality(g.question_ids),
    'body', q.body, 'options', v_opts, 'seconds', g.seconds, 'left_ms', greatest(0, (g.seconds * 1000 - extract(epoch from (now() - p.served_at)) * 1000))::int,
    'score', p.score, 'result', private.game_result(g.id, v_uid));
end $$;

create or replace function public.game_answer(p_game uuid, p_index integer, p_choice text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.game_players; r jsonb;
begin
  select * into p from public.game_players where game_id = p_game and user_id = v_uid;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p.cur <> p_index then return jsonb_build_object('ok', false, 'error', 'moved'); end if;
  r := private.game_record(p_game, v_uid, p_choice);
  if r is null then return jsonb_build_object('ok', false, 'error', 'finished'); end if;
  return r || jsonb_build_object('ok', true);
end $$;

-- My recent games and open friend duels (Games screen).
create or replace function public.games_mine() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by (x ->> 'at') desc), '[]'::jsonb) from (
    select jsonb_build_object('id', g.id, 'mode', g.mode, 'subject_id', g.subject_id, 'status', g.status, 'code', case when g.host = gp.user_id then g.code end,
      'at', gp.joined_at, 'result', private.game_result(g.id, gp.user_id)) x
    from public.game_players gp join public.games g on g.id = gp.game_id
    where gp.user_id = (select auth.uid()) and gp.joined_at > now() - interval '14 days'
    order by gp.joined_at desc limit 20) t;
$$;

-- ---------------------------------------------------------------- Live Exam Arena
create or replace function private.arena_end(a public.arenas) returns timestamptz language sql immutable as $$
  select a.starts_at + make_interval(secs => a.q_count * (a.seconds + a.gap));
$$;

create or replace function public.arenas_list() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'exam_id', a.exam_id, 'subject_id', a.subject_id, 'starts_at', a.starts_at,
      'ends_at', private.arena_end(a), 'q_count', a.q_count, 'seconds', a.seconds, 'max_players', a.max_players,
      'players', (select count(*) from public.arena_players p where p.arena_id = a.id),
      'joined', exists (select 1 from public.arena_players p where p.arena_id = a.id and p.user_id = (select auth.uid()))) order by a.starts_at), '[]'::jsonb)
  from public.arenas a
  where a.status = 'published' and a.starts_at < now() + interval '7 days' and private.arena_end(a) > now() - interval '1 day';
$$;

create or replace function public.arena_join(p_arena uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); a public.arenas; v_subject smallint;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into a from public.arenas where id = p_arena and status = 'published' for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if exists (select 1 from public.arena_players p where p.arena_id = a.id and p.user_id = v_uid) then return jsonb_build_object('ok', true); end if;
  if private.arena_end(a) < now() then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
  if (select count(*) from public.arena_players p where p.arena_id = a.id) >= a.max_players then return jsonb_build_object('ok', false, 'error', 'full'); end if;
  if a.question_ids is null then
    -- Everyone gets the same questions, from years open on the free plan. Mixed arenas take English first.
    v_subject := coalesce(a.subject_id, (select s.id from public.subjects s order by s.sort limit 1));
    update public.arenas set question_ids = private.game_pick(a.exam_id, v_subject, a.q_count, true) where id = a.id returning * into a;
    if cardinality(a.question_ids) < 5 then return jsonb_build_object('ok', false, 'error', 'no_questions'); end if;
  end if;
  insert into public.arena_players (arena_id, user_id) values (a.id, v_uid);
  return jsonb_build_object('ok', true);
end $$;

-- Where the arena is now: lobby, a question (answer hidden), the reveal (answer shown), or done; plus the live board.
create or replace function public.arena_state(p_arena uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); a public.arenas; v_el numeric; v_idx integer; v_phase text; v_left integer; q record; v_opts jsonb;
  me public.arena_players; v_mine record; v_rank integer; v_n integer; v_q integer;
begin
  select * into a from public.arenas where id = p_arena and status <> 'draft';
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  select * into me from public.arena_players where arena_id = a.id and user_id = v_uid;
  v_q := coalesce(cardinality(a.question_ids), a.q_count);
  v_el := extract(epoch from (now() - a.starts_at));
  if a.status = 'cancelled' then v_phase := 'cancelled';
  elsif v_el < 0 then v_phase := 'lobby'; v_left := (-v_el * 1000)::int;
  elsif v_el >= v_q * (a.seconds + a.gap) then v_phase := 'done';
  else
    v_idx := floor(v_el / (a.seconds + a.gap))::int;
    if v_el - v_idx * (a.seconds + a.gap) < a.seconds then
      v_phase := 'question'; v_left := ((a.seconds - (v_el - v_idx * (a.seconds + a.gap))) * 1000)::int;
    else
      v_phase := 'reveal'; v_left := (((v_idx + 1) * (a.seconds + a.gap) - v_el) * 1000)::int;
    end if;
  end if;
  if v_idx is not null and me.user_id is not null and a.question_ids is not null then
    select id, body, options, answer into q from public.questions where id = a.question_ids[v_idx + 1];
    select jsonb_agg(jsonb_build_object('key', k, 'text', q.options ->> k) order by md5(a.id::text || q.id::text || k)) into v_opts from jsonb_object_keys(q.options) k;
    select choice, correct, points into v_mine from public.arena_answers where arena_id = a.id and user_id = v_uid and idx = v_idx;
  end if;
  select count(*) into v_n from public.arena_players where arena_id = a.id;
  if me.user_id is not null then
    select count(*) + 1 into v_rank from public.arena_players p where p.arena_id = a.id and (p.score > me.score or (p.score = me.score and p.joined_at < me.joined_at));
  end if;
  return jsonb_build_object('status', 'ok', 'phase', v_phase, 'title', a.title, 'starts_at', a.starts_at, 'left_ms', v_left, 'index', v_idx, 'total', v_q,
    'seconds', a.seconds, 'joined', me.user_id is not null, 'players', v_n, 'max_players', a.max_players,
    'question', case when v_opts is null then null else jsonb_build_object('body', q.body, 'options', v_opts) end,
    'answer', case when v_phase = 'reveal' and q.id is not null then q.answer end,
    'mine', case when v_mine.choice is null and v_mine.points is null then null else jsonb_build_object('choice', v_mine.choice, 'correct', case when v_phase = 'reveal' then v_mine.correct end, 'points', case when v_phase = 'reveal' then v_mine.points end) end,
    'score', me.score, 'correct', me.correct, 'rank', v_rank, 'xp', me.xp,
    'board', (select coalesce(jsonb_agg(jsonb_build_object('name', private.game_name(p.user_id), 'score', p.score, 'me', p.user_id = v_uid) order by p.score desc, p.joined_at), '[]'::jsonb)
              from (select * from public.arena_players x where x.arena_id = a.id order by x.score desc, x.joined_at limit 10) p));
end $$;

create or replace function public.arena_answer(p_arena uuid, p_index integer, p_choice text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); a public.arenas; v_el numeric; v_in numeric; q record; v_ok boolean; v_ms integer; v_pts integer;
begin
  select * into a from public.arenas where id = p_arena and status = 'published';
  if not found or not exists (select 1 from public.arena_players p where p.arena_id = a.id and p.user_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_joined');
  end if;
  v_el := extract(epoch from (now() - a.starts_at));
  v_in := v_el - p_index * (a.seconds + a.gap);
  -- 1.5 s of grace for slow networks.
  if p_index < 0 or p_index >= cardinality(a.question_ids) or v_in < 0 or v_in > a.seconds + 1.5 then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
  select id, answer, options into q from public.questions where id = a.question_ids[p_index + 1];
  if not (q.options ? coalesce(p_choice, '')) then return jsonb_build_object('ok', false, 'error', 'choice'); end if;
  v_ok := p_choice = q.answer;
  v_ms := least(v_in * 1000, a.seconds * 1000)::int;
  v_pts := private.game_points(v_ok, v_ms, a.seconds);
  insert into public.arena_answers (arena_id, user_id, idx, choice, correct, ms, points) values (a.id, v_uid, p_index, p_choice, v_ok, v_ms, v_pts)
  on conflict do nothing;
  if not found then return jsonb_build_object('ok', false, 'error', 'answered'); end if;
  update public.arena_players set score = score + v_pts, correct = correct + v_ok::int where arena_id = a.id and user_id = v_uid;
  return jsonb_build_object('ok', true);
end $$;

-- Every minute: remind players 5 minutes before; after the end, XP for playing and for the top 3.
create or replace function private.arenas_job() returns void
language plpgsql security definer set search_path = '' as $$
declare a public.arenas; s jsonb := private.games_settings() -> 'xp'; r record; v_xp integer; v_place integer;
begin
  for a in select * from public.arenas x where x.status = 'published' and x.reminded_at is null and x.starts_at between now() and now() + interval '6 minutes' loop
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    select 'challenges'::public.notif_topic, left(a.title, 60) || ' starts soon', 'The Live Exam Arena starts in 5 minutes. Get ready!', 'user', p.user_id,
           'scheduled', now(), 'game', jsonb_build_object('type', 'screen', 'target', '/games/arena/' || a.id)
    from public.arena_players p where p.arena_id = a.id;
    update public.arenas set reminded_at = now() where id = a.id;
  end loop;
  for a in select * from public.arenas x where x.status = 'published' and x.rewarded_at is null and private.arena_end(x) < now() loop
    v_place := 0;
    for r in select p.user_id from public.arena_players p where p.arena_id = a.id
             and exists (select 1 from public.arena_answers aa where aa.arena_id = a.id and aa.user_id = p.user_id)
             order by p.score desc, p.joined_at loop
      v_place := v_place + 1;
      v_xp := private.game_xp(r.user_id, coalesce((s ->> 'arena_play')::int, 5), 'game_arena', a.id::text, 'arena:' || a.id || ':' || r.user_id || ':play');
      if v_place <= 3 then
        v_xp := v_xp + private.game_xp(r.user_id, coalesce((s -> 'arena_top' ->> (v_place - 1))::int, 0), 'game_arena_top', a.id::text, 'arena:' || a.id || ':' || r.user_id || ':top');
      end if;
      update public.arena_players set xp = v_xp where arena_id = a.id and user_id = r.user_id;
    end loop;
    update public.arenas set rewarded_at = now() where id = a.id;
  end loop;
end $$;
select cron.schedule('arenas', '* * * * *', 'select private.arenas_job()');

-- Admin numbers for the Games page.
create or replace function public.admin_games_stats() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not private.is_staff() then null else jsonb_build_object(
    'today', (select count(*) from public.games g where g.created_at >= private.lagos_day_start()),
    'week', (select count(*) from public.games g where g.created_at >= now() - interval '7 days'),
    'players_week', (select count(distinct gp.user_id) from public.game_players gp where gp.joined_at >= now() - interval '7 days'),
    'by_mode', (select coalesce(jsonb_object_agg(mode, n), '{}'::jsonb) from (select g.mode, count(*) n from public.games g where g.created_at >= now() - interval '7 days' group by 1) m),
    'xp_week', (select coalesce(sum(amount), 0) from public.xp_ledger x where x.reason like 'game%' and x.created_at >= now() - interval '7 days')) end;
$$;

revoke all on function private.games_settings(), private.game_xp(uuid, integer, text, text, text), private.game_pick(smallint, smallint, integer, boolean, boolean),
  private.game_name(uuid), private.game_result(uuid, uuid), private.game_finish(uuid, uuid), private.game_record(uuid, uuid, text),
  private.arenas_job() from public, anon, authenticated;
revoke all on function public.game_create(text, smallint, smallint), public.game_join(text), public.game_next(uuid), public.game_answer(uuid, integer, text),
  public.games_mine(), public.arenas_list(), public.arena_join(uuid), public.arena_state(uuid), public.arena_answer(uuid, integer, text), public.admin_games_stats() from public, anon;
grant execute on function public.game_create(text, smallint, smallint), public.game_join(text), public.game_next(uuid), public.game_answer(uuid, integer, text),
  public.games_mine(), public.arenas_list(), public.arena_join(uuid), public.arena_state(uuid), public.arena_answer(uuid, integer, text), public.admin_games_stats() to authenticated;

