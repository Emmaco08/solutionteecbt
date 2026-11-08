import { NextResponse } from "next/server";
import { hasR2 } from "@/lib/env";
import { presignDownload, readJson } from "@/lib/r2";
import type { ApkInfo } from "../apk/route";
import { isStaffRequest } from "@/lib/auth";

/** GET /download/aab → a 10-minute link to the newest Google Play Console bundle (.aab) in the private bucket (D-118). */
export async function GET(req: Request) {
  if (!hasR2()) return new NextResponse("Not available", { status: 503 });
  if (!(await isStaffRequest())) return NextResponse.redirect(new URL("/admin/login?next=/download", req.url)); // staff only (D-125)
  const info = await readJson<ApkInfo>("apk/aab.json");
  if (!info) return new NextResponse("The Google Play file has not been built yet.", { status: 404 });
  const url = await presignDownload(info.key, `SolutionTee-CBT-${info.version}.aab`, "application/octet-stream");
  const res = NextResponse.redirect(url);
  res.headers.set("Cache-Control", "no-store");
  return res;
}
