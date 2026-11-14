import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { env, hasR2 } from "@/lib/env";
import { presignGet } from "@/lib/r2";

/**
 * GET /classes/img?k=public/classes/… → a short signed link to a class flyer or teacher photo (D-163).
 * The bucket stays private: a picture is only signed when a published class programme uses it.
 */
export async function GET(req: Request) {
  const key = new URL(req.url).searchParams.get("k") ?? "";
  if (!hasR2() || !/^public\/classes\/[A-Za-z0-9/_.-]+$/.test(key)) return new NextResponse("Not found", { status: 404 });
  const sb = createClient(env.supabaseUrl, env.supabasePublishableKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: ok } = await sb.rpc("can_view_class_image", { p_key: key });
  if (ok !== true) return new NextResponse("Not found", { status: 404 });
  const res = NextResponse.redirect(await presignGet(key, 3600), 302);
  // Browsers and the CDN may reuse the redirect for a while (the signed link itself lasts an hour).
  res.headers.set("Cache-Control", "public, max-age=600, s-maxage=600");
  return res;
}
