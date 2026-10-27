import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { presignGet } from "@/lib/r2";

/** Admin preview of a stored image: checks access in the database, then redirects to a short-lived R2 link. */
export async function GET(req: NextRequest) {
  const key = req.nextUrl.searchParams.get("key") ?? "";
  if (!hasR2() || !/^[a-z0-9][a-z0-9/_.-]{2,200}$/i.test(key)) return new NextResponse(null, { status: 404 });
  const supabase = await createClient();
  const { data: ok } = await supabase.rpc("can_view_question_image", { p_key: key });
  if (!ok) return new NextResponse(null, { status: 403 });
  const res = NextResponse.redirect(await presignGet(key));
  res.headers.set("Cache-Control", "private, max-age=60");
  return res;
}
