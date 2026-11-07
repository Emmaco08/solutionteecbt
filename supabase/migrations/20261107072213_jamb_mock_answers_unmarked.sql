-- Mock answers are saved unmarked (correct = null) until the student submits.
alter table public.challenge_answers alter column correct drop not null;
