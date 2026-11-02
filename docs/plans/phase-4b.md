# Milestone 4B: SolutionTee AI tutor (detailed plan)

Part of Phase 4 (`docs/plans/phase-4.md`). Approval for the phase stays `PREMIUM APPROVED`.

## What the owner asked for (2026-11-02)
- NVIDIA as the main provider, Dahl (inference.dahl.global) as backup.
- Change API keys, add providers and their keys, and add or change models, all from the admin.
- Pictures go only to models that can read images.
- "Make it perfect."

## Findings (tested with the owner's keys)
- **NVIDIA** (`https://integrate.api.nvidia.com/v1`, OpenAI-compatible): 85 models are listed, but many are not open to this key (404) and the free queue can be slow.
  - Chat: `mistralai/mistral-large-4-1t-a52b` answered correctly in 10 s. `minimaxai/minimax-m3.1-flash` was correct but took 76 s. `deepseek-ai/deepseek-v4.1-flash` timed out.
  - Images: `nvidia/nemotron-3.5-super-vl-120b-a12b` read a photo correctly in 15 s. `meta/llama-3.2-90b-vision-instruct` and `google/gemma-4-31b-it` timed out.
  - Embeddings: `nvidia/nemotron-3.5-embed-1b`, 768 dimensions (`dimensions: 768`), under 1 s.
- **Dahl** (`https://inference.dahl.global/v1`, OpenAI-compatible, SSE streaming): text only, no images.
  - `deepseek-ai/DeepSeek-V4-Flash-0731` took 1.6 s, `zai-org/GLM-5.3-Flash` 3.1 s, `MiniMaxAI/MiniMax-M2.7` 3.6 s.
  - MiniMax writes its thinking inside `<think>…</think>`, which must be hidden.
  - Its free tokens must be allocated to the key on the Dahl account page.

## Design
- **Keys** live in Supabase Vault (encrypted). The admin types a key once, and only its last 4 characters are ever shown again. Only the Edge Function (service role) can read keys. Keys never reach the app or the browser after saving.
- **Tables:**
  - `ai_providers`: name, base URL, on/off, key held in Vault plus a hint.
  - `ai_models`: provider, model id, purpose (chat / vision / embed), priority, on/off, temperature, max tokens.
  - `ai_prompts`: versioned system prompt, one active.
  - `ai_chats` and `ai_messages`: the student's own; they can read and soft-delete them.
  - `ai_usage`: per student per Lagos day.
  - `ai_calls`: health log.
  - `ai_cache`: "explain this question" answers.
  - `ai_chunks`: pgvector, 768 dimensions.
- **Quota:** `ai_take()` checks and uses up a prompt in one step. Free 3 and Premium 100 come from the Free vs Premium rules (`ai`). The day resets at midnight Africa/Lagos. There is also a burst limit of 6 prompts a minute. `ai_refund()` gives the prompt back when every model failed.
- **Model order:** one global priority list across providers (lowest number first) for chat, and a separate list for vision.
  - Defaults: NVIDIA Mistral Large 4 → Dahl DeepSeek V4 Flash → NVIDIA MiniMax M3.1 → Dahl GLM 5.3 → NVIDIA DeepSeek V4.1 → Dahl MiniMax M2.7. NVIDIA comes first, and Dahl takes over quickly when NVIDIA is busy.
  - A model gets 20 s to send its first word. After that, or on 404/429/5xx, the next one is tried.
  - Messages with a picture use only vision models: NVIDIA Nemotron 3.5 VL → Llama 3.2 90B Vision → Gemma 4.
- **Edge Function `ai-chat`:**
  1. Checks the login, then takes a prompt from the quota.
  2. Finds up to 4 matching note chunks (RAG).
  3. Adds the system prompt (plus hint mode and subject) and the last 12 messages.
  4. Streams the answer to the app as SSE, with `<think>` and reasoning text removed.
  5. Saves the messages, logs the call, and returns how many prompts are left.
  6. "Explain question X" answers are cached.
- **Edge Function `ai-index`** (admins only): splits published notes into about 1,200-character chunks and adds the embeddings. The admin presses "Rebuild knowledge".
- **Admin → AI tutor:**
  - Providers: add, edit, turn off, change key, and "Test" (lists the models).
  - Models: add one from the provider's list, set purpose, priority, temperature, max tokens, on/off, and "Test" (one short answer).
  - System prompt: versions, with one active.
  - Knowledge: chunk count and "Rebuild".
  - Health: calls, failures and average speed per model over 24 h, plus today's prompt count.
  - Reports: answers students marked wrong.
- **App:** the AI tab follows the prototype (`ai`, `ai-out`):
  - quota chip, subject chips, suggested prompts, "Snap a question" (camera or gallery, shrunk on the phone)
  - hint mode, streaming answers with Markdown + LaTeX (the notes renderer), copy, "this answer is wrong"
  - new chat, history, and the quota-finished screen with a countdown to midnight Lagos time
  - "Ask AI" from Study and Review sends the question along
- **Images:** a photo is shrunk on the phone (1280 px, JPEG about 75%) and sent with that one message. It is not stored. The saved message notes that it had a photo.

## Tests
- SQL: quota (atomic, Lagos day, burst limit, refund, never below zero, Premium 100); students cannot read providers, models, prompts, keys or other students' chats; the key cannot be read through any public function; only admins can set keys.
- App: SSE parser (deltas, done, error, think-stripping), chat screen widget test, quota-finished screen.
- Live: one real streamed answer and one photo answer through the deployed function.

## Risks
- NVIDIA free tier speed and access change without notice, so the admin can reorder or turn off models.
- The keys were shared in chat: the owner will replace them (shown in the admin as "change key").
