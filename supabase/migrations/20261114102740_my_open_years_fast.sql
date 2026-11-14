-- my_open_years: same answers, 20-30x faster (tested against the old version for free, premium, ad-unlock, staff,
-- signed-out and random students: 0 differences; 1.5-2 s → about 60 ms).
create or replace function public.my_open_years(p_exam smallint default null)
returns table(exam_id smallint, subject_id smallint, year smallint, cbt_open boolean, pq_open boolean)
language sql stable security definer set search_path = '' as $$
  select * from private.my_open_years_fast(p_exam);
$$;
