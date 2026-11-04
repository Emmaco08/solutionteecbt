-- U1 (docs/plans/big-update.md): bookmarks keep text refs; daily motivation for the Home top card.
alter table public.bookmarks alter column ref type text using ref::text;
alter table public.bookmarks drop constraint if exists bookmarks_ref_check;
alter table public.bookmarks add constraint bookmarks_ref_check check (char_length(ref) between 1 and 200);

create table if not exists public.motivation_quotes (
  id bigint generated always as identity primary key,
  body text not null check (char_length(body) between 5 and 280),
  author text check (author is null or char_length(author) <= 80),
  kind text not null default 'quote' check (kind in ('quote','tip','fact')),
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.motivation_quotes enable row level security;
create policy "read active" on public.motivation_quotes for select to authenticated using (active or private.is_staff());
create policy "content edit" on public.motivation_quotes for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin','admin','editor']::public.staff_role[]));

/** Today's line: the same for everyone on a Lagos day, stepping through the active list. */
create or replace function public.today_motivation()
returns jsonb language sql stable security definer set search_path to '' as $$
  with l as (select id, body, author, kind, row_number() over (order by sort, id) - 1 as n, count(*) over () as c
             from public.motivation_quotes where active)
  select coalesce((select jsonb_build_object('id', id, 'body', body, 'author', author, 'kind', kind) from l
    where n = ((now() at time zone 'Africa/Lagos')::date - date '2026-01-01') % c), '{}'::jsonb);
$$;
grant execute on function public.today_motivation() to authenticated;

insert into public.motivation_quotes (body, author, kind, sort) values
('Education is the most powerful weapon which you can use to change the world.', 'Nelson Mandela', 'quote', 1),
('Small steps every day beat one big push the night before the exam.', null, 'quote', 2),
('Twenty good questions today is worth more than two hundred next week.', null, 'quote', 3),
('You don''t have to be great to start, but you have to start to be great.', 'Zig Ziglar', 'quote', 4),
('Read the question twice. Many marks are lost to hurry, not to ignorance.', null, 'tip', 5),
('In JAMB, an unanswered question scores zero. A careful guess might not.', null, 'tip', 6),
('Success is the sum of small efforts, repeated day in and day out.', 'Robert Collier', 'quote', 7),
('Your future school is waiting for the version of you that practises today.', null, 'quote', 8),
('Practise under time. The clock is part of the exam.', null, 'tip', 9),
('Mistakes in practice are cheap. Mistakes in the exam hall are expensive. Make them here.', null, 'quote', 10),
('It always seems impossible until it''s done.', 'Nelson Mandela', 'quote', 11),
('Teach a friend one topic today. Explaining it is the best way to learn it.', null, 'tip', 12),
('Discipline is choosing between what you want now and what you want most.', null, 'quote', 13),
('Use of English carries 100 marks in JAMB. Give it time every week.', null, 'tip', 14),
('Sleep is study too. A rested brain remembers more.', null, 'tip', 15),
('The expert in anything was once a beginner.', null, 'quote', 16),
('Don''t watch the clock; do what it does. Keep going.', 'Sam Levenson', 'quote', 17),
('Go through your wrong answers. That is where the next marks are hiding.', null, 'tip', 18),
('Believe you can, and you are halfway there.', 'Theodore Roosevelt', 'quote', 19),
('A streak is a promise to yourself. Keep it alive today.', null, 'quote', 20),
('For calculations, write each step. It is faster to check than to redo.', null, 'tip', 21),
('Hard work beats talent when talent doesn''t work hard.', 'Tim Notke', 'quote', 22),
('One past question paper a day keeps exam fear away.', null, 'quote', 23),
('Learn the formula, then learn when to use it.', null, 'tip', 24),
('The secret of getting ahead is getting started.', null, 'quote', 25),
('Skip a hard question and come back to it. Don''t let one question eat your time.', null, 'tip', 26),
('Your only competition is who you were yesterday.', null, 'quote', 27),
('Read your novel summary again. Literature questions love small details.', null, 'tip', 28),
('Dreams don''t work unless you do.', 'John C. Maxwell', 'quote', 29),
('Study in short blocks: 25 minutes on, 5 minutes off.', null, 'tip', 30),
('Every expert you admire practised what you are practising now.', null, 'quote', 31),
('Before the exam, know your centre, your time and your documents.', null, 'tip', 32),
('Push yourself, because no one else is going to do it for you.', null, 'quote', 33),
('When two options look right, look for the word that makes one wrong.', null, 'tip', 34),
('Great things never come from comfort zones.', null, 'quote', 35),
('Revise today''s topic tonight, and again in three days. That is how it sticks.', null, 'tip', 36),
('Fall seven times, stand up eight.', 'Japanese proverb', 'quote', 37),
('Drink water and eat before a long test. Your brain needs fuel.', null, 'tip', 38),
('If it is important to you, you will find a way.', null, 'quote', 39),
('Ask the AI tutor to explain the questions you got wrong.', null, 'tip', 40),
('Quality is not an act, it is a habit.', 'Will Durant', 'quote', 41),
('Cover the options and try to answer first. Then check which option matches.', null, 'tip', 42),
('Start where you are. Use what you have. Do what you can.', 'Arthur Ashe', 'quote', 43),
('Know the units. Many physics and chemistry marks are lost on units.', null, 'tip', 44),
('Success doesn''t come to you. You go to it.', null, 'quote', 45),
('Make a list of your weak topics and fix one each week.', null, 'tip', 46),
('The beautiful thing about learning is that no one can take it away from you.', 'B.B. King', 'quote', 47),
('Plan your week: which subject, which day, how many questions.', null, 'tip', 48),
('Strive for progress, not perfection.', null, 'quote', 49),
('Practise reading fast and well. Comprehension passages reward it.', null, 'tip', 50),
('A little progress each day adds up to big results.', null, 'quote', 51),
('Stay away from exam "expo". Real preparation is the only safe road.', null, 'tip', 52),
('You are capable of more than you know.', null, 'quote', 53),
('Do a full timed mock once a week to build exam stamina.', null, 'tip', 54),
('The pain of studying is far less than the pain of regret.', null, 'quote', 55),
('Mark questions you are unsure of, then review them at the end.', null, 'tip', 56),
('Champions keep playing until they get it right.', 'Billie Jean King', 'quote', 57),
('Learn new words daily. Lexis and structure reward a wide vocabulary.', null, 'tip', 58),
('Today''s practice is tomorrow''s admission letter.', null, 'quote', 59),
('Be proud of how far you have come, and keep going.', null, 'quote', 60);
