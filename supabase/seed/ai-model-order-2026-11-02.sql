-- AI model order chosen from live tests on 2026-11-02 (D-058). Already applied to the dev project; the admin can
-- change it any time in Admin → AI tutor. Times are first words / full answer on a JAMB maths question.
--   chat:   1 NVIDIA nemotron-3-nano-omni-30b-a3b-reasoning (2.4 s / 3.4 s) · 2 NVIDIA nemotron-3-ultra-550b-a55b (2.2 s / 3.5 s)
--           3 Dahl DeepSeek-V4-Flash-0731 (1.9 s / up to 59 s when Dahl is busy) · 4 NVIDIA mistral-large-4 (often thinks >25 s)
--           5 Dahl MiniMax-M2.7 · 6 NVIDIA muse-glimmer-30b (26 s) · 7 Dahl GLM-5.3-Flash (long thinking) · 8–9 slow NVIDIA models
--   vision: 1 NVIDIA nemotron-3.5-super-vl-120b-a12b (3.4 s / 3.9 s) · 2 NVIDIA nemotron-3-nano-omni (6.4 s / 8.1 s)
--           3 NVIDIA muse-glimmer-30b (timed out in the test) · 4 llama-3.2-90b-vision · 5 gemma-4-31b-it
with n as (select id from public.ai_providers where name = 'NVIDIA')
insert into public.ai_models (provider_id, model, label, purpose, priority, temperature, max_tokens)
select n.id, v.model, v.label, v.purpose, v.priority, v.temperature, v.max_tokens from n, (values
  ('nvidia/nemotron-3-nano-omni-30b-a3b-reasoning', 'Nemotron 3 Nano Omni', 'chat', 1, 0.3, 3000),
  ('nvidia/nemotron-3-ultra-550b-a55b', 'Nemotron 3 Ultra 550B', 'chat', 2, 0.3, 3000),
  ('meta/muse-glimmer-30b', 'Muse Glimmer 30B', 'chat', 6, 0.3, 3000),
  ('nvidia/nemotron-3-nano-omni-30b-a3b-reasoning', 'Nemotron 3 Nano Omni', 'vision', 2, 0.2, 3000),
  ('meta/muse-glimmer-30b', 'Muse Glimmer 30B', 'vision', 3, 0.2, 3000)
) as v(model, label, purpose, priority, temperature, max_tokens)
on conflict (provider_id, model, purpose) do update set priority = excluded.priority, max_tokens = excluded.max_tokens, enabled = true;
update public.ai_models set priority = 3, max_tokens = 3000 where model = 'deepseek-ai/DeepSeek-V4-Flash-0731';
update public.ai_models set priority = 4, max_tokens = 3000 where model = 'mistralai/mistral-large-4-1t-a52b';
update public.ai_models set priority = 5, max_tokens = 3000 where model = 'MiniMaxAI/MiniMax-M2.7';
update public.ai_models set priority = 7 where model = 'zai-org/GLM-5.3-Flash';
update public.ai_models set priority = 8, max_tokens = 3000 where model = 'minimaxai/minimax-m3.1-flash';
update public.ai_models set priority = 9, max_tokens = 3000 where model = 'deepseek-ai/deepseek-v4.1-flash';
update public.ai_models set priority = 1, max_tokens = 4000 where model = 'nvidia/nemotron-3.5-super-vl-120b-a12b';
update public.ai_models set priority = 4 where model = 'meta/llama-3.2-90b-vision-instruct';
update public.ai_models set priority = 5 where model = 'google/gemma-4-31b-it';

-- 2026-11-03: nemotron-3.5-embed-1b failed most batched requests (HTTP 500); llama-nemotron-embed-vl-1b-v2 handled them.
insert into public.ai_models (provider_id, model, label, purpose, priority, temperature, max_tokens, dimensions)
select id, 'nvidia/llama-nemotron-embed-vl-1b-v2', 'Llama Nemotron Embed VL 1B v2', 'embed', 1, 0, 64, 768 from public.ai_providers where name = 'NVIDIA'
on conflict (provider_id, model, purpose) do update set priority = 1, enabled = true, dimensions = 768;
update public.ai_models set priority = 2, enabled = false where model = 'nvidia/nemotron-3.5-embed-1b';
