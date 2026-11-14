-- A session inside a programme has no price of its own: the programme is what students buy.
alter table public.classes drop constraint classes_check;
alter table public.classes add constraint classes_check check (access <> 'paid' or price_kobo is not null or program_id is not null);
