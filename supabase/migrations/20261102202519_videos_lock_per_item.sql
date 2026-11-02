-- Videos are locked per video (owner, D-057): a video marked free plays for everyone, whatever the
-- section rule says; Premium videos need Premium. Notes, novels and documents keep the section rule.
create or replace function private.study_open(p_kind text, p_is_free boolean)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_rule jsonb;
begin
  if private.is_staff() then return true; end if;
  if (select auth.uid()) is null or private.is_banned() then return false; end if;
  if private.has_premium() then return true; end if;
  if not p_is_free then return false; end if;
  if p_kind in ('video_solution', 'lesson') then return true; end if;
  select r.rules -> private.study_feature(p_kind) into v_rule from public.access_rules r where r.tier = 'free';
  return v_rule is not null and v_rule not in ('false'::jsonb, '0'::jsonb, 'null'::jsonb);
end;
$$;
