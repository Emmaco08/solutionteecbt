// Puts the Android test app on https://admin.solutiontee.com/download (D-059).
// Uploads the APK to the private R2 bucket under apk/ and points apk/latest.json at it.
// Usage (from apps/web): node scripts/upload-apk.mjs [path-to-apk]
// Default path: ../mobile/build/app/outputs/flutter-apk/app-release.apk. Reads keys from .env.local; never prints them.
import { readFileSync, statSync } from "node:fs";
import { AwsClient } from "aws4fetch";

const env = Object.fromEntries(
  readFileSync(new URL("../.env.local", import.meta.url), "utf8")
    .split(/\r?\n/)
    .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^["']|["']$/g, "")]),
);
const file = process.argv[2] ?? new URL("../../mobile/build/app/outputs/flutter-apk/app-release.apk", import.meta.url);
const pubspec = readFileSync(new URL("../../mobile/pubspec.yaml", import.meta.url), "utf8");
const name = pubspec.match(/^version:\s*([0-9.]+)/m)?.[1] ?? "0.0.0";
const built = statSync(file).mtime;
const stamp = built.toISOString().slice(0, 16).replace(/[-:T]/g, "");
const version = `${name}-${stamp}`;
const key = `apk/solutiontee-cbt-${version}.apk`;

const aws = new AwsClient({ accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY, service: "s3", region: "auto" });
const base = `${env.R2_ENDPOINT.replace(/\/+$/, "")}/${env.R2_BUCKET}`;
const body = readFileSync(file);

const put = async (k, data, type) => {
  const r = await aws.fetch(`${base}/${k}`, { method: "PUT", body: data, headers: { "content-type": type } });
  if (!r.ok) throw new Error(`Upload of ${k} failed: HTTP ${r.status} ${(await r.text()).slice(0, 200)}`);
};
console.log(`Uploading ${(body.length / 1024 / 1024).toFixed(1)} MB as ${key} …`);
await put(key, body, "application/vnd.android.package-archive");
const info = { key, version, size: body.length, built_at: built.toISOString() };
await put("apk/latest.json", JSON.stringify(info), "application/json");
console.log("Done:", JSON.stringify(info));
