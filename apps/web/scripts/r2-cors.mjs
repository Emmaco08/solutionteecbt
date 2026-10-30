// Shows or sets the CORS rules of the private R2 bucket, so the admin (laptop and Vercel) can upload straight to R2.
// Usage (from apps/web):  node scripts/r2-cors.mjs           → show current rules
//                         node scripts/r2-cors.mjs --apply   → set the rules below
// Reads keys from .env.local; never prints them.
import { readFileSync } from "node:fs";
import { AwsClient } from "aws4fetch";

const env = Object.fromEntries(
  readFileSync(new URL("../.env.local", import.meta.url), "utf8")
    .split(/\r?\n/)
    .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^["']|["']$/g, "")]),
);

const ORIGINS = [
  "http://localhost:3000",
  "https://solutiontee-cbt.vercel.app",
  "https://solutiontee.com",
  "https://www.solutiontee.com",
  "https://app.solutiontee.com",
  "https://admin.solutiontee.com",
];
const XML = `<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration>
  <CORSRule>
${ORIGINS.map((o) => `    <AllowedOrigin>${o}</AllowedOrigin>`).join("\n")}
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>content-type</AllowedHeader>
    <AllowedHeader>range</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <ExposeHeader>Content-Length</ExposeHeader>
    <ExposeHeader>Content-Range</ExposeHeader>
    <MaxAgeSeconds>3600</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>`;

const aws = new AwsClient({ accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY, service: "s3", region: "auto" });
const url = `${env.R2_ENDPOINT.replace(/\/+$/, "")}/${env.R2_BUCKET}?cors`;

if (process.argv.includes("--apply")) {
  const md5 = (await import("node:crypto")).createHash("md5").update(XML).digest("base64");
  const r = await aws.fetch(url, { method: "PUT", body: XML, headers: { "content-type": "application/xml", "content-md5": md5 } });
  console.log("PUT cors:", r.status, (await r.text()).slice(0, 300));
}
const r = await aws.fetch(url);
console.log("bucket:", env.R2_BUCKET, "GET cors:", r.status);
console.log((await r.text()).slice(0, 1500));
