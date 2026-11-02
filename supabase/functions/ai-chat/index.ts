// SolutionTee AI tutor (milestone 4B, docs/plans/phase-4b.md, D-058).
// POST /functions/v1/ai-chat   Authorization: Bearer <student access token>
// Body: { chat_id?, text?, image?: base64 JPEG/PNG (no data: prefix), subject_id?, hint?, question_id?, explain? }
// Answers as Server-Sent Events:
//   data: {"t":"start","chat_id":"…"}         once, first
//   data: {"t":"think"}                       the model is thinking (no words yet)
//   data: {"t":"d","c":"…"}                   pieces of the answer (Markdown + LaTeX)
//   data: {"t":"done","message_id":"…","left":2,"model":"…"}
//   data: {"t":"error","code":"busy"|"partial","message":"…"}
// Errors before the stream starts are plain JSON with an HTTP status (401, 400, 404, 429 quota/slow, 403 banned).
// Provider keys come from Vault through ai_config() (service role). They never leave this function.

import { createClient } from "npm:@supabase/supabase-js@2.57.4";

type Model = {
  id: string;
  model: string;
  purpose: "chat" | "vision" | "embed";
  priority: number;
  temperature: number;
  max_tokens: number;
  dimensions: number | null;
  provider: string;
  base_url: string;
  key: string;
  params?: Record<string, unknown>;
};
type Msg = { role: "system" | "user" | "assistant"; content: unknown };

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

let cfgCache: { at: number; models: Model[]; prompt: string } | null = null;
async function config() {
  if (cfgCache && Date.now() - cfgCache.at < 60_000) return cfgCache;
  const { data, error } = await admin.rpc("ai_config");
  if (error) throw new Error("config: " + error.message);
  cfgCache = { at: Date.now(), models: (data?.models ?? []) as Model[], prompt: (data?.prompt as string) ?? "" };
  return cfgCache;
}

async function logCall(m: Model, purpose: string, ok: boolean, ms: number, error?: string) {
  await admin.from("ai_calls").insert({ provider: m.provider, model: m.model, purpose, ok, ms, error: error?.slice(0, 300) ?? null });
}

/** Removes <think>…</think> blocks from a stream of text pieces, even when a tag is split across pieces. */
class ThinkStripper {
  private buf = "";
  private inThink = false;
  push(piece: string): string {
    this.buf += piece;
    let out = "";
    for (;;) {
      if (this.inThink) {
        const end = this.buf.indexOf("</think>");
        if (end < 0) {
          this.buf = this.buf.slice(-8);
          return out;
        }
        this.buf = this.buf.slice(end + 8);
        this.inThink = false;
      } else {
        const start = this.buf.indexOf("<think>");
        if (start < 0) {
          // Keep a short tail in case "<think>" is split across pieces.
          const keep = Math.min(6, this.buf.length);
          out += this.buf.slice(0, this.buf.length - keep);
          this.buf = this.buf.slice(this.buf.length - keep);
          return out;
        }
        out += this.buf.slice(0, start);
        this.buf = this.buf.slice(start + 7);
        this.inThink = true;
      }
    }
  }
  flush(): string {
    const rest = this.inThink ? "" : this.buf;
    this.buf = "";
    return rest;
  }
}

async function embed(m: Model, input: string): Promise<number[] | null> {
  const t = Date.now();
  try {
    const r = await fetch(`${m.base_url}/embeddings`, {
      method: "POST",
      headers: { authorization: `Bearer ${m.key}`, "content-type": "application/json" },
      body: JSON.stringify({ model: m.model, input: [input.slice(0, 2000)], input_type: "query", encoding_format: "float", ...(m.dimensions ? { dimensions: m.dimensions } : {}) }),
      signal: AbortSignal.timeout(8000),
    });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const j = await r.json();
    await logCall(m, "embed", true, Date.now() - t);
    return j.data?.[0]?.embedding ?? null;
  } catch (e) {
    await logCall(m, "embed", false, Date.now() - t, String(e));
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  // ---- who is asking
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: who } = await admin.auth.getUser(token);
  const uid = who?.user?.id;
  if (!uid) return json({ error: "Please log in again.", code: "auth" }, 401);

  // ---- what they sent
  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return json({ error: "Bad request" }, 400);
  }
  const text = typeof b.text === "string" ? b.text.trim().slice(0, 4000) : "";
  const image = typeof b.image === "string" && b.image.length > 100 ? b.image : null;
  if (image && (image.length > 2_800_000 || !/^[A-Za-z0-9+/=]+$/.test(image.slice(0, 200)))) return json({ error: "The photo is too large. Try again." }, 400);
  const imageType = image?.startsWith("iVBOR") ? "image/png" : "image/jpeg";
  const hint = b.hint === true;
  const explain = b.explain === true;
  const subjectId = Number.isInteger(b.subject_id) ? (b.subject_id as number) : null;
  const questionId = typeof b.question_id === "string" && UUID.test(b.question_id) ? b.question_id : null;
  let chatId = typeof b.chat_id === "string" && UUID.test(b.chat_id) ? b.chat_id : null;
  if (!text && !image && !questionId) return json({ error: "Type a question first." }, 400);

  if (chatId) {
    const { data: c } = await admin.from("ai_chats").select("id, user_id, deleted_at").eq("id", chatId).maybeSingle();
    if (!c || c.user_id !== uid || c.deleted_at) return json({ error: "This chat was not found." }, 404);
  }

  // ---- quota (atomic in Postgres)
  const { data: left, error: qe } = await admin.rpc("ai_take", { p_uid: uid });
  if (qe) return json({ error: "Something went wrong. Try again." }, 500);
  if (left === -1) return json({ error: "You have used all your AI prompts for today.", code: "quota" }, 429);
  if (left === -2) return json({ error: "That was fast! Wait a minute, then ask again.", code: "slow" }, 429);
  if (left === -3) return json({ error: "This account has been suspended. Contact support.", code: "banned" }, 403);

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const enc = new TextEncoder();
      const send = (o: unknown) => controller.enqueue(enc.encode(`data: ${JSON.stringify(o)}\n\n`));
      let newChat = false;
      try {
        const cfg = await config();

        // ---- the attached past question, if any
        let qBlock = "";
        let qSubject: number | null = null;
        if (questionId) {
          const { data: q } = await admin
            .from("questions")
            .select("body, options, answer, explanation, year, subject_id, exam_bodies(code), subjects(name), topics(name)")
            .eq("id", questionId)
            .maybeSingle();
          if (q) {
            qSubject = q.subject_id;
            const opts = Object.entries((q.options ?? {}) as Record<string, string>).map(([k, v]) => `${k}. ${v}`).join("\n");
            const exam = (q.exam_bodies as unknown as { code: string } | null)?.code ?? "";
            const subj = (q.subjects as unknown as { name: string } | null)?.name ?? "";
            qBlock = `Past question (${exam} ${q.year} ${subj}):\n${q.body}\n${opts}\nCorrect answer: ${q.answer}` + (q.explanation ? `\nOfficial explanation: ${q.explanation}` : "");
          }
        }

        // ---- chat row
        if (!chatId) {
          const title = (text || (questionId ? "Explain a past question" : "Photo question")).replace(/\s+/g, " ").slice(0, 60);
          const { data: c, error } = await admin.from("ai_chats").insert({ user_id: uid, title, subject_id: subjectId ?? qSubject }).select("id").single();
          if (error) throw new Error("chat: " + error.message);
          chatId = c.id;
          newChat = true;
        }
        send({ t: "start", chat_id: chatId });

        const userText = [qBlock, text || (image ? "Solve the question in this photo, step by step." : "Explain this question step by step.")].filter(Boolean).join("\n\n");
        const saveUser = () =>
          admin.from("ai_messages").insert({ chat_id: chatId, user_id: uid, role: "user", content: text || (questionId ? "Explain this question." : ""), has_image: !!image, question_id: questionId, hint });

        // ---- cached "explain this question"
        const cacheKey = questionId && explain && !text && !image ? `q:${questionId}:${hint ? 1 : 0}` : null;
        if (cacheKey) {
          const { data: hit } = await admin.from("ai_cache").select("answer, model, hits").eq("key", cacheKey).maybeSingle();
          if (hit) {
            for (let i = 0; i < hit.answer.length; i += 80) send({ t: "d", c: hit.answer.slice(i, i + 80) });
            await saveUser();
            const { data: m } = await admin.from("ai_messages").insert({ chat_id: chatId, user_id: uid, role: "assistant", content: hit.answer, model: hit.model, provider: "cache", ms: 0 }).select("id").single();
            await admin.from("ai_cache").update({ hits: (hit.hits ?? 0) + 1 }).eq("key", cacheKey);
            await admin.from("ai_chats").update({ updated_at: new Date().toISOString() }).eq("id", chatId);
            send({ t: "done", message_id: m?.id, left, model: hit.model });
            controller.close();
            return;
          }
        }

        // ---- related notes (RAG)
        let notes = "";
        const embedModel = cfg.models.find((m) => m.purpose === "embed");
        const query = [text, qBlock].filter(Boolean).join("\n");
        if (embedModel && query.length >= 8) {
          const v = await embed(embedModel, query);
          if (v) {
            const { data: chunks } = await admin.rpc("ai_match", { p_embedding: JSON.stringify(v), p_subject: subjectId ?? qSubject, p_count: 4 });
            const good = ((chunks ?? []) as { title: string; content: string; similarity: number }[]).filter((c) => c.similarity > 0.35);
            if (good.length) notes = good.map((c) => `### ${c.title}\n${c.content}`).join("\n\n");
          }
        }

        // ---- the conversation
        const subjectName = subjectId
          ? ((await admin.from("subjects").select("name").eq("id", subjectId).maybeSingle()).data?.name as string | undefined)
          : undefined;
        const extra = [
          subjectName ? `The student chose the subject: ${subjectName}.` : "",
          hint
            ? "HINT MODE IS ON: do not give the final answer. Give one hint or the first step only, then ask the student to try the next step. If they get it right, give the next hint."
            : "",
          notes ? `Material from SolutionTee's own lesson notes that may help (use it when relevant, do not mention it by name):\n\n${notes}` : "",
        ].filter(Boolean).join("\n\n");
        const { data: hist } = await admin
          .from("ai_messages")
          .select("role, content")
          .eq("chat_id", chatId)
          .order("created_at", { ascending: false })
          .limit(12);
        const messages: Msg[] = [
          { role: "system", content: [cfg.prompt, extra].filter(Boolean).join("\n\n") },
          ...((hist ?? []).reverse().filter((m) => m.content) as Msg[]),
          {
            role: "user",
            content: image
              ? [{ type: "text", text: userText }, { type: "image_url", image_url: { url: `data:${imageType};base64,${image}` } }]
              : userText,
          },
        ];

        // ---- ask the models in order until one answers
        // Timing rules: a model must start sending something within 20 s (35 s for photos) and start WRITING the answer
        // within 25 s (45 s for photos), even if it is busy thinking ("Thinking…" shows in the app meanwhile). Once it
        // writes, it may continue as long as something arrives at least every 30 s. The whole request stays inside the
        // server's time limit; when time runs short no new model is tried.
        const candidates = cfg.models.filter((m) => m.purpose === (image ? "vision" : "chat"));
        const deadline = Date.now() + 135_000;
        let answer = "";
        let used: Model | null = null;
        let started = 0;
        for (const m of candidates) {
          if (Date.now() > deadline - 20_000) break;
          const t = Date.now();
          const abort = new AbortController();
          let idle = setTimeout(() => abort.abort("no reply"), image ? 35_000 : 20_000);
          const keepAlive = () => {
            clearTimeout(idle);
            idle = setTimeout(() => abort.abort("stalled"), 30_000);
          };
          const hardStop = setTimeout(() => abort.abort("out of time"), Math.max(deadline - Date.now(), 5_000));
          const noAnswer = setTimeout(() => abort.abort("thinking too long, no answer yet"), image ? 45_000 : 25_000);
          let sentAny = false;
          let lastThink = 0;
          try {
            const r = await fetch(`${m.base_url}/chat/completions`, {
              method: "POST",
              headers: { authorization: `Bearer ${m.key}`, "content-type": "application/json", accept: "text/event-stream" },
              body: JSON.stringify({ ...(m.params ?? {}), model: m.model, messages, stream: true, temperature: Number(m.temperature), max_tokens: m.max_tokens }),
              signal: abort.signal,
            });
            if (!r.ok || !r.body) throw new Error(`HTTP ${r.status} ${(await r.text().catch(() => "")).slice(0, 160)}`);
            const reader = r.body.pipeThrough(new TextDecoderStream()).getReader();
            const strip = new ThinkStripper();
            let lineBuf = "";
            let leading = true;
            let finish: string | null = null;
            const emit = (s: string) => {
              if (leading) {
                s = s.replace(/^\s+/, "");
                if (!s) return;
                leading = false;
              }
              if (!sentAny) clearTimeout(noAnswer);
              sentAny = true;
              answer += s;
              send({ t: "d", c: s });
            };
            outer: for (;;) {
              const { value, done } = await reader.read();
              if (done) break;
              lineBuf += value;
              let nl: number;
              while ((nl = lineBuf.indexOf("\n")) >= 0) {
                const line = lineBuf.slice(0, nl).trim();
                lineBuf = lineBuf.slice(nl + 1);
                if (!line.startsWith("data:")) continue;
                const data = line.slice(5).trim();
                if (data === "[DONE]") break outer;
                try {
                  const j = JSON.parse(data);
                  const c = j.choices?.[0];
                  if (!c) continue;
                  keepAlive();
                  const piece = c.delta?.content;
                  if (typeof piece === "string" && piece) emit(strip.push(piece));
                  else if (!sentAny && (c.delta?.reasoning_content || c.delta?.reasoning) && Date.now() - lastThink > 2000) {
                    lastThink = Date.now();
                    send({ t: "think" });
                  }
                  if (c.finish_reason) finish = c.finish_reason;
                } catch {
                  // ignore keep-alive or broken lines
                }
              }
              if (finish && lineBuf.trim() === "") {
                // Some providers keep the connection open after the last piece: stop reading once a model says it is done.
                reader.cancel().catch(() => {});
                break;
              }
            }
            emit(strip.flush());
            clearTimeout(idle);
            clearTimeout(hardStop);
            clearTimeout(noAnswer);
            if (!answer.trim()) throw new Error(`empty answer${finish ? ` (${finish})` : ""}`);
            used = m;
            started = t;
            await logCall(m, image ? "vision" : "chat", true, Date.now() - t);
            break;
          } catch (e) {
            clearTimeout(idle);
            clearTimeout(hardStop);
            clearTimeout(noAnswer);
            await logCall(m, image ? "vision" : "chat", false, Date.now() - t, String(e));
            if (sentAny) {
              // Part of an answer was already shown: do not mix in another model's answer.
              used = m;
              started = t;
              answer += "\n\n*(The answer was cut off. Ask again to continue.)*";
              send({ t: "d", c: "\n\n*(The answer was cut off. Ask again to continue.)*" });
              break;
            }
          }
        }

        if (!used) {
          await admin.rpc("ai_refund", { p_uid: uid });
          if (newChat) await admin.from("ai_chats").delete().eq("id", chatId);
          send({ t: "error", code: "busy", message: "SolutionTee AI is very busy right now. Try again in a moment. This did not use a prompt." });
          controller.close();
          return;
        }

        await saveUser();
        const { data: saved } = await admin
          .from("ai_messages")
          .insert({ chat_id: chatId, user_id: uid, role: "assistant", content: answer, model: used.model, provider: used.provider, ms: Date.now() - started, hint })
          .select("id")
          .single();
        await admin.from("ai_chats").update({ updated_at: new Date().toISOString() }).eq("id", chatId);
        if (cacheKey && !answer.includes("cut off")) await admin.from("ai_cache").upsert({ key: cacheKey, answer, model: used.model });
        send({ t: "done", message_id: saved?.id, left, model: used.model });
      } catch (e) {
        console.error("ai-chat", e);
        await admin.rpc("ai_refund", { p_uid: uid });
        send({ t: "error", code: "busy", message: "Something went wrong. Try again. This did not use a prompt." });
      }
      controller.close();
    },
  });

  return new Response(stream, {
    headers: { ...cors, "content-type": "text/event-stream; charset=utf-8", "cache-control": "no-cache", "x-accel-buffering": "no" },
  });
});
