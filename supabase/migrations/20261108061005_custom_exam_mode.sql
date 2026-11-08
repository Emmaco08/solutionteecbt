-- Custom exam (owner, 2026-11-07): the student picks subjects, questions per subject (at most 40, English 60), the
-- time, topics and years. Saved like any other test, with mode 'custom'. The admin decides who can use it.
alter table public.attempts drop constraint if exists attempts_mode_check;
alter table public.attempts add constraint attempts_mode_check check (mode in ('full', 'subject', 'year', 'quick', 'topic', 'custom'));

insert into public.app_settings (key, value, is_public)
values ('custom_exam', '{"on": true, "who": "everyone", "max_questions": 40, "max_english": 60, "max_minutes": 180}', true)
on conflict (key) do nothing;
