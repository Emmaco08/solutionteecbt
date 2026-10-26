-- SolutionTee CBT · Phase 2 · image access for Cloudflare R2 (D-045)
-- Images are not stored in Supabase. They live in Cloudflare R2:
--   st-question-images (private): signed GET links (a few minutes) are made only by trusted server code
--                                  (Next.js server / Edge Function) after this check says yes.
--   st-public (public, cached on a custom domain): news images, onboarding art, logos.
-- `questions.image_path` and `news_posts.image_path` store the R2 object key, e.g. "q/jamb/2001/mth/7.webp".

/** May the signed-in user see this question image? Used by the image-link signer before it signs. */
create or replace function public.can_view_question_image(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_staff()
      or (not private.is_banned() and exists (
            select 1 from public.questions q
            join public.exam_years y on y.exam_id = q.exam_id and y.subject_id = q.subject_id and y.year = q.year
            where q.image_path = p_key and q.status = 'published' and q.deleted_at is null
              and y.status = 'published'
              and (private.year_open(q.exam_id, q.year, 'cbt') or private.year_open(q.exam_id, q.year, 'pq'))));
$$;

create index questions_image on public.questions (image_path) where image_path is not null;

/** Staff may upload images (the server signs an upload link only when this is true). */
create or replace function public.can_upload_images()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]);
$$;

revoke execute on function public.can_view_question_image, public.can_upload_images from public, anon;
grant execute on function public.can_view_question_image, public.can_upload_images to authenticated;
