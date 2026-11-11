-- 30 sample badges (B8, D-142). Rewards are a starting point for the owner to change in Admin → Badges:
-- XP at every level, plus free Premium days at diamond for the hardest ones. No cash.
with r(k, v) as (values
  ('std', '{"bronze":{"xp":20},"silver":{"xp":50},"gold":{"xp":100},"diamond":{"xp":250}}'::jsonb),
  ('big', '{"bronze":{"xp":30},"silver":{"xp":75},"gold":{"xp":150},"diamond":{"xp":300,"days":7}}'::jsonb)
)
insert into public.badges (key, name, description, icon, metric, targets, rewards, sort)
select b.key, b.name, b.description, b.icon, b.metric, b.targets::jsonb, r.v, b.sort
from (values
  ('daily_habit', 'Daily habit', 'Practise many days in a row.', 'fire', 'streak', '{"bronze":3,"silver":7,"gold":30,"diamond":100}', 'big', 10),
  ('test_taker', 'Test taker', 'Finish tests of any kind.', 'exam', 'tests', '{"bronze":5,"silver":25,"gold":100,"diamond":500}', 'std', 20),
  ('sharp_mind', 'Sharp mind', 'Get questions right.', 'target', 'correct', '{"bronze":50,"silver":250,"gold":1000,"diamond":5000}', 'big', 30),
  ('question_crusher', 'Question crusher', 'Answer questions in tests.', 'checkFat', 'questions', '{"bronze":100,"silver":500,"gold":2500,"diamond":10000}', 'std', 40),
  ('jamb_high', 'JAMB high scorer', 'Your best score in a full JAMB mock.', 'trophy', 'jamb_best', '{"bronze":200,"silver":250,"gold":300,"diamond":350}', 'big', 50),
  ('full_mock', 'Full mock', 'Finish full JAMB mocks.', 'timer', 'full_mocks', '{"bronze":1,"silver":5,"gold":20,"diamond":50}', 'std', 60),
  ('perfect', 'Perfect score', 'Get every question right (10 or more).', 'sealCheck', 'perfect', '{"bronze":1,"silver":5,"gold":20,"diamond":50}', 'big', 70),
  ('strong_pass', 'Strong pass', 'Score 70% or more in a test.', 'chartLineUp', 'score70', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 80),
  ('speedster', 'Speedster', '20+ answers, under 30 s each, 70% right.', 'lightning', 'speed', '{"bronze":1,"silver":5,"gold":20,"diamond":50}', 'std', 90),
  ('days_studied', 'Days studied', 'Days you finished at least one test.', 'calendarCheck', 'days', '{"bronze":5,"silver":20,"gold":60,"diamond":150}', 'big', 100),
  ('study_hours', 'Study hours', 'Hours spent in tests.', 'clock', 'hours', '{"bronze":5,"silver":25,"gold":100,"diamond":300}', 'std', 110),
  ('night_owl', 'Night owl', 'Finish tests after 10 pm.', 'moonStars', 'night', '{"bronze":1,"silver":10,"gold":30,"diamond":100}', 'std', 120),
  ('early_bird', 'Early bird', 'Finish tests between 5 and 8 am.', 'sunHorizon', 'early', '{"bronze":1,"silver":10,"gold":30,"diamond":100}', 'std', 130),
  ('weekend', 'Weekend warrior', 'Finish tests on Saturdays and Sundays.', 'calendarStar', 'weekend', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 140),
  ('topic_drill', 'Topic driller', 'Finish topic drills.', 'listChecks', 'topic_tests', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 150),
  ('subject_master', 'Subject master', 'Finish single-subject tests.', 'bookOpenText', 'subject_tests', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 160),
  ('quick_fire', 'Quick fire', 'Finish quick tests.', 'hourglass', 'quick_tests', '{"bronze":5,"silver":25,"gold":75,"diamond":200}', 'std', 170),
  ('exam_builder', 'Exam builder', 'Finish custom exams you built.', 'gearSix', 'custom_tests', '{"bronze":1,"silver":5,"gold":20,"diamond":60}', 'std', 180),
  ('bookworm', 'Bookworm', 'Finish lessons, notes, videos or novels.', 'books', 'lessons', '{"bronze":5,"silver":20,"gold":60,"diamond":150}', 'std', 190),
  ('video_learner', 'Video learner', 'Watch videos to the end.', 'playCircle', 'videos', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 200),
  ('note_reader', 'Note reader', 'Read lesson notes to the end.', 'notePencil', 'notes', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 210),
  ('literature', 'Literature lover', 'Finish JAMB literature novels.', 'bookOpen', 'novels', '{"bronze":1,"silver":2,"gold":3,"diamond":5}', 'std', 220),
  ('curious', 'Curious mind', 'Start chats with the AI tutor.', 'sparkle', 'ai_chats', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 230),
  ('challenger', 'Challenger', 'Finish challenges and events.', 'flagCheckered', 'challenges', '{"bronze":1,"silver":5,"gold":20,"diamond":50}', 'std', 240),
  ('top_three', 'Top three', 'Finish a challenge in the top 3.', 'medal', 'podium', '{"bronze":1,"silver":3,"gold":10,"diamond":25}', 'big', 250),
  ('friend_maker', 'Friend maker', 'Friends who joined with your invite.', 'users', 'referrals', '{"bronze":1,"silver":3,"gold":10,"diamond":25}', 'big', 260),
  ('daily_question', 'Question of the day', 'Answer the question of the day right.', 'lightbulb', 'qotd', '{"bronze":5,"silver":20,"gold":60,"diamond":200}', 'std', 270),
  ('xp_collector', 'XP collector', 'XP earned in total.', 'coins', 'xp', '{"bronze":500,"silver":2000,"gold":10000,"diamond":50000}', 'std', 280),
  ('news_voice', 'Community voice', 'Comment on news posts.', 'chatCircleText', 'comments', '{"bronze":1,"silver":10,"gold":30,"diamond":100}', 'std', 290),
  ('news_fan', 'News fan', 'Like news posts.', 'heart', 'likes', '{"bronze":3,"silver":15,"gold":50,"diamond":150}', 'std', 300)
) as b(key, name, description, icon, metric, targets, rk, sort)
join r on r.k = b.rk;

