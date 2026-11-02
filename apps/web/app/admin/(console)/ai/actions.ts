"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient, createServiceClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

// Admin → AI tutor (D-058). Only super admins and admins. API keys go straight into Supabase Vault through
// admin_set_ai_key(); this file never reads a key back except on the server to run a "Test" call.
const admins = () => requireStaff(["super_admin", "admin"]);
const on = z.enum(["on"]).optional().transform((v) => v === "on");
const done = () => revalidatePath("/admin/ai");

// ---------------- providers
const Provider = z.object({
  id: z.string().uuid().optional().or(z.literal("").transform(() => undefined)),
  name: z.string().trim().min(2, "Name is too short").max(60),
  base_url: z.string().trim().url("Use a full https:// address").regex(/^https:\/\//, "Use https://").transform((v) => v.replace(/\/+$/, "")),
  notes: z.string().trim().max(500).transform((v) => v || null),
  enabled: on,
});

export async function saveProvider(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Provider.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the provider" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const { error } = id ? await supabase.from("ai_providers").update(row).eq("id", id) : await supabase.from("ai_providers").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: id ? "Provider saved." : "Provider added. Now set its API key." };
}

export async function deleteProvider(id: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.from("ai_providers").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: "Provider and its models removed." };
}

export async function setProviderKey(form: FormData): Promise<ActionResult> {
  await admins();
  const id = String(form.get("id") ?? "");
  const key = String(form.get("key") ?? "").trim();
  if (!z.string().uuid().safeParse(id).success) return { ok: false, error: "Unknown provider." };
  if (key.length < 8) return { ok: false, error: "Paste the full API key." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_set_ai_key", { p_provider: id, p_key: key });
  if (error) return { ok: false, error: error.message === "bad_key" ? "That does not look like an API key (no spaces, 8–400 characters)." : friendlyError(error) };
  done();
  return { ok: true, message: `Key saved (ends ${data}). It is stored encrypted and will not be shown again.` };
}

/** Lists the provider's models with its saved key (server only). */
async function providerModels(id: string) {
  const svc = await createServiceClient();
  const [{ data: key }, { data: p }] = await Promise.all([
    svc.rpc("ai_provider_key", { p_provider: id }),
    svc.from("ai_providers").select("base_url").eq("id", id).maybeSingle(),
  ]);
  if (!p) throw new Error("Unknown provider.");
  if (!key) throw new Error("Set the API key first.");
  const t = Date.now();
  const r = await fetch(`${p.base_url}/models`, { headers: { authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(20000), cache: "no-store" });
  if (!r.ok) throw new Error(r.status === 401 || r.status === 403 ? "The provider refused the key (wrong or expired key)." : `The provider answered HTTP ${r.status}.`);
  const j = await r.json();
  const ids = ((j.data ?? j.models ?? []) as { id?: string; name?: string }[]).map((m) => m.id ?? m.name ?? "").filter(Boolean).sort();
  return { ids, ms: Date.now() - t };
}

export async function testProvider(id: string): Promise<ActionResult<{ ids: string[]; ms: number }>> {
  await admins();
  try {
    const data = await providerModels(id);
    return { ok: true, data, message: `Connected in ${(data.ms / 1000).toFixed(1)} s. ${data.ids.length} models available.` };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : "Could not reach the provider." };
  }
}

// ---------------- models
const Model = z.object({
  id: z.string().uuid().optional().or(z.literal("").transform(() => undefined)),
  provider_id: z.string().uuid("Choose a provider"),
  model: z.string().trim().min(2, "Type the model id").max(120),
  label: z.string().trim().max(60).transform((v) => v || null),
  purpose: z.enum(["chat", "vision", "embed"]),
  priority: z.coerce.number().int().min(1).max(99),
  temperature: z.coerce.number().min(0).max(2),
  max_tokens: z.coerce.number().int().min(64).max(16000),
  dimensions: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(64).max(4096)]).optional().transform((v) => v ?? null),
  params: z.string().trim().transform((v, ctx) => {
    if (!v) return {};
    try {
      const o = JSON.parse(v);
      if (o && typeof o === "object" && !Array.isArray(o)) return o as Record<string, unknown>;
    } catch {
      /* falls through */
    }
    ctx.addIssue({ code: "custom", message: 'Extra settings must be JSON like {"chat_template_kwargs":{"thinking":false}}' });
    return z.NEVER;
  }),
  enabled: on,
});

export async function saveModel(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Model.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the model" };
  const { id, params, ...rest } = p.data;
  const row = { ...rest, params: params as never };
  const supabase = await createClient();
  const { error } = id ? await supabase.from("ai_models").update(row).eq("id", id) : await supabase.from("ai_models").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: id ? "Model saved." : "Model added." };
}

export async function deleteModel(id: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.from("ai_models").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: "Model removed." };
}

/** Sends one short question to a model (or one embedding) and reports the time and the reply. */
export async function testModel(id: string): Promise<ActionResult> {
  await admins();
  const svc = await createServiceClient();
  const { data: m } = await svc.from("ai_models").select("model, purpose, max_tokens, temperature, dimensions, params, ai_providers(name, base_url)").eq("id", id).maybeSingle();
  if (!m) return { ok: false, error: "Unknown model." };
  const p = m.ai_providers as unknown as { name: string; base_url: string } | null;
  const providerId = (await svc.from("ai_models").select("provider_id").eq("id", id).single()).data?.provider_id;
  const { data: key } = await svc.rpc("ai_provider_key", { p_provider: providerId! });
  if (!p || !key) return { ok: false, error: "Set the provider's API key first." };
  const t = Date.now();
  try {
    const body =
      m.purpose === "embed"
        ? { model: m.model, input: ["Indices and logarithms"], input_type: "query", encoding_format: "float", ...(m.dimensions ? { dimensions: m.dimensions } : {}) }
        : { ...((m.params as Record<string, unknown>) ?? {}), model: m.model, max_tokens: Math.max(m.max_tokens, 512), temperature: Number(m.temperature), messages: [{ role: "user", content: "Solve 2x + 3 = 11. Reply in one short line." }] };
    const r = await fetch(`${p.base_url}/${m.purpose === "embed" ? "embeddings" : "chat/completions"}`, {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(60000),
      cache: "no-store",
    });
    const ms = Date.now() - t;
    const text = await r.text();
    if (!r.ok) {
      await svc.from("ai_calls").insert({ provider: p.name, model: m.model, purpose: m.purpose, ok: false, ms, error: `test: HTTP ${r.status} ${text.slice(0, 200)}` });
      return { ok: false, error: r.status === 404 ? "This model is not available for your key (404)." : `HTTP ${r.status}: ${text.slice(0, 160)}` };
    }
    const j = JSON.parse(text);
    await svc.from("ai_calls").insert({ provider: p.name, model: m.model, purpose: m.purpose, ok: true, ms });
    if (m.purpose === "embed") return { ok: true, message: `Works: ${j.data?.[0]?.embedding?.length ?? "?"} numbers in ${(ms / 1000).toFixed(1)} s.` };
    const reply = String(j.choices?.[0]?.message?.content ?? "").replace(/<think>[\s\S]*?<\/think>/g, "").trim();
    return { ok: true, message: reply ? `Answered in ${(ms / 1000).toFixed(1)} s: "${reply.slice(0, 120)}"` : `Replied in ${(ms / 1000).toFixed(1)} s but wrote no answer (it may need a higher max tokens).` };
  } catch {
    await svc.from("ai_calls").insert({ provider: p.name, model: m.model, purpose: m.purpose, ok: false, ms: Date.now() - t, error: "test: timed out" });
    return { ok: false, error: "No answer within 60 seconds. The model is busy or too slow right now." };
  }
}

// ---------------- system prompt (versions)
export async function savePrompt(form: FormData): Promise<ActionResult> {
  await admins();
  const body = String(form.get("body") ?? "").trim();
  const notes = String(form.get("notes") ?? "").trim() || null;
  if (body.length < 20) return { ok: false, error: "The prompt is too short." };
  const supabase = await createClient();
  const { data: last } = await supabase.from("ai_prompts").select("version").order("version", { ascending: false }).limit(1).maybeSingle();
  const { error: e1 } = await supabase.from("ai_prompts").update({ active: false }).eq("active", true);
  if (e1) return { ok: false, error: friendlyError(e1) };
  const { error } = await supabase.from("ai_prompts").insert({ version: (last?.version ?? 0) + 1, body, notes, active: true });
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: `Saved as version ${(last?.version ?? 0) + 1} and switched on. Students get it within a minute.` };
}

export async function activatePrompt(id: number): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error: e1 } = await supabase.from("ai_prompts").update({ active: false }).eq("active", true);
  if (e1) return { ok: false, error: friendlyError(e1) };
  const { error } = await supabase.from("ai_prompts").update({ active: true }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  done();
  return { ok: true, message: "That version is now in use." };
}
