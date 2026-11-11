import "server-only";
import { env } from "@/lib/env";

/*
 * SolutionTee emails (D-123, revised after the owner's review: "less generic, no pills").
 * A calm letter, the way a real company writes: white card, the real brand mark (public PNG, never redrawn), a plain
 * heading, short paragraphs, thin-rule notes, one navy button, a sign-off from the team and a quiet footer.
 * No badges, no emoji in headings or subjects, no gradient banners. Table layout with inline styles so it looks the
 * same in Gmail, Outlook, Yahoo and phone mail apps; 600 px on computers, full width on phones. Every email also has a
 * plain-text version and the JAMB/WAEC/NECO disclaimer.
 */
const NAVY = "#0B1F44", GOLD = "#C98A0B", TEXT = "#1B2638", MUTED = "#5B677A", LINE = "#E4E8EF", BG = "#F3F5F9", SOFT = "#F7F9FC";
const RED = "#B42318";
const FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
const SITE = "https://cbt.solutiontee.com";
const DISCLAIMER = "SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.";
const COMPANY = "SOLUTIONTEE EDUTECH AND ICT SERVICES (RC 9123561), Ipaja, Lagos, Nigeria";
const support = () => env.mail.support || "support@mail.solutiontee.com";

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
const first = (name: string) => name.trim().split(/\s+/)[0] ?? "";

/* ------------------------------------------------------------------ building blocks */
const p = (html: string, extra = "") => `<p style="margin:0 0 16px;font-size:15px;line-height:24px;color:${TEXT};${extra}">${html}</p>`;
const small = (html: string) => `<p style="margin:18px 0 0;font-size:13px;line-height:20px;color:${MUTED}">${html}</p>`;
const h2 = (html: string) => `<p style="margin:26px 0 10px;font-size:14px;line-height:20px;font-weight:700;color:${NAVY}">${html}</p>`;
const signoff = `<p style="margin:26px 0 0;font-size:15px;line-height:24px;color:${TEXT}">Best wishes,<br><b>The SolutionTee team</b></p>`;

/** A plain button that works in Outlook too (table cell + link, no images). */
function button(label: string, href: string, kind: "primary" | "danger" = "primary") {
  const s = kind === "primary" ? { bg: NAVY, fg: "#FFFFFF", bd: NAVY } : { bg: "#FFFFFF", fg: RED, bd: RED };
  return `<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:22px 0 4px"><tr>
<td align="center" bgcolor="${s.bg}" style="border-radius:8px;border:1px solid ${s.bd}">
<a href="${esc(href)}" target="_blank" style="display:inline-block;padding:13px 24px;font-family:${FONT};font-size:15px;font-weight:600;line-height:20px;color:${s.fg};text-decoration:none;border-radius:8px">${esc(label)}</a>
</td></tr></table>`;
}

/** The code students type in the app. */
function codeBox(code: string, hint: string) {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:4px 0 18px"><tr>
<td style="background:${SOFT};border:1px solid ${LINE};border-radius:8px;padding:18px 20px">
<div class="code" style="font-family:'SF Mono',Consolas,Menlo,monospace;font-size:32px;line-height:38px;font-weight:700;letter-spacing:8px;color:${NAVY}">${esc(code)}</div>
<div style="margin-top:6px;font-size:13px;line-height:18px;color:${MUTED}">${hint}</div></td></tr></table>`;
}

/** A note set off with a thin rule on the left (no icons). */
function note(html: string, tone: "neutral" | "warn" | "danger" = "neutral") {
  const bar = tone === "danger" ? RED : tone === "warn" ? GOLD : NAVY;
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:4px 0 16px"><tr>
<td style="width:3px;background:${bar}"></td>
<td style="background:${SOFT};padding:12px 16px;font-size:14px;line-height:22px;color:${TEXT}">${html}</td></tr></table>`;
}

/** A short list. */
function list(items: string[]) {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 14px">${items
    .map((i) => `<tr><td valign="top" style="width:18px;padding:3px 0;font-size:15px;line-height:24px;color:${MUTED}">&ndash;</td>
<td style="padding:3px 0;font-size:15px;line-height:24px;color:${TEXT}">${i}</td></tr>`).join("")}</table>`;
}

/** Numbered steps. */
function steps(items: [string, string][]) {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 12px">${items
    .map(([t, d], i) => `<tr><td valign="top" style="width:26px;padding:6px 0;font-size:15px;line-height:22px;font-weight:700;color:${GOLD}">${i + 1}.</td>
<td style="padding:6px 0;font-size:15px;line-height:22px;color:${TEXT}"><b>${t}</b><br><span style="color:${MUTED}">${d}</span></td></tr>`).join("")}</table>`;
}

/** Label and value rows (an amount, a date, details of a change). */
function details(rows: [string, string][]) {
  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:4px 0 18px;border-top:1px solid ${LINE};border-bottom:1px solid ${LINE}">${rows
    .map(([k, v], i) => `<tr><td style="padding:12px 0;font-size:14px;line-height:20px;color:${MUTED};${i ? `border-top:1px solid ${LINE};` : ""}">${k}</td>
<td align="right" style="padding:12px 0;font-size:15px;line-height:20px;font-weight:700;color:${TEXT};${i ? `border-top:1px solid ${LINE};` : ""}">${v}</td></tr>`).join("")}</table>`;
}

type Layout = { title: string; preheader: string; heading: string; body: string; why?: string };

function layout({ title, preheader, heading, body, why }: Layout) {
  const logo = env.mail.logoUrl || `${SITE}/brand/solutiontee-mark-transparent.png`;
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light"><meta name="supported-color-schemes" content="light"><title>${esc(title)}</title>
<style>
  body{margin:0!important;padding:0!important;width:100%!important}
  @media (max-width:620px){.wrap{width:100%!important}.pad{padding-left:22px!important;padding-right:22px!important}.h1{font-size:21px!important;line-height:28px!important}.code{font-size:28px!important;letter-spacing:6px!important}}
</style></head>
<body style="margin:0;padding:0;background:${BG};font-family:${FONT};color:${TEXT};-webkit-font-smoothing:antialiased">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${esc(preheader)}&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:${BG}"><tr><td align="center" style="padding:32px 12px">
<table role="presentation" class="wrap" width="600" cellspacing="0" cellpadding="0" border="0" style="width:600px;max-width:600px">
  <tr><td bgcolor="#FFFFFF" style="background:#FFFFFF;border:1px solid ${LINE};border-top:3px solid ${NAVY};border-radius:10px">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
      <tr><td class="pad" style="padding:26px 36px 20px;border-bottom:1px solid ${LINE}">
        <img src="${esc(logo)}" width="34" height="30" alt="SolutionTee" style="display:inline-block;vertical-align:middle;border:0">
        <span style="display:inline-block;vertical-align:middle;margin-left:10px;font-size:17px;font-weight:700;color:${NAVY}">SolutionTee CBT</span>
      </td></tr>
      <tr><td class="pad" style="padding:30px 36px 32px">
        <h1 class="h1" style="margin:0 0 18px;font-size:23px;line-height:30px;font-weight:700;color:${NAVY}">${heading}</h1>
        ${body}
      </td></tr>
    </table>
  </td></tr>
  <tr><td class="pad" style="padding:22px 36px 0;font-size:12px;line-height:19px;color:#7A8597">
    ${why ? `${why} ` : ""}Questions? Reply to this email, write to <a href="mailto:${esc(support())}" style="color:#7A8597">${esc(support())}</a>
    or WhatsApp <a href="https://wa.me/2348122445948" style="color:#7A8597">+234 812 244 5948</a>.
    <p style="margin:10px 0 0;font-size:12px;line-height:19px;color:#7A8597"><a href="${SITE}" style="color:#7A8597">cbt.solutiontee.com</a> &nbsp;|&nbsp;
    <a href="${SITE}/privacy" style="color:#7A8597">Privacy Policy</a> &nbsp;|&nbsp; <a href="${SITE}/terms" style="color:#7A8597">Terms</a></p>
    <p style="margin:10px 0 0;font-size:11px;line-height:17px;color:#98A1B0">${COMPANY}.<br>${DISCLAIMER}</p>
  </td></tr>
</table></td></tr></table></body></html>`;
}

const footText = (why?: string) =>
  `\n\nBest wishes,\nThe SolutionTee team\n\n${why ? `${why}\n` : ""}Help: ${support()} · WhatsApp +234 812 244 5948 · ${SITE}\n${COMPANY}\n${DISCLAIMER}`;

/* ------------------------------------------------------------------ account and security */
export function signupCodeEmail(name: string, code: string) {
  const hi = first(name) ? `Hi ${esc(first(name))},` : "Hi,";
  return {
    subject: `${code} is your SolutionTee code`,
    html: layout({
      title: "Confirm your email", preheader: `Your code is ${code}. Type it in the app to finish signing up.`, heading: "Confirm your email address",
      body: p(hi) + p("Thanks for signing up for SolutionTee CBT. Type this code in the app to confirm your email:") + codeBox(code, "It works once and expires soon.")
        + small("If you did not create an account, you can ignore this email. Nobody can use your email address without this code.") + signoff,
      why: "You are receiving this because this email address was used to sign up for SolutionTee CBT.",
    }),
    text: `${first(name) ? `Hi ${first(name)},` : "Hi,"}\n\nThanks for signing up for SolutionTee CBT. Your code is: ${code}\n\nType it in the app to confirm your email. It works once and expires soon.\nIf you did not create an account, ignore this email.${footText()}`,
  };
}

export function resetCodeEmail(code: string) {
  return {
    subject: `${code} is your SolutionTee password reset code`,
    html: layout({
      title: "Reset your password", preheader: `Your password reset code is ${code}.`, heading: "Reset your password",
      body: p("We received a request to reset the password for your SolutionTee account. Type this code in the app:") + codeBox(code, "It works once and expires soon.")
        + note("If you did not ask for this, ignore this email. Your password stays the same and your account is safe.") + signoff,
    }),
    text: `We received a request to reset the password for your SolutionTee account.\n\nYour code is: ${code}\n\nIf you did not ask for this, ignore this email. Your password stays the same.${footText()}`,
  };
}

export function passwordChangedEmail(when: string) {
  return {
    subject: "Your SolutionTee password was changed",
    html: layout({
      title: "Password changed", preheader: `Your password was changed on ${when}.`, heading: "Your password was changed",
      body: p("This is a quick confirmation that the password for your SolutionTee account was changed.") + details([["Changed on", esc(when)]])
        + p("If this was you, there is nothing else to do.")
        + note("<b>Not you?</b> Reset your password in the app now (Log in, then Forgot password) and reply to this email so we can secure your account.", "danger") + signoff,
    }),
    text: `Your SolutionTee password was changed on ${when}.\n\nIf this was you, there is nothing else to do. If it was not you, reset your password in the app now and reply to this email so we can help.${footText()}`,
  };
}

export function welcomeEmail(name: string) {
  const n = first(name) ? esc(first(name)) : "there";
  return {
    subject: "Welcome to SolutionTee CBT",
    html: layout({
      title: "Welcome", preheader: "Your account is ready. Here is a simple way to start.", heading: `Welcome to SolutionTee CBT, ${n}`,
      body: p("Your account is ready. You can now practise JAMB, WAEC and NECO questions in a real computer-based test, read a clear explanation for every answer, and ask the AI tutor whenever you are stuck.")
        + h2("A simple way to start")
        + steps([
          ["Take a quick test", "It takes about 10 minutes and shows where you stand."],
          ["Work on your weak topics", "Your results show exactly what to practise next."],
          ["Come back every day", "The question of the day keeps your streak going."],
        ])
        + p("Tip: download questions while you have data, then practise offline. Your results sync when you are back online.", `color:${MUTED};font-size:14px`)
        + button("Open SolutionTee CBT", SITE) + signoff,
      why: "You are receiving this because you created a SolutionTee CBT account.",
    }),
    text: `Hi ${first(name) || "there"},\n\nWelcome to SolutionTee CBT. Your account is ready.\n\nA simple way to start:\n1. Take a quick test.\n2. Work on your weak topics.\n3. Come back every day to keep your streak.\n\n${SITE}${footText()}`,
  };
}

export function inviteEmail(link: string, role: string, inviter: string) {
  return {
    subject: "You're invited to the SolutionTee admin",
    html: layout({
      title: "Admin invite", preheader: `${inviter} invited you to the SolutionTee admin as ${role}.`, heading: "You have been invited to the admin",
      body: p(`${esc(inviter)} invited you to help run SolutionTee CBT as <b>${esc(role)}</b>.`)
        + steps([["Accept the invite", "Choose your own password."], ["Turn on 2-step login", "Use an authenticator app. It is required for all staff."]])
        + button("Accept the invite", link)
        + small("This link works once and expires in 24 hours. If you did not expect this invite, you can ignore this email.") + signoff,
    }),
    text: `${inviter} invited you to the SolutionTee CBT admin as ${role}.\n\nAccept the invite (works once, expires in 24 hours):\n${link}\n\nIf you did not expect it, ignore this email.`,
  };
}

export function testEmail(name: string) {
  return {
    subject: "SolutionTee test email",
    html: layout({
      title: "Test email", preheader: "If you can read this, SolutionTee emails are working.", heading: "Your emails are working",
      body: p(`Hi ${esc(name)}, this is a test from the SolutionTee admin.`) + p("This is how a code looks:") + codeBox("482139", "Example only.")
        + button("Open the website", SITE) + signoff,
    }),
    text: `Hi ${name}, this is a test from the SolutionTee admin. If you can read this, emails are working.`,
  };
}

/** Reply to a banned phone's appeal (D-079). */
export function phoneAppealEmail(accepted: boolean, noteText: string) {
  const head = accepted ? "Your phone is no longer banned" : "Your appeal was not accepted";
  const line = accepted
    ? "We have reviewed your appeal. You can use SolutionTee CBT on this phone again. Open the app and log in."
    : "We have reviewed your appeal. The ban on this phone stays in place.";
  return {
    subject: `SolutionTee CBT: ${head.toLowerCase()}`,
    html: layout({
      title: head, preheader: line, heading: head,
      body: p("Hi,") + p(line) + (noteText.trim() ? note(esc(noteText.trim())) : "") + signoff,
    }),
    text: `Hi,\n\n${line}${noteText.trim() ? `\n\n${noteText.trim()}` : ""}${footText()}`,
  };
}

/* ------------------------------------------------------------------ parents and guardians */
/**
 * Parent/guardian notice for a student aged 13 to 17 (D-109). Reading it is enough: the parent only acts to turn
 * the account off. Plain summary of the Privacy Policy and Terms; the full text is on the website.
 */
export function guardianNoticeEmail(childName: string, childEmail: string, stopLink: string) {
  const child = first(childName) ? esc(first(childName)) : "Your child";
  const childPlain = first(childName) || "Your child";
  return {
    subject: `${childPlain} has joined SolutionTee CBT`,
    html: layout({
      title: "Welcome to SolutionTee CBT", preheader: `${childPlain} created an account and named you as their parent or guardian.`,
      heading: `${child} has joined SolutionTee CBT`,
      body: p("Hello,") + p(`<b>${child}</b> (${esc(childEmail)}) has created a SolutionTee CBT account and gave us your email address as their parent or guardian.`)
        + p("SolutionTee CBT helps students prepare for JAMB, WAEC and NECO with a real computer-based test, an explanation for every answer, video lessons, study notes and an AI tutor that only helps with schoolwork.")
        + note(`By receiving this email and letting ${child} keep using the app, you agree, for ${child} and for yourself, to our Privacy Policy and Terms of Service. <b>You do not need to do anything to approve.</b>`)
        + h2(`How we look after ${child}'s data`)
        + list([
          "We collect only what the app needs: name, email, state, school (optional), year of birth, exam choices, practice results and AI tutor chats.",
          "We never sell personal data. Students under 18 never see personalised ads, only general, age-appropriate ones.",
          "If your child ever wins cash, we email you first.",
          "Payments are always optional. Free practice is available every day.",
          `You can ask us to see, correct or delete ${child}'s data at any time by replying to this email.`,
        ])
        + h2("If you do not agree")
        + p(`Use the button below. ${child}'s account will be turned off at once and deleted after 30 days.`, "margin-bottom:0")
        + button(first(childName) ? `Turn off ${first(childName)}'s account` : "Turn off this account", stopLink, "danger")
        + small(`The full <a href="${SITE}/privacy" style="color:${MUTED}">Privacy Policy</a> and <a href="${SITE}/terms" style="color:${MUTED}">Terms of Service</a> are on our website.`)
        + signoff,
      why: `You are receiving this because ${childPlain} named you as their parent or guardian.`,
    }),
    text: `Hello,\n\n${childPlain} (${childEmail}) has created a SolutionTee CBT account and gave us your email as their parent or guardian.\n\nSolutionTee CBT helps students prepare for JAMB, WAEC and NECO with a real CBT, answers explained, video lessons, notes and an AI tutor for schoolwork only.\n\nBy receiving this email and letting ${childPlain} keep using the app, you agree, for ${childPlain} and for yourself, to our Privacy Policy and Terms of Service. You do not need to do anything to approve.\n\nHow we look after the data:\n- We collect only what the app needs: name, email, state, school (optional), year of birth, exam choices, practice results and AI tutor chats.\n- We never sell personal data. Students under 18 never see personalised ads.\n- If your child ever wins cash, we email you first.\n- Payments are always optional.\n- You can ask us to see, correct or delete ${childPlain}'s data at any time by replying to this email.\n\nIf you do not agree, open this link to turn off ${childPlain}'s account (deleted after 30 days):\n${stopLink}\n\nPrivacy Policy: ${SITE}/privacy · Terms: ${SITE}/terms${footText(`You are receiving this because ${childPlain} named you as their parent or guardian.`)}`,
  };
}

/** A student aged 13 to 17 won cash (D-121, lawyer): their parent or guardian is told before the prize is paid. */
export function guardianPrizeEmail(childName: string, amountNaira: number, title: string, kind: "challenge" | "referral") {
  const child = first(childName) ? esc(first(childName)) : "Your child";
  const childPlain = first(childName) || "Your child";
  const amount = `₦${amountNaira.toLocaleString("en-NG")}`;
  const what = kind === "challenge" ? `a prize in the SolutionTee challenge “${esc(title)}”` : "a reward for inviting friends to SolutionTee CBT";
  const whatPlain = kind === "challenge" ? `a prize in the SolutionTee challenge "${title}"` : "a reward for inviting friends to SolutionTee CBT";
  return {
    subject: `${childPlain} has won ${amount} on SolutionTee CBT`,
    html: layout({
      title: "A prize for your child", preheader: `${childPlain} won ${amount}. Here is what happens next.`, heading: `${child} has won a prize`,
      body: p("Hello,") + p(`We are pleased to tell you that <b>${child}</b> has won ${what}. Well done to them.`)
        + details([["Prize", amount], [kind === "challenge" ? "Challenge" : "For", kind === "challenge" ? esc(title) : "Inviting friends"]])
        + h2("What happens next")
        + steps([
          ["Paid to a parent or guardian", `Because ${child} is under 18, the prize goes to a parent's or guardian's bank account, which ${child} gives us in the app with your name and phone number.`],
          ["Free to enter", "Nobody paid money or XP to take part."],
          ["We may call to confirm", "We may call the number given before we pay."],
        ])
        + note(`<b>If you do not agree</b> with ${child} receiving this prize, reply to this email within 7 days and we will not pay it.`, "warn") + signoff,
      why: `You are receiving this because ${childPlain} named you as their parent or guardian on SolutionTee CBT.`,
    }),
    text: `Hello,\n\nWe are pleased to tell you that ${childPlain} has won ${amount}, ${whatPlain}.\n\nWhat happens next:\n- Because ${childPlain} is under 18, the prize is paid to a parent or guardian's bank account, which ${childPlain} will give us in the app with your name and phone number.\n- Entering was free. Nobody paid money or XP to take part.\n- We may call the number given to confirm before we pay.\n\nIf you do not agree with ${childPlain} receiving this prize, reply to this email within 7 days and we will not pay it.${footText(`You are receiving this because ${childPlain} named you as their parent or guardian on SolutionTee CBT.`)}`,
  };
}

/* ------------------------------------------------------------------ website */
/** Website log-in code (cbt.solutiontee.com/pay, D-114). Only sent to existing accounts. */
export function webLoginCodeEmail(code: string) {
  return {
    subject: `${code} is your SolutionTee log-in code`,
    html: layout({
      title: "Log in to pay", preheader: `Your website log-in code is ${code}.`, heading: "Your log-in code",
      body: p("Use this code to log in on the SolutionTee website and get Premium:") + codeBox(code, "It works for 10 minutes.")
        + note("If you did not ask for this, ignore this email. Nobody can log in without this code.") + signoff,
    }),
    text: `Use this code to log in on the SolutionTee website and get Premium: ${code}\n\nIt works for 10 minutes. If this was not you, ignore this email.${footText()}`,
  };
}

/** Account deletion from the website (cbt.solutiontee.com/delete-account, Google Play requirement, D-118). */
export function deleteCodeEmail(code: string) {
  return {
    subject: `${code} is your code to delete your SolutionTee account`,
    html: layout({
      title: "Delete your account", preheader: `Your code to delete your account is ${code}.`, heading: "Confirm you want to delete your account",
      body: p("We received a request to delete the SolutionTee CBT account for this email address. Use this code on the website to confirm:") + codeBox(code, "It works for 10 minutes.")
        + note("Deleting is permanent: your progress, XP and any Premium time left are lost. If you did not ask for this, ignore this email and nothing will be deleted.", "danger") + signoff,
    }),
    text: `We received a request to delete the SolutionTee CBT account for this email. Your code is: ${code}\n\nIt works for 10 minutes. If this was not you, ignore this email: nothing will be deleted.${footText()}`,
  };
}

/** 24 months without activity (Privacy Policy §10, D-119): sent 30+ days before the account is deleted. */
export function inactiveNoticeEmail(name: string, deleteOn: string, appLink: string) {
  const hi = first(name) ? `Hi ${esc(first(name))},` : "Hi,";
  return {
    subject: "Your SolutionTee account will be deleted soon",
    html: layout({
      title: "Keep your account?", preheader: `Log in before ${deleteOn} to keep your account.`, heading: "Would you like to keep your account?",
      body: p(hi) + p("You have not used SolutionTee CBT for almost two years. To protect your data, we delete accounts that have not been used for two years.")
        + details([["Account will be deleted on", esc(deleteOn)]])
        + p("To keep your account, simply open the app and log in before that date. Nothing else is needed.")
        + button("Open SolutionTee CBT", appLink)
        + small("If you do nothing, your account and practice history will be deleted for good. Payment records are kept only as the law requires.") + signoff,
      why: "You are receiving this because you have a SolutionTee CBT account.",
    }),
    text: `${first(name) ? `Hi ${first(name)},` : "Hi,"}\n\nYou have not used SolutionTee CBT for almost two years. To protect your data, we delete accounts that have not been used for two years.\n\nYour account will be deleted on ${deleteOn}.\n\nTo keep it, open the app and log in before then: ${appLink}\n\nIf you do nothing, your account is deleted for good. Payment records are kept only as the law requires.${footText()}`,
  };
}

/* ------------------------------------------------------------------ account status and important moments (D-127) */
const naira = (kobo: number) => `₦${Math.round(kobo / 100).toLocaleString("en-NG")}`;
const day = (iso: string | null | undefined) =>
  iso ? new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "Africa/Lagos" }) : "";
const hello = (name: string) => (first(name) ? `Hi ${esc(first(name))},` : "Hi,");
const helloText = (name: string) => (first(name) ? `Hi ${first(name)},` : "Hi,");

/** Account banned (by an admin, or because the phone was banned). */
export function accountBannedEmail(name: string, reason: string | null) {
  const why = (reason ?? "").trim() || "Breaking our rules of conduct.";
  return {
    subject: "Your SolutionTee account has been suspended",
    html: layout({
      title: "Account suspended", preheader: "Your account has been suspended. Here is why and how to appeal.", heading: "Your account has been suspended",
      body: p(hello(name)) + p("We have suspended your SolutionTee CBT account, so you cannot use the app with it for now.")
        + details([["Reason", esc(why)]])
        + h2("Think this is a mistake?")
        + p("Open the app and log in. You will see the reason and a button to <b>send an appeal</b>. A person reads every appeal, usually within 2 working days, and we email you the answer.")
        + small("Any Premium time you paid for is kept while we review an appeal. Our rules are in the Terms of Service, section 8.") + signoff,
      why: "You are receiving this because of a change to your SolutionTee CBT account.",
    }),
    text: `${helloText(name)}\n\nWe have suspended your SolutionTee CBT account.\n\nReason: ${why}\n\nThink this is a mistake? Open the app and log in to see the reason and send an appeal. A person reads every appeal, usually within 2 working days.${footText()}`,
  };
}

export function accountUnbannedEmail(name: string) {
  return {
    subject: "Your SolutionTee account is open again",
    html: layout({
      title: "Account open again", preheader: "You can use SolutionTee CBT again.", heading: "Your account is open again",
      body: p(hello(name)) + p("Good news: your SolutionTee CBT account is no longer suspended. Open the app and log in to carry on practising.")
        + note("Please keep to our rules: one account per person and per phone, and no cheating in challenges.") + button("Open SolutionTee CBT", SITE) + signoff,
    }),
    text: `${helloText(name)}\n\nYour SolutionTee CBT account is no longer suspended. Open the app and log in to carry on.\n\nPlease keep to our rules: one account per person and per phone.${footText()}`,
  };
}

/** A second account signed in on a phone that already has one. */
export function secondAccountBlockedEmail(name: string) {
  return {
    subject: "Your SolutionTee account is paused on this phone",
    html: layout({
      title: "One account per phone", preheader: "This phone already has a SolutionTee account.", heading: "This phone already has an account",
      body: p(hello(name)) + p("You logged in to SolutionTee CBT on a phone that another account already uses. To keep challenges and rewards fair, each phone can have <b>one account</b>, so this account is paused on that phone.")
        + h2("What you can do")
        + steps([
          ["Use your first account", "Log out and log in with the account that was on this phone first."],
          ["Sharing with a brother or sister?", "Reply to this email with both names and the email addresses of both accounts. If it is a real family phone, we can allow both."],
          ["Use your own phone", "This account works normally on a phone that has no other account."],
        ])
        + small("Making several accounts to collect rewards is against our Terms of Service and can lead to every account being suspended.") + signoff,
      why: "You are receiving this because your SolutionTee CBT account was used on a shared phone.",
    }),
    text: `${helloText(name)}\n\nYou logged in on a phone that another SolutionTee CBT account already uses. Each phone can have one account, so this account is paused on that phone.\n\nWhat you can do:\n1. Log in with the account that was on this phone first.\n2. Sharing with a brother or sister? Reply with both names and both email addresses and we can allow both.\n3. Use this account on your own phone.${footText()}`,
  };
}

export function phoneAllowedEmail(name: string) {
  return {
    subject: "You can use SolutionTee on your phone again",
    html: layout({
      title: "Allowed on this phone", preheader: "We have allowed your account on the shared phone.", heading: "You are allowed on this phone",
      body: p(hello(name)) + p("We checked the phone you share, and your account can now be used on it. Open the app and you can carry on straight away.")
        + button("Open SolutionTee CBT", SITE) + signoff,
    }),
    text: `${helloText(name)}\n\nWe checked the phone you share, and your account can now be used on it. Open the app to carry on.${footText()}`,
  };
}

export function banAppealEmail(name: string, accepted: boolean, noteText: string | null) {
  const head = accepted ? "Your appeal was accepted" : "Your appeal was not accepted";
  const line = accepted
    ? "We have reviewed your appeal and your account is open again. Open the app and log in to carry on."
    : "We have reviewed your appeal carefully. The suspension stays in place.";
  return {
    subject: `SolutionTee CBT: ${head.toLowerCase()}`,
    html: layout({
      title: head, preheader: line, heading: head,
      body: p(hello(name)) + p(line) + ((noteText ?? "").trim() ? note(esc(noteText!.trim())) : "") + (accepted ? button("Open SolutionTee CBT", SITE) : "") + signoff,
    }),
    text: `${helloText(name)}\n\n${line}${(noteText ?? "").trim() ? `\n\n${noteText!.trim()}` : ""}${footText()}`,
  };
}

/** Receipt after a successful Paystack or Google Play payment. */
export function paymentReceiptEmail(name: string, d: { reference?: string; provider?: string; amount_kobo?: number; discount_kobo?: number; fee_kobo?: number; plan?: string | null; item?: string | null; at?: string; expires_at?: string | null }) {
  const what = d.plan ? `${d.plan} Premium` : d.item ? `Single item (${d.item})` : "Premium";
  const rows: [string, string][] = [["Bought", esc(what)], ["Amount paid", naira(d.amount_kobo ?? 0)]];
  if (d.discount_kobo) rows.push(["Discount", `− ${naira(d.discount_kobo)}`]);
  if (d.fee_kobo) rows.push(["Includes processing fee", naira(d.fee_kobo)]);
  rows.push(["Paid with", d.provider === "play" ? "Google Play" : "Paystack"], ["Date", day(d.at)]);
  if (d.expires_at) rows.push(["Premium until", day(d.expires_at)]);
  if (d.reference) rows.push(["Reference", `<span style="font-family:monospace">${esc(d.reference)}</span>`]);
  return {
    subject: `Your SolutionTee receipt: ${what}`,
    html: layout({
      title: "Receipt", preheader: `Thank you. ${what} is active${d.expires_at ? ` until ${day(d.expires_at)}` : ""}.`, heading: "Thank you for your payment",
      body: p(hello(name)) + p(`Your payment went through and <b>${esc(what)}</b> is active on your account.`) + details(rows)
        + p("Premium does not renew by itself. Nothing else will be taken from your account.", `color:${MUTED};font-size:14px`)
        + small(`Keep this email as your receipt. Questions about a payment? Reply with the reference. Refunds follow our <a href="${SITE}/refunds" style="color:${MUTED}">Refund Policy</a>.`) + signoff,
      why: "You are receiving this because you paid for SolutionTee CBT.",
    }),
    text: `${helloText(name)}\n\nThank you. Your payment went through and ${what} is active.\n\n${rows.map(([k, v]) => `${k}: ${v.replace(/<[^>]+>/g, "")}`).join("\n")}\n\nPremium does not renew by itself. Keep this email as your receipt. Refund Policy: ${SITE}/refunds${footText()}`,
  };
}

export function prizePaidEmail(name: string, amountNaira: number, title: string | null, bank: string | null) {
  const amount = `₦${Math.round(amountNaira).toLocaleString("en-NG")}`;
  return {
    subject: `Your SolutionTee prize of ${amount} has been paid`,
    html: layout({
      title: "Prize paid", preheader: `We have sent your prize of ${amount}.`, heading: "Your prize has been paid",
      body: p(hello(name)) + p("Congratulations again. We have sent your prize to the account you gave us.")
        + details([["Prize", amount], ...(title ? [["Challenge", esc(title)] as [string, string]] : []), ...(bank ? [["Bank", esc(bank)] as [string, string]] : [])])
        + small("Transfers usually arrive within minutes, but some banks take up to 24 hours. If it has not arrived after a day, reply to this email.") + signoff,
    }),
    text: `${helloText(name)}\n\nWe have sent your prize of ${amount}${title ? ` for "${title}"` : ""} to the account you gave us. Transfers can take up to 24 hours.${footText()}`,
  };
}

export function guardianTurnedOffEmail(name: string) {
  return {
    subject: "Your SolutionTee account has been turned off",
    html: layout({
      title: "Account turned off", preheader: "Your parent or guardian turned your account off.", heading: "Your account has been turned off",
      body: p(hello(name)) + p("Your parent or guardian has turned off your SolutionTee CBT account, so you can no longer log in. The account and its data will be deleted after 30 days.")
        + p("If this was a mistake, ask your parent or guardian to reply to this email within 30 days and we can turn it back on.") + signoff,
    }),
    text: `${helloText(name)}\n\nYour parent or guardian has turned off your SolutionTee CBT account. It will be deleted after 30 days.\n\nIf this was a mistake, ask them to reply to this email within 30 days.${footText()}`,
  };
}

/** The code that confirms deleting an account from the app. */
export function deleteAppCodeEmail(code: string) {
  return {
    subject: `${code} is your code to delete your SolutionTee account`,
    html: layout({
      title: "Confirm account deletion", preheader: `Your code to delete your account is ${code}.`, heading: "Confirm you want to delete your account",
      body: p("You asked to delete your SolutionTee CBT account in the app. Type this code in the app to confirm:") + codeBox(code, "It works for 10 minutes.")
        + note("Deleting is permanent: your progress, XP, streaks and any Premium time left are lost. If you did not ask for this, change your password in the app and ignore this email.", "danger") + signoff,
    }),
    text: `You asked to delete your SolutionTee CBT account. Your code is: ${code}\n\nIt works for 10 minutes. If you did not ask for this, change your password and ignore this email.${footText()}`,
  };
}

/** Sent right after an account is deleted (app or website). */
export function accountDeletedEmail(name: string) {
  return {
    subject: "Your SolutionTee account has been deleted",
    html: layout({
      title: "Account deleted", preheader: "Your account and data have been deleted.", heading: "Your account has been deleted",
      body: p(hello(name)) + p("As you asked, your SolutionTee CBT account has been deleted. Your profile, practice history, AI chats and progress are removed (copies in our backups are cleared within 30 days).")
        + p("We keep only what the law requires, such as payment records for tax, without your account details.", `color:${MUTED};font-size:14px`)
        + p("Thank you for practising with us. We wish you the very best in your exams. You are always welcome back.")
        + small("Did not delete your account? Reply to this email straight away.") + signoff,
      why: "You are receiving this because your SolutionTee CBT account was deleted.",
    }),
    text: `${helloText(name)}\n\nAs you asked, your SolutionTee CBT account has been deleted. Your profile, practice history, AI chats and progress are removed (backups within 30 days). We keep only what the law requires, such as payment records.\n\nThank you for practising with us. Good luck in your exams.\n\nDid not delete your account? Reply straight away.${footText()}`,
  };
}

/** The SolutionTee team replied to a tutor request (D-149); the chat itself is in the app (Learn → Request a tutor). */
export function tutorReplyEmail(name: string, body: string) {
  return {
    subject: "SolutionTee replied about your tutor request",
    html: layout({
      title: "Tutor request reply", preheader: body.slice(0, 90), heading: "We replied to your tutor request",
      body: p(hello(name)) + p("Someone from the SolutionTee team replied to your request for a tutor:")
        + note(esc(body).replace(/\n/g, "<br>"))
        + p("Open the SolutionTee CBT app and go to <b>Request a tutor</b> to reply or see the tutor plans.")
        + small("For your safety, keep your chats with tutors inside the app or on the WhatsApp number we give you.") + signoff,
      why: "You are receiving this because you asked for a tutor on SolutionTee CBT.",
    }),
    text: `${helloText(name)}\n\nSomeone from the SolutionTee team replied to your tutor request:\n\n${body}\n\nOpen the SolutionTee CBT app and go to Request a tutor to reply.${footText()}`,
  };
}

const REASONS: Record<string, string> = {
  shared_phone: "More than one account used on the same phone", many_accounts: "Many accounts on the same phone",
  second_account: "A second account was tried on your phone", phone_banned: "A phone linked to your account was blocked",
  fair_play: "Tests that looked unfair (leaving the app, screenshots or answers too fast to read)",
  challenge_dq: "Being disqualified in a challenge", referral_abuse: "Invites that broke the rules",
  payment_abuse: "A payment refunded after Premium was given", reports: "Comments hidden after reports",
  ai_strike: "Breaking the AI tutor rules",
};

/** Automatic safety check, first step (D-145): what we noticed and what to do; a ban can follow if it goes on. */
export function safetyWarningEmail(name: string, reasons: string[]) {
  const items = reasons.map((r) => REASONS[r] ?? r.replace(/_/g, " "));
  return {
    subject: "A safety warning about your SolutionTee account",
    html: layout({
      title: "Safety warning", preheader: "Our automatic checks noticed something on your account.", heading: "Please read: a safety warning",
      body: p(hello(name)) + p("Our automatic safety checks noticed the following on your SolutionTee CBT account in the last 90 days:")
        + list(items.map(esc))
        + note("If this goes on, your account can be suspended. Please use one account per person and per phone, and practise fairly.", "warn")
        + p("If you think this is a mistake, simply reply to this email and a person will look at it.") + signoff,
      why: "You are receiving this because of an automatic safety check on your SolutionTee CBT account.",
    }),
    text: `${helloText(name)}\n\nOur automatic safety checks noticed the following on your account in the last 90 days:\n${items.map((i) => `- ${i}`).join("\n")}\n\nIf this goes on, your account can be suspended. Please use one account per person and per phone, and practise fairly.\n\nThink this is a mistake? Reply to this email.${footText()}`,
  };
}

/** Daily note for admins (D-145): only sent when something needs a look. */
export function adminAlertEmail(name: string, d: Record<string, unknown>) {
  const n = (k: string) => Number(d[k] ?? 0);
  const rows: [string, string, string][] = [
    ["Automatic bans (24 h)", String(n("auto_bans")), "/admin/safety"],
    ["Safety warnings sent (24 h)", String(n("warnings")), "/admin/safety"],
    ["Second accounts tried (24 h)", String(n("second_accounts")), "/admin/fraud"],
    ["Payments stuck as pending (24 h)", String(n("stuck_payments")), "/admin/payments"],
    ["Payouts waiting", String(n("payouts_waiting")), "/admin/winners"],
    ["Ban appeals waiting", String(n("appeals_waiting")), "/admin/fraud"],
    ["News comments reported", String(n("reported_comments")), "/admin/news/comments"],
  ].filter((r) => r[1] !== "0") as [string, string, string][];
  const admin = "https://admin.solutiontee.com";
  return {
    subject: `SolutionTee admin: ${rows.length} thing${rows.length === 1 ? "" : "s"} to look at`,
    html: layout({
      title: "Admin alerts", preheader: "Today's admin alerts.", heading: "Today's admin alerts",
      body: p(hello(name)) + details(rows.map(([k, v]) => [k, v])) + button("Open the admin", `${admin}${rows[0]?.[2] ?? "/admin"}`) + signoff,
      why: "You are receiving this because you are an admin of SolutionTee CBT. Turn these off in Admin → Safety.",
    }),
    text: `${helloText(name)}\n\nToday's admin alerts:\n${rows.map(([k, v, u]) => `- ${k}: ${v} (${admin}${u})`).join("\n")}${footText()}`,
  };
}

/** Builds the email for an outbox row (D-127). Unknown kinds return null and are marked failed. */
export function outboxEmail(kind: string, name: string, data: Record<string, unknown>) {
  const s = (k: string) => (typeof data[k] === "string" ? (data[k] as string) : null);
  const n = (k: string) => (typeof data[k] === "number" ? (data[k] as number) : 0);
  switch (kind) {
    case "account_banned": return accountBannedEmail(name, s("reason"));
    case "account_unbanned": return accountUnbannedEmail(name);
    case "second_account_blocked": return secondAccountBlockedEmail(name);
    case "phone_allowed": return phoneAllowedEmail(name);
    case "ban_appeal": return banAppealEmail(name, data.accepted === true, s("note"));
    case "payment_receipt": return paymentReceiptEmail(name, data as Parameters<typeof paymentReceiptEmail>[1]);
    case "prize_paid": return prizePaidEmail(name, n("amount"), s("title"), s("bank"));
    case "guardian_turned_off": return guardianTurnedOffEmail(name);
    case "safety_warning": return safetyWarningEmail(name, Array.isArray(data.reasons) ? (data.reasons as string[]) : []);
    case "admin_alert": return adminAlertEmail(name, data);
    case "tutor_reply": return tutorReplyEmail(name, s("body") ?? "");
    default: return null;
  }
}
