-- Challenge background pictures (owner, 2026-11-04): one for light theme, one for dark theme (either may be empty;
-- the app uses the other one). Kept in the private R2 bucket under public/challenges/ and signed for the app.
alter table public.challenges add column if not exists bg_light text, add column if not exists bg_dark text;
alter table public.challenges drop constraint if exists challenges_bg_check;
alter table public.challenges add constraint challenges_bg_check check (
  (bg_light is null or bg_light ~ '^public/challenges/[A-Za-z0-9/_.-]{5,200}$') and
  (bg_dark is null or bg_dark ~ '^public/challenges/[A-Za-z0-9/_.-]{5,200}$'));

-- The card the app shows gets the two keys.
do $$
declare d text := pg_get_functiondef('private.challenge_card(public.challenges, uuid)'::regprocedure);
begin
  if position('''bg_light''' in d) = 0 then
    d := replace(d, '''calculator'', c.allow_calculator,', '''calculator'', c.allow_calculator, ''bg_light'', c.bg_light, ''bg_dark'', c.bg_dark,');
    if position('''bg_light''' in d) = 0 then raise exception 'challenge_card: anchor not found'; end if;
    execute d;
  end if;
end $$;

/** May this student get a link to this challenge picture? (replaced in the next migration: published challenges) */
create or replace function public.can_view_challenge_image(p_key text)
returns boolean language sql stable security definer set search_path to '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.challenges c
    where (c.bg_light = p_key or c.bg_dark = p_key) and private.challenge_status(c) <> 'draft');
$$;
revoke execute on function public.can_view_challenge_image(text) from public, anon;
grant execute on function public.can_view_challenge_image(text) to authenticated;
