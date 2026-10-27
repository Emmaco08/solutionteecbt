import "server-only";
import { env, hasBrevo } from "@/lib/env";

export type Mail = { to: string; subject: string; html: string; text: string; from?: "noreply" | "info" | "support"; tags?: string[] };

/** Sends one transactional email through the Brevo API (free plan: 300/day). Replies go to support. */
export async function sendEmail(m: Mail): Promise<{ ok: boolean; error?: string }> {
  // Development-only test mode: write the email to the server log instead of sending it.
  if (process.env.EMAIL_TRANSPORT === "log" && process.env.NODE_ENV !== "production") {
    console.info(`[email:log] to=${m.to} from=${m.from ?? "noreply"} subject="${m.subject}"`);
    return { ok: true };
  }
  if (!hasBrevo()) return { ok: false, error: "Brevo is not configured" };
  const sender = env.mail[m.from ?? "noreply"] || env.brevo.fromEmail;
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": env.brevo.apiKey, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      sender: { email: sender, name: env.brevo.fromName },
      replyTo: { email: env.mail.support, name: "SolutionTee Support" },
      to: [{ email: m.to }],
      subject: m.subject,
      htmlContent: m.html,
      textContent: m.text,
      tags: m.tags,
    }),
  });
  if (!res.ok) return { ok: false, error: `Brevo said ${res.status}` };
  return { ok: true };
}
