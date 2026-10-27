import "server-only";
import { env } from "@/lib/env";

// Branded, light emails that work in Gmail, Outlook and phone mail apps: tables-free, inline styles,
// brand colours from design/tokens.json, simple English. Every email has a plain-text version too.
const NAVY = "#0B1F44", GOLD = "#F2B233", TEXT = "#06132B", MUTED = "#4F5B70", BG = "#F4F6FA";
const DISCLAIMER = "SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.";

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

function layout(title: string, body: string) {
  // Logo only when a public URL is set (EMAIL_LOGO_URL); emails can't load images from localhost.
  const logo = env.mail.logoUrl ? `<img src="${esc(env.mail.logoUrl)}" width="32" height="28" alt="" style="vertical-align:middle;margin-right:10px">` : "";
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title></head>
<body style="margin:0;background:${BG};font-family:Arial,Helvetica,sans-serif;color:${TEXT}">
<div style="max-width:520px;margin:0 auto;padding:24px 16px">
  <div style="background:${NAVY};color:#fff;border-radius:16px 16px 0 0;padding:18px 24px;font-weight:700;font-size:17px">${logo}SolutionTee CBT</div>
  <div style="background:#fff;border-radius:0 0 16px 16px;padding:24px;font-size:15px;line-height:22px">${body}</div>
  <p style="font-size:11px;line-height:16px;color:#6B778C;margin:16px 4px 0">Need help? Reply to this email or write to ${esc(env.mail.support)}.<br>${DISCLAIMER}</p>
</div></body></html>`;
}

const codeBox = (code: string) =>
  `<div style="margin:20px 0;text-align:center"><span style="display:inline-block;background:${BG};border:1px solid #DCE2EB;border-radius:12px;padding:14px 22px;font-size:30px;font-weight:700;letter-spacing:8px;font-family:Consolas,Menlo,monospace;color:${NAVY}">${esc(code)}</span></div>`;

export function signupCodeEmail(name: string, code: string) {
  const hi = name ? `Hi ${esc(name.split(" ")[0]!)},` : "Hi,";
  return {
    subject: `${code} is your SolutionTee code`,
    html: layout("Confirm your email", `<p style="margin:0 0 8px">${hi}</p><p style="margin:0">Welcome to SolutionTee CBT. Type this code in the app to confirm your email:</p>${codeBox(code)}
      <p style="margin:0;color:${MUTED};font-size:13px">The code works once and expires soon. If you did not create an account, ignore this email.</p>`),
    text: `${hi}\n\nWelcome to SolutionTee CBT. Your code is: ${code}\n\nType it in the app to confirm your email. It works once and expires soon.\nIf you did not create an account, ignore this email.\n\n${DISCLAIMER}`,
  };
}

export function resetCodeEmail(code: string) {
  return {
    subject: `${code} is your SolutionTee password reset code`,
    html: layout("Reset your password", `<p style="margin:0">Someone asked to reset the password for your SolutionTee account. Type this code in the app:</p>${codeBox(code)}
      <p style="margin:0;color:${MUTED};font-size:13px">If this was not you, ignore this email. Your password stays the same.</p>`),
    text: `Someone asked to reset the password for your SolutionTee account.\n\nYour code is: ${code}\n\nIf this was not you, ignore this email. Your password stays the same.\n\n${DISCLAIMER}`,
  };
}

export function passwordChangedEmail(when: string) {
  return {
    subject: "Your SolutionTee password was changed",
    html: layout("Password changed", `<p style="margin:0 0 12px">Your SolutionTee password was changed on <b>${esc(when)}</b>.</p>
      <p style="margin:0">If this was you, you don't need to do anything. If it was not you, reset your password in the app now and reply to this email so we can help.</p>`),
    text: `Your SolutionTee password was changed on ${when}.\n\nIf this was not you, reset your password in the app now and reply to this email so we can help.\n\n${DISCLAIMER}`,
  };
}

export function welcomeEmail(name: string) {
  const first = name ? esc(name.split(" ")[0]!) : "there";
  return {
    subject: "Welcome to SolutionTee CBT",
    html: layout("Welcome", `<p style="margin:0 0 12px">Hi ${first}, welcome to SolutionTee CBT! 🎉</p>
      <p style="margin:0 0 12px">Practise JAMB, WAEC and NECO past questions in a real CBT, get every answer explained, and ask the AI tutor when you are stuck.</p>
      <p style="margin:0 0 4px"><b>Start here:</b></p>
      <p style="margin:0 0 12px">1. Take a quick test to see where you stand.<br>2. Check your weak topics on your profile.<br>3. Come back every day to keep your streak.</p>
      <p style="margin:0;color:${MUTED};font-size:13px">Learn. Think. Solve.</p>`),
    text: `Hi ${name ? name.split(" ")[0] : "there"}, welcome to SolutionTee CBT!\n\nPractise JAMB, WAEC and NECO past questions in a real CBT, get every answer explained, and ask the AI tutor when you are stuck.\n\nStart here:\n1. Take a quick test.\n2. Check your weak topics.\n3. Come back every day to keep your streak.\n\nLearn. Think. Solve.\n\n${DISCLAIMER}`,
  };
}

export function inviteEmail(link: string, role: string, inviter: string) {
  return {
    subject: "You're invited to the SolutionTee admin",
    html: layout("Admin invite", `<p style="margin:0 0 12px">${esc(inviter)} invited you to the SolutionTee CBT admin as <b>${esc(role)}</b>.</p>
      <p style="margin:0 0 20px;color:${MUTED}">Set your password, then turn on 2-step login with an authenticator app.</p>
      <a href="${esc(link)}" style="display:inline-block;background:${GOLD};color:${NAVY};font-weight:700;text-decoration:none;padding:14px 22px;border-radius:12px">Accept the invite</a>
      <p style="margin:20px 0 0;font-size:12px;color:#6B778C">This link works once and expires in 24 hours. If you did not expect it, ignore this email.</p>`),
    text: `${inviter} invited you to the SolutionTee CBT admin as ${role}.\n\nAccept the invite (works once, expires in 24 hours):\n${link}\n\nIf you did not expect it, ignore this email.`,
  };
}

export function testEmail(name: string) {
  return {
    subject: "SolutionTee test email",
    html: layout("Test email", `<p style="margin:0 0 12px">Hi ${esc(name)}, this is a test from the SolutionTee admin.</p><p style="margin:0">If you can read this, emails from SolutionTee are working. Here is what a code looks like:</p>${codeBox("12345678")}`),
    text: `Hi ${name}, this is a test from the SolutionTee admin. If you can read this, emails are working.`,
  };
}
