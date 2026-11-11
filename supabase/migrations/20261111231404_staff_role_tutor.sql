-- Tutor v2 (D-152): a staff role for tutors. They see only their own students (see tutor_v2).
alter type public.staff_role add value if not exists 'tutor';

