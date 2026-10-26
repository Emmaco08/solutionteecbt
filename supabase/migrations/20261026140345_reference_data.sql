-- SolutionTee CBT · Phase 2 · reference data every environment needs (editable later in the admin)
-- Plan prices are the SAMPLE prices from the approved prototype; the owner confirms them before launch.

insert into public.exam_bodies (code, name, logo_path, sort) values
  ('JAMB', 'JAMB UTME', 'brand/exam-bodies/jamb.png', 1),
  ('WAEC', 'WAEC WASSCE', 'brand/exam-bodies/waec.png', 2),
  ('NECO', 'NECO SSCE', 'brand/exam-bodies/neco.png', 3);

insert into public.subjects (code, name, sort) values
  ('eng', 'Use of English', 1), ('mth', 'Mathematics', 2), ('phy', 'Physics', 3), ('chm', 'Chemistry', 4),
  ('bio', 'Biology', 5), ('eco', 'Economics', 6), ('gov', 'Government', 7), ('lit', 'Literature in English', 8),
  ('com', 'Commerce', 9), ('acc', 'Financial Accounting', 10), ('geo', 'Geography', 11),
  ('crs', 'Christian Religious Studies', 12), ('irs', 'Islamic Religious Studies', 13),
  ('agr', 'Agricultural Science', 14), ('fmt', 'Further Mathematics', 15), ('civ', 'Civic Education', 16),
  ('his', 'History', 17), ('cmp', 'Computer Studies', 18);

-- JAMB: 4 subjects, Use of English compulsory (60 questions), others 40; 120 minutes; scaled to 400.
insert into public.exam_configs (exam_id, subjects_per_candidate, total_minutes, score_scale, max_options, rules)
select id, 4, 120, 400, 4, '{"compulsory": ["eng"], "per_subject_scale": 100}'::jsonb from public.exam_bodies where code = 'JAMB';
-- WAEC / NECO: one objective paper per subject; per-subject count and time below (editable).
insert into public.exam_configs (exam_id, subjects_per_candidate, total_minutes, score_scale, max_options, rules)
select id, 1, null, 100, 4, '{}'::jsonb from public.exam_bodies where code in ('WAEC', 'NECO');

insert into public.exam_subjects (exam_id, subject_id, compulsory, question_count, minutes)
select e.id, s.id, s.code = 'eng', case when s.code = 'eng' then 60 else 40 end, null
from public.exam_bodies e cross join public.subjects s
where e.code = 'JAMB' and s.code not in ('fmt', 'civ', 'cmp');

insert into public.exam_subjects (exam_id, subject_id, compulsory, question_count, minutes)
select e.id, s.id, false, 50, 60
from public.exam_bodies e cross join public.subjects s
where e.code in ('WAEC', 'NECO');

-- Free vs Premium (D-027). Same keys as the approved prototype.
insert into public.access_rules (tier, rules, updated_by) values
  ('free', '{"jamb": 3, "waec": 3, "neco": 3, "pq": 2, "which": "oldest", "videos": false, "lessons": false, "notes": false, "novels": false, "syllabus": 2, "ai": 3, "offline": false, "compete": true}', null),
  ('premium', '{"jamb": "all", "waec": "all", "neco": "all", "pq": "all", "which": "oldest", "videos": true, "lessons": true, "notes": true, "novels": true, "syllabus": "all", "ai": 100, "offline": true, "compete": true}', null);

insert into public.plans (code, name, description, price_kobo, duration_days, ends_on, sort) values
  ('monthly', 'Monthly', 'SAMPLE price. Billed once. No auto-renew.', 150000, 30, null, 1),
  ('three_months', '3 Months', 'SAMPLE price. Save ₦1,000.', 350000, 90, null, 2),
  ('exam_season', 'Exam Season', 'SAMPLE price. Covers JAMB, WAEC and NECO 2027.', 600000, null, '2027-07-31', 3);

insert into public.app_tabs (key, title, icon, type, sort) values
  ('home', 'Home', 'house', 'home', 1), ('study', 'Study', 'book-open-text', 'study', 2),
  ('test', 'Test', 'exam', 'test', 3), ('ai', 'AI Tutor', 'sparkle', 'ai_chat', 4), ('me', 'Me', 'user-circle', 'profile', 5);

insert into public.onboarding_slides (title, body, animation, sort) values
  ('A real CBT experience', 'Practise JAMB, WAEC and NECO exactly like the real computer-based test.', 'cbt', 1),
  ('Win cash prizes every week', 'Answer our weekly challenge fast and right to win. Free and Premium students can join.', 'trophy', 2),
  ('Past questions, videos and notes', 'Every answer explained, with video solutions and simple lesson notes.', 'study', 3),
  ('SolutionTee AI tutor', 'Stuck? Ask the AI tutor. It explains step by step, like a good teacher.', 'ai', 4),
  ('See your progress', 'Track your scores, find your weak topics and watch yourself improve.', 'progress', 5),
  ('Join live JAMB classes', 'Learn with our teachers in live online classes.', 'classes', 6);

insert into public.feature_flags (key, enabled, description, updated_by) values
  ('challenges_enabled', true, 'Show challenges, prizes and the Winners wall.', null),
  ('referrals_enabled', true, 'Invite friends, discount codes and cash rewards.', null),
  ('ai_photo_questions', true, 'Students can attach a photo to the AI tutor (needs a vision model).', null),
  ('paystack_in_play_build', false, 'Keep OFF until Google''s billing-choice programme covers Nigeria and we enrol.', null),
  ('paid_events_in_play_build', false, 'Keep OFF until a lawyer confirms paid contests are allowed.', null),
  ('cash_challenges_on_web', false, 'Allow cash-prize challenges in the web app (anti-cheat is weaker in a browser).', null),
  ('leaderboard_enabled', true, 'Show leaderboards (also controlled in Leaderboard settings).', null);

insert into public.app_settings (key, value, description, is_public, updated_by) values
  ('min_app_version', '{"android": "1.0.0", "force": false}', 'Older app versions are asked (or forced) to update.', true, null),
  ('maintenance', '{"enabled": false, "message": "We are improving SolutionTee. Back in 30 minutes."}', 'Maintenance mode for the app and web app.', true, null),
  ('support', '{"whatsapp": "+2348122445948", "whatsapp_link": "https://wa.me/2348122445948", "email": null}', 'Support contacts shown in Help.', true, null),
  ('company', '{"name": "SolutionTee", "rc_number": "RC 9123561", "address": "Diamond Estate, 1 Obashoro St, off Command Road, Ipaja, Lagos 100276, Lagos, Nigeria", "website": "https://solutiontee.com", "web_app": "https://app.solutiontee.com"}', 'Company details for About, legal pages and receipts.', true, null),
  ('disclaimer', '"SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO."', 'Shown on onboarding, About, Terms and store listings.', true, null);

-- Reference rows above are setup, not admin actions: clear their audit rows.
delete from public.audit_log;
