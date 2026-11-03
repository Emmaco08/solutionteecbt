// Builds the AI tutor's knowledge (RAG) from published lesson notes (milestone 4B, D-058).
// POST /functions/v1/ai-index   Authorization: Bearer <admin access token, 2-step>
// Body: { mode: "missing" | "all", limit?: number }
// Each call embeds up to `limit` notes (default 25) and answers { done, remaining, chunks }.
// The admin page calls it again until remaining is 0 (keeps each call short and inside NVIDIA's rate limit).

import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });

/** Splits a note into ~1,200-character chunks along headings and paragraphs; pictures are dropped. */
function chunks(title: string, body: string): string[] {
  const clean = body.replace(/!\[[^\]]*\]\([^)]*\)/g, "").replace(/\r\n/g, "\n");
  const sections = clean.split(/\n(?=#{1,4} )/);
  const out: string[] = [];
  for (const s of sections) {
    const heading = s.match(/^#{1,4} (.+)/)?.[1]?.trim();
    let cur = "";
    for (const p of s.split(/\n\s*\n/)) {
      if (cur && cur.length + p.length > 1200) {
        out.push(cur);
        cur = heading ? `${heading} (continued)\n` : "";
      }
      cur += (cur ? "\n\n" : "") + p.trim();
    }
    if (cur.trim().length > 40) out.push(cur);
  }
  return out.map((c) => `${title}\n${c}`.slice(0, 2000));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  // Admins only, with 2-step login (aal2), like the rest of the admin.
  const { data: who } = await admin.auth.getUser(token);
  const uid = who?.user?.id;
  let aal = "";
  try {
    const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    aal = JSON.parse(atob(part + "=".repeat((4 - (part.length % 4)) % 4))).aal ?? "";
  } catch {
    aal = "";
  }
  const { data: staff } = uid ? await admin.from("staff").select("role").eq("user_id", uid).maybeSingle() : { data: null };
  if (!uid || aal !== "aal2" || !staff || !["super_admin", "admin"].includes(staff.role)) return json({ error: "Admins only (log in with 2-step)." }, 403);

  const b = await req.json().catch(() => ({}));
  const mode = b.mode === "all" ? "all" : "missing";
  const limit = Math.min(Math.max(Number(b.limit) || 10, 1), 40);

  const { data: cfg } = await admin.rpc("ai_config");
  const m = ((cfg?.models ?? []) as { purpose: string; model: string; base_url: string; key: string; dimensions: number | null; provider: string }[]).find((x) => x.purpose === "embed");
  if (!m) return json({ error: "Add an embedding model (purpose: embed) first." }, 400);

  // Which notes still need work: "all" starts over; "missing" = notes with no chunks or edited after their chunks.
  if (mode === "all" && b.restart === true) await admin.from("ai_chunks").delete().eq("source", "note");
  const { data: notes, error } = await admin
    .from("study_items")
    .select("id, title, subject_id, body, updated_at")
    .eq("kind", "note")
    .eq("status", "published")
    .is("deleted_at", null)
    .order("updated_at", { ascending: true });
  if (error) return json({ error: error.message }, 500);
  const { data: have } = await admin.rpc("ai_chunk_sources", { p_source: "note" });
  const newest = new Map<string, number>();
  for (const h of (have ?? []) as { source_id: string; indexed_at: string }[]) newest.set(h.source_id, Date.parse(h.indexed_at));
  const todo = (notes ?? []).filter((n) => (n.body ?? "").trim().length > 40 && (!newest.has(n.id) || newest.get(n.id)! < Date.parse(n.updated_at)));
  // Notes that were deleted or unpublished lose their chunks.
  const live = new Set((notes ?? []).map((n) => n.id));
  const gone = [...newest.keys()].filter((id) => !live.has(id));
  if (gone.length) await admin.from("ai_chunks").delete().eq("source", "note").in("source_id", gone);

  let made = 0;
  const t = Date.now();
  for (const n of todo.slice(0, limit)) {
    const title = n.title.replace("[SAMPLE] ", "");
    const parts = chunks(title, n.body ?? "");
    if (!parts.length) continue;
    // NVIDIA's embedding service sometimes fails on batches: try the batch twice, then one piece at a time.
    const embedMany = async (inputs: string[]): Promise<number[][]> => {
      const r = await fetch(`${m.base_url}/embeddings`, {
        method: "POST",
        headers: { authorization: `Bearer ${m.key}`, "content-type": "application/json" },
        body: JSON.stringify({ model: m.model, input: inputs, input_type: "passage", encoding_format: "float", ...(m.dimensions ? { dimensions: m.dimensions } : {}) }),
        signal: AbortSignal.timeout(30000),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status} ${(await r.text()).slice(0, 160)}`);
      const j = await r.json();
      return (j.data as { embedding: number[]; index: number }[]).sort((a, b) => a.index - b.index).map((d) => d.embedding);
    };
    let vectors: number[][] | null = null;
    let lastErr = "";
    for (let attempt = 0; attempt < 2 && !vectors; attempt++) {
      try {
        vectors = await embedMany(parts);
      } catch (e) {
        lastErr = String(e);
      }
    }
    if (!vectors) {
      vectors = [];
      for (const part of parts) {
        let v: number[] | null = null;
        for (let attempt = 0; attempt < 3 && !v; attempt++) {
          try {
            v = (await embedMany([part]))[0];
          } catch (e) {
            lastErr = String(e);
            await new Promise((res) => setTimeout(res, 800));
          }
        }
        if (!v) {
          await admin.from("ai_calls").insert({ provider: m.provider, model: m.model, purpose: "embed", ok: false, ms: Date.now() - t, error: lastErr.slice(0, 300) });
          return json({ error: `The embedding model failed: ${lastErr}`, done: made }, 502);
        }
        vectors.push(v);
      }
    }
    await admin.from("ai_chunks").delete().eq("source", "note").eq("source_id", n.id);
    const rows = vectors.map((v, i) => ({
      source: "note",
      source_id: n.id,
      subject_id: n.subject_id,
      title,
      content: parts[i].slice(title.length + 1),
      embedding: JSON.stringify(v),
    }));
    const { error: ie } = await admin.from("ai_chunks").insert(rows);
    if (ie) return json({ error: ie.message, done: made }, 500);
    made++;
  }
  await admin.from("ai_calls").insert({ provider: m.provider, model: m.model, purpose: "embed", ok: true, ms: Date.now() - t });
  const { count } = await admin.from("ai_chunks").select("id", { count: "exact", head: true });
  return json({ done: made, remaining: Math.max(todo.length - made, 0), chunks: count ?? 0 });
});
