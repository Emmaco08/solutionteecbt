// Puts the Android test app on https://admin.solutiontee.com/download (D-059, D-060).
// Uploads the APK to the private R2 bucket under apk/ and points apk/latest.json (or apk/test.json) at it.
// Usage (from apps/web): node scripts/upload-apk.mjs [path-to-apk] [--channel main|test] [--branch name]
// Keys come from .env.local on the laptop, or from environment variables on GitHub Actions. Never printed.
import { existsSync, readFileSync, statSync } from "node:fs";
import { AwsClient } from "aws4fetch";

const envFile = new URL("../.env.local", import.meta.url);
const env = {
  ...process.env,
  ...(existsSync(envFile)
    ? Object.fromEntries(
        readFileSync(envFile, "utf8")
          .split(/\r?\n/)
          .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
          .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^["']|["']$/g, "")]),
      )
    : {}),
};
const args = process.argv.slice(2);
const flag = (n) => (args.includes(n) ? args[args.indexOf(n) + 1] : undefined);
const channel = flag("--channel") === "test" ? "test" : "main";
const branch = flag("--branch");
const positional = args.filter((a, i) => !a.startsWith("--") && !(i > 0 && args[i - 1].startsWith("--")));
const file = positional[0] ?? new URL("../../mobile/build/app/outputs/flutter-apk/app-release.apk", import.meta.url);
const pubspec = readFileSync(new URL("../../mobile/pubspec.yaml", import.meta.url), "utf8");
const name = pubspec.match(/^version:\s*([0-9.]+)/m)?.[1] ?? "0.0.0";
const built = statSync(file).mtime;
const stamp = built.toISOString().slice(0, 16).replace(/[-:T]/g, "");
const version = `${name}-${stamp}`;
const key = `apk/${channel === "test" ? "test/" : ""}solutiontee-cbt-${version}.apk`;

const aws = new AwsClient({ accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY, service: "s3", region: "auto" });
const base = `${env.R2_ENDPOINT.replace(/\/+$/, "")}/${env.R2_BUCKET}`;
const body = readFileSync(file);

const put = async (k, data, type) => {
  const r = await aws.fetch(`${base}/${k}`, { method: "PUT", body: data, headers: { "content-type": type } });
  if (!r.ok) throw new Error(`Upload of ${k} failed: HTTP ${r.status} ${(await r.text()).slice(0, 200)}`);
};
console.log(`Uploading ${(body.length / 1024 / 1024).toFixed(1)} MB as ${key} …`);
await put(key, body, "application/vnd.android.package-archive");
const info = { key, version, size: body.length, built_at: built.toISOString(), ...(branch ? { branch } : {}) };
await put(channel === "test" ? "apk/test.json" : "apk/latest.json", JSON.stringify(info), "application/json");
console.log("Done:", JSON.stringify(info));
