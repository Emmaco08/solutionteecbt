-- Onboarding text for Game Zone, Community and Request a tutor, shorter and clearer (owner, 14 Nov 2026).
-- Only rows still holding the first text are changed, so edits made in Admin are kept.
update public.onboarding_slides set title = 'Game Zone: learn by playing',
  body = 'Battle other students or the SolutionTee Bot in fast exam games. Every game is real practice, and every win earns XP.'
where animation = 'games' and title = 'Game Zone';
update public.onboarding_slides set title = 'Learn together',
  body = 'Ask any question and get help fast from other students and SolutionTee AI. Share tips and help others too.'
where animation = 'community' and title = 'A friendly student community';
update public.onboarding_slides set title = 'Your own real tutor',
  body = 'Book a real teacher for one-to-one lessons in chat. Any topic, explained step by step, at your pace.'
where animation = 'tutor' and title = 'Request a real tutor';
