import "server-only";

/** Server-side settings. Public values may also be read in the browser via NEXT_PUBLIC_*. Never log secrets. */
const read = (k: string) => (process.env[k] ?? "").trim();

export const env = {
  supabaseUrl: read("NEXT_PUBLIC_SUPABASE_URL"),
  supabasePublishableKey: read("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"),
  supabaseSecretKey: read("SUPABASE_SECRET_KEY"),
  r2: {
    endpoint: read("R2_ENDPOINT").replace(/\/+$/, ""),
    accessKeyId: read("R2_ACCESS_KEY_ID"),
    secretAccessKey: read("R2_SECRET_ACCESS_KEY"),
    bucket: read("R2_BUCKET"),
    publicBaseUrl: read("R2_PUBLIC_BASE_URL").replace(/\/+$/, ""),
    signedUrlTtl: Number(read("R2_SIGNED_URL_TTL")) || 300,
  },
  brevo: {
    apiKey: read("BREVO_API_KEY"),
    fromEmail: read("BREVO_FROM_EMAIL") || read("MAIL_SENDER_NOREPLY"),
    fromName: read("MAIL_FROM_NAME") || read("BREVO_FROM_NAME") || "SolutionTee CBT",
  },
  mail: {
    noreply: read("MAIL_SENDER_NOREPLY") || read("BREVO_FROM_EMAIL"),
    info: read("MAIL_SENDER_INFO") || read("BREVO_FROM_EMAIL"),
    support: read("MAIL_SENDER_SUPPORT") || read("MAIL_SENDER_INFO"),
    logoUrl: read("EMAIL_LOGO_URL"),
  },
  siteUrl: read("NEXT_PUBLIC_SITE_URL") || "http://localhost:3000",
};

export const hasServiceKey = () => Boolean(env.supabaseSecretKey);
export const hasR2 = () => Boolean(env.r2.endpoint && env.r2.accessKeyId && env.r2.secretAccessKey && env.r2.bucket);
export const hasBrevo = () => Boolean(env.brevo.apiKey && env.brevo.fromEmail);
