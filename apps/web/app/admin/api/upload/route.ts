import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { ALLOWED_TYPES, MAX_BYTES, presignPut } from "@/lib/r2";

const Body = z.object({
  kind: z.enum(["question", "news"]),
  contentType: z.string(),
  size: z.number().int().positive(),
});

/** Gives a staff member a 10-minute link to upload one image straight to R2. */
export async function POST(req: Request) {
  if (!hasR2()) return NextResponse.json({ error: "Image storage (R2) is not set up yet." }, { status: 503 });
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Bad request" }, { status: 400 });
  const { kind, contentType, size } = parsed.data;
  const ext = ALLOWED_TYPES[contentType];
  if (!ext) return NextResponse.json({ error: "Use a WebP, PNG, JPG or SVG image." }, { status: 415 });
  if (size > MAX_BYTES) return NextResponse.json({ error: "The image is over 2 MB. Make it smaller (WebP works best)." }, { status: 413 });

  // The database decides: staff with 2-step login and an editing role.
  const supabase = await createClient();
  const { data: allowed } = await supabase.rpc("can_upload_images");
  if (!allowed) return NextResponse.json({ error: "Not allowed. Log in again with 2-step." }, { status: 403 });

  const d = new Date();
  const key = `${kind === "question" ? "q" : "public/news"}/${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, "0")}/${crypto.randomUUID()}.${ext}`;
  return NextResponse.json({ key, url: await presignPut(key, contentType) });
}
