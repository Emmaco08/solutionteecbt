-- Game Zone v2 (owner, 12 Nov 2026): SolutionTee's own game questions (CSV per subject in Admin → Games), a setting for
-- where game questions come from (JAMB past questions, SolutionTee questions or both; overall or per subject; students are
-- never told), and fewer repeats (questions a player saw in the last 21 days come last).

create table if not exists public.gz_questions (
  id bigint generated always as identity primary key,
  subject_id smallint not null references public.subjects (id),
  body text not null check (char_length(body) between 3 and 2000),
  options jsonb not null check (jsonb_typeof(options) = 'object'),
  answer text not null,
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  active boolean not null default true,
  batch text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  check (options ? answer)
);
create index if not exists gz_questions_subject_idx on public.gz_questions (subject_id) where active;
create index if not exists gz_questions_batch_idx on public.gz_questions (batch);
alter table public.gz_questions enable row level security;
create policy "staff read" on public.gz_questions for select using (private.is_staff());
create policy "staff edit" on public.gz_questions for all using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
grant select, insert, update, delete on public.gz_questions to authenticated;

-- Which game questions each student has seen (kept 30 days) so new ones come first.
create table if not exists public.gz_seen (
  user_id uuid not null references auth.users (id) on delete cascade,
  qkey text not null,
  seen_at timestamptz not null default now(),
  primary key (user_id, qkey)
);
create index if not exists gz_seen_time_idx on public.gz_seen (seen_at);
alter table public.gz_seen enable row level security;

-- 'jamb' (past questions), 'own' (SolutionTee questions) or 'both': games.gz.sources.<subject_id>, else games.gz.source.
create or replace function private.gz_source(p_subject smallint)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(private.games_settings() -> 'gz' -> 'sources' ->> p_subject::text, ''), private.games_settings() -> 'gz' ->> 'source', 'both');
$$;

create or replace function private.gz_build_items(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_n integer; v_ids uuid[]; v_items jsonb := '[]'; v_keys jsonb := '[]'; q record; w record; r jsonb; lvl integer;
  v_pairs integer; v_mode text; v_humans uuid[]; v_free boolean; v_hard boolean; v_own integer; v_seen text[] := '{}';
begin
  select * into m from public.gz_matches where id = p_match;
  if m.game in ('duel', 'survival', 'relay', 'rush') then
    v_n := case when m.game = 'rush' then 40 else m.rounds end;
    v_hard := m.game = 'survival';
    select array_agg(user_id) into v_humans from public.gz_players where match_id = m.id and user_id is not null;
    v_free := exists (select 1 from unnest(coalesce(v_humans, '{}')) u where not private.has_premium(u));
    v_mode := private.gz_source(m.subject_id);
    select count(*) into v_own from public.gz_questions g where g.active and g.subject_id = m.subject_id;
    -- Too few of our own for a whole game: fill with past questions (and the other way round), so a game always starts.
    if v_mode = 'own' and v_own < v_n then v_mode := 'both'; end if;
    if v_mode <> 'own' then
      v_ids := private.game_pick(m.exam_id, m.subject_id, v_n * 3, v_free, v_hard);
      if v_mode = 'jamb' and cardinality(v_ids) < least(v_n, 5) then v_mode := 'both'; end if;
    end if;
    select coalesce(array_agg(s.qkey), '{}') into v_seen from public.gz_seen s
    where s.user_id = any (coalesce(v_humans, '{}')) and s.seen_at > now() - interval '21 days';
    for q in
      with cand as (
        select 'g:' || g.id as k, g.body, g.options, g.answer, g.difficulty from public.gz_questions g
        where v_mode in ('own', 'both') and g.active and g.subject_id = m.subject_id
        union all
        select 'q:' || x.id, x.body, x.options, x.answer, coalesce(x.difficulty::text, 'medium') from public.questions x
        where v_mode in ('jamb', 'both') and x.id = any (coalesce(v_ids, '{}'))
      )
      select * from cand
      order by (k = any (v_seen)), case when v_hard then case difficulty when 'hard' then 0 when 'medium' then 1 else 2 end else 0 end, random()
      limit v_n
    loop
      v_items := v_items || jsonb_build_array(jsonb_build_object('body', q.body,
        'options', (select jsonb_agg(jsonb_build_object('key', o, 'text', q.options ->> o) order by md5(p_match::text || q.k || o)) from jsonb_object_keys(q.options) o)));
      v_keys := v_keys || to_jsonb(q.answer);
      insert into public.gz_seen (user_id, qkey) select u, q.k from unnest(coalesce(v_humans, '{}')) u
      on conflict (user_id, qkey) do update set seen_at = now();
    end loop;
    if jsonb_array_length(v_items) < least(v_n, 5) then raise exception 'no_questions'; end if;
    if m.game <> 'rush' then update public.gz_matches set rounds = least(rounds, jsonb_array_length(v_items)) where id = m.id; end if;
  elsif m.game = 'words' then
    for w in select * from public.gz_words where active order by random() limit m.rounds loop
      v_items := v_items || jsonb_build_array(jsonb_build_object('kind', w.kind, 'word', w.word,
        'body', case w.kind when 'synonym' then 'Same meaning as' when 'antonym' then 'Opposite of' else 'Which is spelt right?' end,
        'options', (select jsonb_agg(jsonb_build_object('key', o, 'text', o) order by random()) from unnest(w.answer || w.wrong[1:3]) o)));
      v_keys := v_keys || to_jsonb(w.answer);
    end loop;
    if jsonb_array_length(v_items) < 5 then raise exception 'no_content'; end if;
    update public.gz_matches set rounds = jsonb_array_length(v_items) where id = m.id;
  elsif m.game = 'blitz' then
    r := private.gz_blitz_items(p_match::text, 90);
    v_items := r -> 'items'; v_keys := r -> 'keys';
  elsif m.game = 'memory' then
    for lvl in 1 .. 3 loop
      v_pairs := 3 + lvl;
      v_items := v_items || jsonb_build_array((
        with picked as (select x.id, x.front, x.back from public.gz_cards x where x.active order by (x.subject_id = m.subject_id) desc nulls last, random() limit v_pairs),
        faces as (select id as pair, front as text from picked union all select id, back from picked)
        select jsonb_build_object('level', lvl, 'pairs', (select count(*) from picked),
          'cards', (select jsonb_agg(jsonb_build_object('pair', f.pair, 'text', f.text) order by md5(p_match::text || lvl || f.text || f.pair)) from faces f))));
    end loop;
    if (select count(*) from public.gz_cards where active) < 6 then raise exception 'no_content'; end if;
  end if;
  update public.gz_matches set items = v_items, keys = v_keys where id = p_match;
end $$;

create or replace function private.gz_sweep()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.gz_queue where joined_at < now() - interval '10 minutes';
  update public.gz_matches set status = 'cancelled' where status = 'lobby' and lobby_until < now() - interval '2 minutes';
  update public.gz_matches set status = 'cancelled' where status = 'playing' and ends_at < now() - interval '30 minutes';
  delete from public.gz_seen where seen_at < now() - interval '30 days';
end $$;

-- Admin: our own game questions per subject (all and live).
create or replace function public.admin_gz_question_counts()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not private.is_staff() then null else coalesce((
    select jsonb_object_agg(subject_id, jsonb_build_object('all', n, 'live', live)) from (
      select subject_id, count(*) n, count(*) filter (where active) live from public.gz_questions group by subject_id) t), '{}') end;
$$;
revoke all on function public.admin_gz_question_counts() from public, anon;
grant execute on function public.admin_gz_question_counts() to authenticated;
