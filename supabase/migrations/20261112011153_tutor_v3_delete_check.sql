alter table public.tutor_messages drop constraint tutor_messages_body_check;
alter table public.tutor_messages add constraint tutor_messages_body_check
  check (char_length(body) <= 4000 and (kind <> 'text' or deleted_at is not null or char_length(btrim(body)) >= 1));
