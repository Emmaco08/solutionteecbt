import "server-only";
import { AwsClient } from "aws4fetch";
import { env, hasR2 } from "@/lib/env";

/** Cloudflare R2 (S3-compatible) presigned links. Keys never leave the server (D-045). */
function client() {
  if (!hasR2()) throw new Error("R2 is not configured");
  return new AwsClient({ accessKeyId: env.r2.accessKeyId, secretAccessKey: env.r2.secretAccessKey, service: "s3", region: "auto" });
}

const objectUrl = (key: string) => `${env.r2.endpoint}/${env.r2.bucket}/${key.split("/").map(encodeURIComponent).join("/")}`;

async function presign(method: "GET" | "PUT", key: string, seconds: number, contentType?: string) {
  const url = new URL(objectUrl(key));
  url.searchParams.set("X-Amz-Expires", String(seconds));
  const signed = await client().sign(new Request(url, { method, headers: contentType ? { "content-type": contentType } : undefined }), {
    aws: { signQuery: true },
  });
  return signed.url;
}

/** Upload link valid for 10 minutes. */
export const presignPut = (key: string, contentType: string) => presign("PUT", key, 600, contentType);
/** Read link valid for R2_SIGNED_URL_TTL seconds (default 300). */
export const presignGet = (key: string) => presign("GET", key, env.r2.signedUrlTtl);

export const ALLOWED_TYPES: Record<string, string> = {
  "image/webp": "webp", "image/png": "png", "image/jpeg": "jpg", "image/svg+xml": "svg",
};
export const MAX_BYTES = 2 * 1024 * 1024;
