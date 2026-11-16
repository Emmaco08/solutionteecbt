-- WhatsApp channel (owner, 16 Nov 2026, D-174): the admin sets the channel link in Admin → Flags & settings; the app shows
-- a "Join our WhatsApp channel" card at the bottom of Home and News, and a pop-up on every app open until the student
-- taps Join. A tap is remembered here (so a new phone or a reinstall does not ask again) and counted for the admin.

insert into public.app_settings (key, value, description, is_public)
values ('whatsapp_channel', '{"enabled": true, "popup": true, "url": "", "title": "", "text": ""}'::jsonb,
        'WhatsApp channel link, card and pop-up in the app (D-174)', true)
on conflict (key) do nothing;

create table if not exists public.channel_joins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  url text not null,
  joined_at timestamptz not null default now()
);
alter table public.channel_joins enable row level security;
drop policy if exists "own row" on public.channel_joins;
create policy "own row" on public.channel_joins for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "staff read" on public.channel_joins;
create policy "staff read" on public.channel_joins for select to authenticated using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));

/** The student tapped Join on the WhatsApp channel link (the app passes the link it opened). */
create or replace function public.channel_joined(p_url text)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or coalesce(p_url, '') = '' then return; end if;
  insert into public.channel_joins (user_id, url) values (v_uid, left(p_url, 300))
  on conflict (user_id) do update set url = excluded.url, joined_at = now();
end;
$$;
revoke all on function public.channel_joined(text) from public, anon;
grant execute on function public.channel_joined(text) to authenticated;
