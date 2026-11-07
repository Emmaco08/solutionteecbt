import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { ALLOWED_TYPES, MAX_BYTES, presignPut } from "@/lib/r2";

const Body = z.object({
  kind: z.enum(["question", "news", "video", "pdf", "cover", "note_image", "receipt", "challenge", "ad_image", "ad_video"]),
  contentType: z.string(),
  size: z.number().int().positive(),
});

const MB = 1024 * 1024;
/** What each kind of upload accepts, its size limit and where it lives in the private bucket (D-045, D-053). */
const KINDS = {
  question: { types: ALLOWED_TYPES, max: MAX_BYTES, prefix: "q", what: "Use a WebP, PNG, JPG or SVG image.", big: "The image is over 2 MB. Make it smaller (WebP works best)." },
  news: { types: ALLOWED_TYPES, max: MAX_BYTES, prefix: "public/news", what: "Use a WebP, PNG, JPG or SVG image.", big: "The image is over 2 MB. Make it smaller (WebP works best)." },
  note_image: { types: ALLOWED_TYPES, max: MAX_BYTES, prefix: "n", what: "Use a WebP, PNG, JPG or SVG image.", big: "The image is over 2 MB. Make it smaller (WebP works best)." },
  challenge: { types: { "image/webp": "webp", "image/png": "png", "image/jpeg": "jpg" } as Record<string, string>, max: MAX_BYTES, prefix: "public/challenges", what: "Use a WebP, PNG or JPG picture.", big: "The picture is over 2 MB. Make it smaller (WebP works best)." },
  receipt: { types: ALLOWED_TYPES, max: MAX_BYTES, prefix: "public/winners", what: "Use a WebP, PNG or JPG image of the receipt.", big: "The image is over 2 MB. Make it smaller (WebP works best)." },
  cover: { types: ALLOWED_TYPES, max: MAX_BYTES, prefix: "s", what: "Use a WebP, PNG, JPG or SVG image.", big: "The image is over 2 MB. Make it smaller (WebP works best)." },
  ad_image: { types: { "image/webp": "webp", "image/png": "png", "image/jpeg": "jpg", "image/gif": "gif" } as Record<string, string>, max: MAX_BYTES, prefix: "public/ads", what: "Use a WebP, PNG, JPG or GIF picture.", big: "The picture is over 2 MB. Make it smaller (WebP works best)." },
  ad_video: { types: { "video/mp4": "mp4" } as Record<string, string>, max: 60 * MB, prefix: "public/ads/v", what: "Use an MP4 video (H.264).", big: "The ad video is over 60 MB. Keep brand videos short (15–30 s at 720p is about 5 MB)." },
  video: { types: { "video/mp4": "mp4" } as Record<string, string>, max: 400 * MB, prefix: "v", what: "Use an MP4 video (H.264).", big: "The video is over 400 MB. Export it smaller (360p about 60 MB per 10 minutes)." },
  pdf: { types: { "application/pdf": "pdf" } as Record<string, string>, max: 40 * MB, prefix: "d", what: "Use a PDF file.", big: "The PDF is over 40 MB. Compress it first." },
} as const;

/** Gives a staff member a 10-minute link to upload one file straight to R2. */
export async function POST(req: Request) {
  if (!hasR2()) return NextResponse.json({ error: "File storage (R2) is not set up yet." }, { status: 503 });
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Bad request" }, { status: 400 });
  const { kind, contentType, size } = parsed.data;
  const rule = KINDS[kind];
  const ext = (rule.types as Record<string, string>)[contentType];
  if (!ext) return NextResponse.json({ error: rule.what }, { status: 415 });
  if (size > rule.max) return NextResponse.json({ error: rule.big }, { status: 413 });

  // The database decides: staff with 2-step login and an editing role.
  const supabase = await createClient();
  const { data: allowed } = await supabase.rpc("can_upload_images");
  if (!allowed) return NextResponse.json({ error: "Not allowed. Log in again with 2-step." }, { status: 403 });

  const d = new Date();
  const key = `${rule.prefix}/${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, "0")}/${crypto.randomUUID()}.${ext}`;
  return NextResponse.json({ key, url: await presignPut(key, contentType) });
}
