-- Owner's slide order (2026-10-30): CBT, weekly cash challenge, AI tutor, past questions, progress, live classes.
update public.onboarding_slides set sort = case animation
  when 'cbt' then 1 when 'trophy' then 2 when 'ai' then 3 when 'study' then 4 when 'progress' then 5 when 'classes' then 6 else sort end;
