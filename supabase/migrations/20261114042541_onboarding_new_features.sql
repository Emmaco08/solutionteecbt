-- Onboarding (owner, 13 Nov 2026): slides for Game Zone, the student community and Request a tutor, in this order:
-- CBT, Game Zone, AI tutor, Community, Tutor, Challenges, Study, Progress, Classes. Admin → Onboarding can edit them.
insert into public.onboarding_slides (title, body, animation, sort, enabled)
select v.title, v.body, v.animation, v.sort, true
from (values
  ('Game Zone', 'Live games against students or the SolutionTee Bot: JAMB Duel, Comprehension Clash, Speed Rush and more. Learn while you play and win XP.', 'games', 2),
  ('A friendly student community', 'Ask questions, share tips and help others. Tag @solutiontee and SolutionTee AI joins the chat.', 'community', 4),
  ('Request a real tutor', 'Chat one-to-one with a real teacher who explains any topic at your pace.', 'tutor', 5)
) as v(title, body, animation, sort)
where not exists (select 1 from public.onboarding_slides s where s.animation = v.animation);

update public.onboarding_slides set sort = case animation
  when 'cbt' then 1 when 'games' then 2 when 'ai' then 3 when 'community' then 4 when 'tutor' then 5
  when 'trophy' then 6 when 'study' then 7 when 'progress' then 8 when 'classes' then 9 else sort end;
