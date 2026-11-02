// Live check of the ai-chat Edge Function with a temporary test student (created, used, then deleted).
// Usage (from apps/web): node scripts/ai-smoke.mjs [--image]
// Reads keys from .env.local; never prints them.
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

const env = Object.fromEntries(
  readFileSync(new URL("../.env.local", import.meta.url), "utf8")
    .split(/\r?\n/)
    .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^["']|["']$/g, "")]),
);
const url = env.NEXT_PUBLIC_SUPABASE_URL;
const svc = createClient(url, env.SUPABASE_SECRET_KEY, { auth: { persistSession: false } });
const email = `ai-smoke-${Date.now()}@test.solutiontee.com`;
const password = crypto.randomUUID() + "Aa1";

const { data: u, error: ce } = await svc.auth.admin.createUser({ email, password, email_confirm: true });
if (ce) throw ce;
try {
  const pub = createClient(url, env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false } });
  const { data: s, error: se } = await pub.auth.signInWithPassword({ email, password });
  if (se) throw se;
  const token = s.session.access_token;

  const { data: quota } = await createClient(url, env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, { global: { headers: { Authorization: `Bearer ${token}` } } }).rpc("ai_quota");
  console.log("quota before:", JSON.stringify(quota));

  async function ask(body, label) {
    const t = Date.now();
    const r = await fetch(`${url}/functions/v1/ai-chat`, {
      method: "POST",
      headers: { authorization: `Bearer ${token}`, apikey: env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    console.log(`\n== ${label}: HTTP ${r.status} ${r.headers.get("content-type")}`);
    if (!r.ok || !r.body) return console.log(await r.text());
    const dec = new TextDecoder();
    let buf = "", answer = "", first = 0;
    for await (const chunk of r.body) {
      buf += dec.decode(chunk, { stream: true });
      let i;
      while ((i = buf.indexOf("\n\n")) >= 0) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 2);
        if (!line.startsWith("data:")) continue;
        const e = JSON.parse(line.slice(5));
        if (e.t === "d") { if (!first) first = Date.now() - t; answer += e.c; }
        else console.log("event:", JSON.stringify(e));
      }
    }
    console.log(`first words after ${first} ms, total ${Date.now() - t} ms, ${answer.length} chars`);
    console.log("answer start:", answer.slice(0, 400).replace(/\n/g, " / "));
    console.log("has <think>:", answer.includes("<think>"));
  }

  await ask({ text: "Solve 2x^2 - 7x + 3 = 0 for x.", subject_id: 2 }, "text question");
  if (process.argv.includes("--image")) {
    const img = readFileSync(new URL("./ai-smoke.jpg", import.meta.url)).toString("base64");
    await ask({ text: "", image: img }, "photo question");
  }
  const { data: q2 } = await createClient(url, env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, { global: { headers: { Authorization: `Bearer ${token}` } } }).rpc("ai_quota");
  console.log("\nquota after:", JSON.stringify(q2));
} finally {
  await svc.auth.admin.deleteUser(u.user.id);
  console.log("temporary student deleted");
}
