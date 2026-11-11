-- D-135: exam countdown. Admin → Motivation → Exam countdown sets the date of each exam; the app shows a full-screen
-- countdown on the first open of each day ("daily") and a small chip on Home. Public: only dates and switches.
insert into public.app_settings (key, value, is_public)
values ('exam_countdown', '{"on": true, "daily": true, "dates": {}}', true)
on conflict (key) do nothing;
