import { NextResponse } from "next/server";
import { hasR2 } from "@/lib/env";
import { apkBuildAllowed, apkNameOk, verifyGithubToken } from "@/lib/github-oidc";
import { objectSize, presignPut, writeJson } from "@/lib/r2";
import type { ApkInfo } from "@/app/download/apk/route";

const APK = "application/vnd.android.package-archive";
const read = (k: string) => (process.env[k] ?? "").trim();

/**
 * POST /api/ci/apk — used only by the GitHub workflow `android-apk.yml` (D-065), so /download always has the newest app.
 * The caller proves it is that workflow with GitHub's signed run token (no stored password). Steps:
 *   {step:"start"}   → the app signing key and Firebase app file (kept as Vercel secrets) for this build
 *   {step:"upload", name} → a 10-minute upload link for apk/<name> in the private bucket
 *   {step:"publish", name, version, built_at, build} → checks the file arrived, then points /download at it
 */
export async function POST(req: Request) {
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const claims = token ? await verifyGithubToken(token).catch(() => null) : null;
  if (!claims || !apkBuildAllowed(claims)) return NextResponse.json({ error: "Not allowed" }, { status: 403 });
  if (!hasR2()) return NextResponse.json({ error: "Storage is not set up" }, { status: 503 });

  const body = (await req.json().catch(() => ({}))) as { step?: string; name?: unknown; version?: unknown; built_at?: unknown; build?: unknown };
  const branch = claims.ref.replace(/^refs\/heads\//, "");

  if (body.step === "start") {
    const keystore = read("ANDROID_DIRECT_KEYSTORE_B64"), password = read("ANDROID_DIRECT_KEYSTORE_PASSWORD");
    if (!keystore || !password) return NextResponse.json({ error: "Signing key is not set up" }, { status: 503 });
    return NextResponse.json(
      { keystore, password, alias: read("ANDROID_DIRECT_KEY_ALIAS") || "solutiontee", google_services: read("GOOGLE_SERVICES_JSON_B64") },
      { headers: { "Cache-Control": "no-store" } },
    );
  }

  if (!apkNameOk(body.name)) return NextResponse.json({ error: "Bad file name" }, { status: 400 });
  const key = `apk/${body.name}`;

  if (body.step === "upload") return NextResponse.json({ url: await presignPut(key, APK) }, { headers: { "Cache-Control": "no-store" } });

  if (body.step === "publish") {
    const size = await objectSize(key);
    if (!size || size < 1024 * 1024) return NextResponse.json({ error: "The APK did not arrive" }, { status: 409 });
    const version = typeof body.version === "string" && /^[0-9A-Za-z.+-]{1,60}$/.test(body.version) ? body.version : body.name.slice(16, -4);
    const builtAt = typeof body.built_at === "string" && !Number.isNaN(Date.parse(body.built_at)) ? new Date(body.built_at).toISOString() : new Date().toISOString();
    // The Android versionCode (minutes since 1970): the app compares it with its own to know an update exists (D-080).
    const build = typeof body.build === "number" && Number.isInteger(body.build) && body.build > 0 ? body.build : undefined;
    const info: ApkInfo & { commit: string } = { key, version, size, built_at: builtAt, branch, commit: claims.sha, build };
    await writeJson("apk/latest.json", info);
    return NextResponse.json(info);
  }
  return NextResponse.json({ error: "Unknown step" }, { status: 400 });
}
