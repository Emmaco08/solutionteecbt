-- Game Zone v2: bot plans for races and Memory Flash (fix a name clash).
create or replace function private.gz_add_bots(p_match uuid, p_n integer)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; i integer; v_spec jsonb; v_seed text; v_plan jsonb; v_limit integer;
begin
  select * into m from public.gz_matches where id = p_match;
  for i in 1 .. greatest(p_n, 0) loop
    v_seed := p_match::text || ':bot:' || i || ':' || random();
    v_spec := private.gz_bot_spec(m.level, v_seed);
    if m.game in ('rush', 'blitz') then
      v_limit := case when m.game = 'blitz' then 6000 else 15000 end;
      select jsonb_agg(private.gz_bot_answer(v_spec, v_seed || ':' || g.n, v_limit) order by g.n) into v_plan from generate_series(0, 89) g(n);
      v_spec := v_spec || jsonb_build_object('plan', v_plan);
    elsif m.game = 'memory' then
      v_spec := v_spec || jsonb_build_object('plan', (select jsonb_agg(jsonb_build_object(
        'moves', (3 + g.n) + floor(private.gz_rand(v_seed || g.n) * (3 + g.n) * (1.4 - (v_spec ->> 'acc')::float))::int,
        'ms', ((3 + g.n) * (2600 - 1400 * (v_spec ->> 'acc')::float) + private.gz_rand(v_seed || 'm' || g.n) * 6000)::int) order by g.n)
        from generate_series(1, 3) g(n)));
    end if;
    insert into public.gz_players (match_id, user_id, bot, name) values (p_match, null, v_spec, v_spec ->> 'name');
  end loop;
end $$;
