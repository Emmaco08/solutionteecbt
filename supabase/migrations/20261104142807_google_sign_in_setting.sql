-- Sign in with Google (D-087): the app shows "Continue with Google" only when this is on and a Web client ID is set.
-- The Web client ID is public (it is inside every app); the client secret lives only in Supabase Auth settings.
insert into public.app_settings (key, value, is_public)
values ('google_auth', '{"enabled": false, "web_client_id": ""}'::jsonb, true)
on conflict (key) do nothing;
