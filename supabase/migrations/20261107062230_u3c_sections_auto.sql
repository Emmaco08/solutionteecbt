-- New or edited English questions get a JAMB section by the rules (unless an admin chose one); unclear ones wait for the AI sorter.
create or replace function private.questions_section() returns trigger
language plpgsql security definer set search_path to '' as $$
begin
  if new.subject_id = (select id from public.subjects where name = 'Use of English')
     and (new.section is null or new.section_source is distinct from 'admin' and new.section_source is distinct from 'import' and new.section_source is distinct from 'ai'
          and (tg_op = 'INSERT' or new.body is distinct from old.body or new.passage_id is distinct from old.passage_id or new.topic_id is distinct from old.topic_id)) then
    new.section := private.english_section(new.body, (select t.name from public.topics t where t.id = new.topic_id), new.passage_id is not null,
                                           (select p.body from public.passages p where p.id = new.passage_id));
    new.section_source := case when new.section is null then null else 'rule' end;
  end if;
  return new;
end;
$$;
create trigger questions_section before insert or update of body, passage_id, topic_id, section on public.questions
  for each row execute function private.questions_section();

-- Is the caller allowed to edit content? (used by the sort-sections function)
create or replace function public.am_content_editor() returns boolean
language sql stable security definer set search_path to '' as $$
  select private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]);
$$;
revoke execute on function public.am_content_editor() from public, anon;
grant execute on function public.am_content_editor() to authenticated;

-- Start the AI sorter from SQL (pg_cron nightly, or by hand).
create or replace function private.sort_sections_kick(p_limit integer default 300) returns void
language sql security definer set search_path to '' as $$
  select null::void from (select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/sort-sections',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := jsonb_build_object('limit', p_limit), timeout_milliseconds := 150000)) x;
$$;
revoke all on function private.sort_sections_kick(integer) from public, anon, authenticated;
select cron.schedule('sort-sections', '17 2 * * *', $cron$ select private.sort_sections_kick(300); $cron$);
