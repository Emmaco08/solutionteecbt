-- D-080 (owner): screenshot / screen-recording block is an admin switch (whole app; tests, challenges and videos),
-- and the direct app updates itself from inside the app (force by default).
insert into public.app_settings (key, value, description, is_public)
values ('screen_protection', '{"whole_app": false, "exams": true}', 'Block screenshots and screen recording (Admin → Flags & settings)', true),
       ('app_update', '{"force": true}', 'In-app update of the direct APK (Admin → Flags & settings)', true)
on conflict (key) do nothing;
