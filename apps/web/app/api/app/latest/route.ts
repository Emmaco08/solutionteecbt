import { NextResponse } from "next/server";
import { env, hasR2 } from "@/lib/env";
import { readJson } from "@/lib/r2";
import { apkInfoKey, type ApkInfo } from "@/app/download/apk/route";

/**
 * GET /api/app/latest → the newest direct Android app (D-080), or ?channel=windows for the Windows installer (D-166): { version, build, size, built_at, url }.
 * The app compares `build` with its own versionCode, then downloads `url` (a redirect to a 10-minute link).
 */
export async function GET(req: Request) {
  if (!hasR2()) return NextResponse.json({ error: "Not available" }, { status: 503 });
  const channel = new URL(req.url).searchParams.get("channel");
  const info = await readJson<ApkInfo>(apkInfoKey(channel));
  if (!info) return NextResponse.json({ error: "No app yet" }, { status: 404 });
  // Downloads come from the public website (D-125); old apps that still ask admin.solutiontee.com get the same link.
  const reqUrl = new URL(req.url);
  const origin = /(^|\.)solutiontee\.com$/.test(reqUrl.hostname) ? env.publicUrl.replace(/\/+$/, "") : reqUrl.origin;
  const res = NextResponse.json({
    version: info.version, build: info.build ?? null, size: info.size, built_at: info.built_at,
    url: channel === "windows" ? `${origin}/download/windows` : `${origin}/download/apk${channel === "test" ? "?channel=test" : ""}`,
  });
  res.headers.set("Cache-Control", "no-store");
  return res;
}
