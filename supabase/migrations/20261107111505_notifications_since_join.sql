-- Owner (2026-11-07): a new account does not get the old notifications. Broadcasts count only from the moment the
-- account was created; personal ones (audience = user) always show.
do $do$
declare d text;
begin
  select pg_get_functiondef('public.my_notifications(integer)'::regprocedure) into d;
  d := replace(d, $a$    and n.sent_at > me.joined - interval '7 days'$a$, $b$    and (n.audience = 'user' or n.sent_at >= me.joined)$b$);
  if position('n.sent_at >= me.joined' in d) = 0 then raise exception 'marker not found'; end if;
  execute d;
end
$do$;
