import "server-only";
import { env, hasBrevo } from "@/lib/env";

/** Sends one transactional email through the Brevo API (300/day on the free plan). */
export async function sendEmail(to: string, subject: string, html: string): Promise<{ ok: boolean; error?: string }> {
  if (!hasBrevo()) return { ok: false, error: "Brevo is not configured" };
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": env.brevo.apiKey, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ sender: { email: env.brevo.fromEmail, name: env.brevo.fromName }, to: [{ email: to }], subject, htmlContent: html }),
  });
  if (!res.ok) return { ok: false, error: `Brevo said ${res.status}` };
  return { ok: true };
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

export function inviteEmail(link: string, role: string, inviter: string) {
  return `<!doctype html><html><body style="margin:0;background:#F4F6FA;font-family:Arial,sans-serif;color:#06132B">
  <div style="max-width:520px;margin:0 auto;padding:32px 16px">
    <div style="background:#0B1F44;color:#fff;border-radius:16px 16px 0 0;padding:20px 24px;font-weight:700;font-size:18px">SolutionTee Admin</div>
    <div style="background:#fff;border-radius:0 0 16px 16px;padding:24px">
      <p style="font-size:16px;margin:0 0 12px">${esc(inviter)} invited you to the SolutionTee CBT admin as <b>${esc(role)}</b>.</p>
      <p style="margin:0 0 20px;color:#4F5B70">Set your password, then turn on 2-step login with an authenticator app.</p>
      <a href="${esc(link)}" style="display:inline-block;background:#F2B233;color:#0B1F44;font-weight:700;text-decoration:none;padding:14px 22px;border-radius:12px">Accept the invite</a>
      <p style="margin:20px 0 0;font-size:12px;color:#6B778C">This link works once and expires in 24 hours. If you did not expect it, ignore this email.</p>
    </div>
  </div></body></html>`;
}
