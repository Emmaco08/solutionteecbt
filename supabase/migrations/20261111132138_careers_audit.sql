-- Careers: admin changes go to the audit log, and updated_at moves on every edit (same as study_items).
create trigger careers_audit after insert or update or delete on public.careers for each row execute function private.audit_row();
create trigger careers_touch before update on public.careers for each row execute function private.touch_updated_at();

