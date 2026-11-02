-- Extra request settings per model (for example {"chat_template_kwargs":{"thinking":false}}), merged into the provider request.
alter table public.ai_models add column params jsonb not null default '{}'::jsonb check (jsonb_typeof(params) = 'object');

-- GLM 5.3 Flash thinks at length before answering: give it room, and try it after the faster models.
update public.ai_models set max_tokens = 6000, priority = 7 where model = 'zai-org/GLM-5.3-Flash';

create or replace function public.ai_config() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'models', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', m.id, 'model', m.model, 'purpose', m.purpose, 'priority', m.priority,
               'temperature', m.temperature, 'max_tokens', m.max_tokens, 'dimensions', m.dimensions, 'params', m.params,
               'provider', p.name, 'base_url', p.base_url, 'key', s.decrypted_secret)
             order by m.priority, m.created_at)
      from public.ai_models m
      join public.ai_providers p on p.id = m.provider_id and p.enabled
      join vault.decrypted_secrets s on s.id = p.key_secret
      where m.enabled), '[]'::jsonb),
    'prompt', (select body from public.ai_prompts where active limit 1));
$$;
revoke all on function public.ai_config() from public, anon, authenticated;
grant execute on function public.ai_config() to service_role;
