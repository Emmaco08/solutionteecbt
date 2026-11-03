import { NextResponse } from "next/server";
import { hasR2 } from "@/lib/env";
import { presignDownload, readJson } from "@/lib/r2";

export type ApkInfo = { key: string; version: string; size: number; built_at: string; branch?: string };
/** "main" is the build from the main branch (for the team); "test" is the newest build from any other branch (D-060). */
export const apkInfoKey = (channel: string | null | undefined) => (channel === "test" ? "apk/test.json" : "apk/latest.json");

/** GET /download/apk → a 10-minute link to the latest Android test app in the private bucket (D-059). */
export async function GET(req: Request) {
  if (!hasR2()) return new NextResponse("Not available", { status: 503 });
  const info = await readJson<ApkInfo>(apkInfoKey(new URL(req.url).searchParams.get("channel")));
  if (!info) return new NextResponse("No app file has been uploaded yet.", { status: 404 });
  const url = await presignDownload(info.key, `SolutionTee-CBT-${info.version}.apk`, "application/vnd.android.package-archive");
  const res = NextResponse.redirect(url);
  res.headers.set("Cache-Control", "no-store");
  return res;
}
