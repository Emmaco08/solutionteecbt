import { NextResponse } from "next/server";
import { hasR2 } from "@/lib/env";
import { presignDownload, readJson } from "@/lib/r2";
import { apkInfoKey, type ApkInfo } from "../apk/route";

/** GET /download/windows → a 10-minute link to the newest SolutionTee CBT installer for Windows (D-166). Public, like the
 *  students' Android app. */
export async function GET() {
  if (!hasR2()) return new NextResponse("Not available", { status: 503 });
  const info = await readJson<ApkInfo>(apkInfoKey("windows"));
  if (!info) return new NextResponse("The Windows app is not ready yet.", { status: 404 });
  const url = await presignDownload(info.key, `SolutionTee-CBT-Setup-${info.version}.exe`, "application/vnd.microsoft.portable-executable");
  const res = NextResponse.redirect(url);
  res.headers.set("Cache-Control", "no-store");
  return res;
}
