// Read a student's own history that has moved to Neon (docs/plans/backend-neon.md, D-108).
// POST /functions/v1/archive-read   Authorization: Bearer <access token>
//   {"kind":"chat","chat_id":"…"}       → {"messages":[…]}  older AI tutor messages of the student's own chat
//   {"kind":"attempt","attempt_id":"…"} → {"answers":[…]}   question-by-question answers of an older test
// Only the signed-in student's own rows are returned (checked by user_id in Neon and ownership on Supabase).
import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { neon } from "npm:@neondatabase/serverless@1.0.2";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });
const UUID = /^[0-9a-f-]{36}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: who } = await admin.auth.getUser(token);
  const uid = who.user?.id;
  if (!uid) return json({ error: "Please log in again." }, 401);
  const body = await req.json().catch(() => ({})) as { kind?: string; chat_id?: string; attempt_id?: string };

  try {
    if (body.kind === "chat" && UUID.test(body.chat_id ?? "")) {
      const url = Deno.env.get("NEON_AI_URL");
      if (!url) return json({ messages: [] });
      const rows = await neon(url).query(
        `select id, role, content, has_image, flagged_at, card, reaction, created_at
           from ai_messages where chat_id = $1 and user_id = $2 order by created_at limit 500`,
        [body.chat_id, uid],
      );
      return json({ messages: rows });
    }
    if (body.kind === "attempt" && UUID.test(body.attempt_id ?? "")) {
      const url = Deno.env.get("NEON_HISTORY_URL");
      if (!url) return json({ answers: [] });
      const rows = await neon(url).query(
        `select question_id, choice, is_correct, flagged, time_ms from attempt_answers where attempt_id = $1 and user_id = $2`,
        [body.attempt_id, uid],
      );
      return json({ answers: rows });
    }
    return json({ error: "Bad request" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "Could not load this right now. Try again." }, 503);
  }
});
