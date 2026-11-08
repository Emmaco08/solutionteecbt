// Nightly mover: old history leaves Supabase for Neon (docs/plans/backend-neon.md, D-108).
// POST /functions/v1/archive-mover  {"kinds"?: string[], "max_batches"?: number}
//   Called by pg_cron at 02:15 Lagos time (header x-cron-token, checked in Vault like the push job).
// For each kind: archive_take (a batch of old rows) -> insert into the right Neon database (rows already there are
// skipped) -> count them in Neon -> archive_drop (delete exactly those rows on Supabase). Nothing is deleted before
// Neon has every row. Safe to run again at any time.
// Secrets (Edge Function secrets, set in the Supabase dashboard): NEON_ARCHIVE_URL, NEON_HISTORY_URL, NEON_AI_URL,
// NEON_ANALYTICS_URL (Neon pooled connection strings).
import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { neon } from "npm:@neondatabase/serverless@1.0.2";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });

// Neon connection strings: Edge Function secret if set, otherwise Supabase Vault (via neon_url, service role only).
const urls = new Map<string, string>();
async function neonUrl(name: string): Promise<string | null> {
  const env = Deno.env.get(name);
  if (env) return env;
  if (urls.has(name)) return urls.get(name)!;
  const { data } = await admin.rpc("neon_url", { p_name: name });
  if (typeof data === "string" && data) urls.set(name, data);
  return typeof data === "string" && data ? data : null;
}

type Kind = {
  db: string; // secret name
  table: string;
  cols: string[]; // columns written to Neon (Neon adds archived_at)
  // How Neon counts the rows of this batch (keys from archive_take).
  count: string;
  conflict: string;
};

const KINDS: Record<string, Kind> = {
  audit: {
    db: "NEON_ARCHIVE_URL", table: "audit_log", cols: ["id", "at", "actor", "action", "table_name", "row_id", "before", "after"],
    count: "select count(*)::int n from audit_log where id = any(select (x)::bigint from jsonb_array_elements_text($1::jsonb) x)", conflict: "(id)",
  },
  payment_events: {
    db: "NEON_ARCHIVE_URL", table: "payment_events", cols: ["id", "payment_id", "provider", "kind", "event_key", "ok", "note", "data", "created_at"],
    count: "select count(*)::int n from payment_events where id = any(select (x)::bigint from jsonb_array_elements_text($1::jsonb) x)", conflict: "(id)",
  },
  ai_calls: {
    db: "NEON_ARCHIVE_URL", table: "ai_calls", cols: ["id", "at", "provider", "model", "purpose", "ok", "ms", "error"],
    count: "select count(*)::int n from ai_calls where id = any(select (x)::bigint from jsonb_array_elements_text($1::jsonb) x)", conflict: "(id)",
  },
  ai_messages: {
    db: "NEON_AI_URL", table: "ai_messages",
    cols: ["id", "chat_id", "user_id", "role", "content", "has_image", "question_id", "hint", "model", "provider", "ms", "flagged_at", "flag_reason", "created_at", "card", "reaction"],
    count: "select count(*)::int n from ai_messages where id = any(select (x)::uuid from jsonb_array_elements_text($1::jsonb) x)", conflict: "(id)",
  },
  attempt_answers: {
    db: "NEON_HISTORY_URL", table: "attempt_answers",
    cols: ["attempt_id", "question_id", "choice", "is_correct", "flagged", "time_ms", "user_id", "submitted_at"],
    // Rows for these tests (compared with the number of rows taken).
    count: "select count(*)::int n from attempt_answers where attempt_id = any(select (x)::uuid from jsonb_array_elements_text($1::jsonb) x)",
    conflict: "(attempt_id, question_id)",
  },
  challenge_answers: {
    db: "NEON_HISTORY_URL", table: "challenge_answers", cols: ["entry_id", "question_id", "choice", "correct", "time_ms", "answered_at", "user_id"],
    count: "select count(*)::int n from challenge_answers where entry_id = any(select (x)::uuid from jsonb_array_elements_text($1::jsonb) x)",
    conflict: "(entry_id, question_id)",
  },
  ad_rewards: {
    db: "NEON_ANALYTICS_URL", table: "ad_rewards",
    cols: ["id", "user_id", "kind", "ref", "status", "transaction_id", "ad_unit", "via", "created_at", "granted_at", "expires_at"],
    count: "select count(*)::int n from ad_rewards where id = any(select (x)::uuid from jsonb_array_elements_text($1::jsonb) x)", conflict: "(id)",
  },
  ad_daily: {
    db: "NEON_ANALYTICS_URL", table: "ad_daily", cols: ["day", "format", "placement", "impressions", "clicks"],
    count: "select count(*)::int n from ad_daily d join jsonb_to_recordset($1::jsonb) as k(day date, format text, placement text) on d.day = k.day and d.format = k.format and d.placement = k.placement",
    conflict: "(day, format, placement)",
  },
};

// Rows that keep exactly their key count (one row per key); answer kinds compare row counts instead.
const PER_ROW = new Set(["audit", "payment_events", "ai_calls", "ai_messages", "ad_rewards", "ad_daily"]);

async function moveOnce(name: string, k: Kind, batch: number): Promise<{ moved: number; done: boolean }> {
  const url = await neonUrl(k.db);
  if (!url) throw new Error(`${k.db} is not set`);
  const { data, error } = await admin.rpc("archive_take", { p_kind: name, p_limit: batch });
  if (error) throw new Error(`take ${name}: ${error.message}`);
  const rows = (data?.rows ?? []) as Record<string, unknown>[];
  const keys = (data?.keys ?? []) as unknown[];
  if (!keys.length) return { moved: 0, done: true };

  const sql = neon(url);
  const cols = k.cols.join(", ");
  // One statement: the batch arrives as JSON and is unpacked in Neon (rows already there are skipped).
  await sql.query(
    `insert into ${k.table} (${cols}) select ${cols} from jsonb_populate_recordset(null::${k.table}, $1::jsonb) on conflict ${k.conflict} do nothing`,
    [JSON.stringify(rows)],
  );
  const res = await sql.query(k.count, [JSON.stringify(keys)]) as { n: number }[];
  const inNeon = res[0]?.n ?? 0;
  const want = PER_ROW.has(name) ? keys.length : rows.length;
  if (inNeon < want) throw new Error(`${name}: Neon has ${inNeon} of ${want}; nothing deleted`);

  const { data: dropped, error: e2 } = await admin.rpc("archive_drop", { p_kind: name, p_keys: keys, p_note: `${rows.length} rows to ${k.db}` });
  if (e2) throw new Error(`drop ${name}: ${e2.message}`);
  return { moved: Number(dropped ?? 0), done: keys.length < 1 };
}

Deno.serve(async (req) => {
  // Setup check (GET ?health=1): which Neon secrets this function can see. Names and yes/no only, never the values.
  if (req.method === "GET" && new URL(req.url).searchParams.get("health") === "1") {
    const want = ["NEON_ARCHIVE_URL", "NEON_HISTORY_URL", "NEON_AI_URL", "NEON_ANALYTICS_URL"];
    const seen = Object.keys(Deno.env.toObject()).filter((k) => k.toUpperCase().includes("NEON"));
    const vault: Record<string, boolean> = {};
    for (const k of want) vault[k] = !!(await neonUrl(k));
    return json({ set: Object.fromEntries(want.map((k) => [k, !!Deno.env.get(k)])), available: vault, neon_like_names: seen });
  }
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const cron = req.headers.get("x-cron-token");
  const ok = cron ? (await admin.rpc("push_cron_ok", { p_token: cron })).data === true : false;
  if (!ok) return json({ error: "forbidden" }, 403);

  const body = await req.json().catch(() => ({})) as { kinds?: string[]; max_batches?: number };
  const { data: s } = await admin.from("app_settings").select("value").eq("key", "archive").maybeSingle();
  const cfg = (s?.value ?? {}) as { on?: boolean; batch?: number };
  if (cfg.on === false) return json({ skipped: "archive is off" });
  const batch = Math.min(Math.max(Number(cfg.batch ?? 2000), 100), 5000);
  const maxBatches = Math.min(Math.max(Number(body.max_batches ?? 40), 1), 400);
  const kinds = (body.kinds?.length ? body.kinds : Object.keys(KINDS)).filter((x) => KINDS[x]);

  const report: Record<string, unknown> = {};
  const started = Date.now();
  for (const name of kinds) {
    let total = 0;
    try {
      for (let i = 0; i < maxBatches && Date.now() - started < 120_000; i++) {
        const r = await moveOnce(name, KINDS[name], batch);
        total += r.moved;
        if (r.done || r.moved === 0) break;
      }
      report[name] = { moved: total };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      report[name] = { moved: total, error: msg };
      await admin.from("archive_runs").insert({ kind: name, moved: 0, ok: false, note: msg.slice(0, 300) });
    }
  }
  return json({ ok: true, report, ms: Date.now() - started });
});
