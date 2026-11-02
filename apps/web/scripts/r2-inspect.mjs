// Checks a stored file in R2: size, type, and for MP4s whether it can start playing before it fully downloads
// ("faststart": the moov index is at the start). Usage (from apps/web): node scripts/r2-inspect.mjs <key>
// Reads keys from .env.local; never prints them.
import { readFileSync } from "node:fs";
import { AwsClient } from "aws4fetch";

const env = Object.fromEntries(
  readFileSync(new URL("../.env.local", import.meta.url), "utf8")
    .split(/\r?\n/)
    .filter((l) => l.includes("=") && !l.trim().startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^["']|["']$/g, "")]),
);
const key = process.argv[2];
if (!key) throw new Error("Give a key, e.g. v/2026/10/x.mp4");
const aws = new AwsClient({ accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY, service: "s3", region: "auto" });
const url = `${env.R2_ENDPOINT.replace(/\/+$/, "")}/${env.R2_BUCKET}/${key}`;

const r = await aws.fetch(url, { headers: { range: "bytes=0-65535" } });
console.log("status", r.status, "type", r.headers.get("content-type"), "range", r.headers.get("content-range"), "accept-ranges", r.headers.get("accept-ranges"));
const buf = new Uint8Array(await r.arrayBuffer());
if (key.endsWith(".mp4")) {
  // Walk the top-level MP4 boxes in the first 64 KB.
  const boxes = [];
  let i = 0;
  while (i + 8 <= buf.length && boxes.length < 12) {
    const size = (buf[i] << 24) | (buf[i + 1] << 16) | (buf[i + 2] << 8) | buf[i + 3];
    const type = String.fromCharCode(...buf.slice(i + 4, i + 8));
    boxes.push(`${type}(${size >>> 0})`);
    if (size <= 0) break;
    i += size >>> 0;
  }
  console.log("top boxes:", boxes.join(" "));
  const moovFirst = boxes.findIndex((b) => b.startsWith("moov")), mdat = boxes.findIndex((b) => b.startsWith("mdat"));
  console.log(moovFirst >= 0 && (mdat < 0 || moovFirst < mdat) ? "faststart: YES (plays while downloading)" : "faststart: NO (phone must download the end of the file before it can play)");
}
