-- Friend duel codes: pgcrypto lives in the extensions schema; letters are upper-cased before the look-alikes (0 O 1 I L) are removed.
do $$
declare d text := pg_get_functiondef('public.game_create(text,smallint,smallint)'::regprocedure);
begin
  d := replace(d, $r$upper(substr(translate(encode(gen_random_bytes(8), 'base64'), '+/=0O1IL', ''), 1, 6))$r$,
                  $r$substr(translate(upper(encode(extensions.gen_random_bytes(9), 'base64')), '+/=0O1IL', ''), 1, 6)$r$);
  if position('extensions.gen_random_bytes' in d) = 0 then raise exception 'game_create not changed'; end if;
  execute d;
end $$;

