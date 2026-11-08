import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { env, hasBrevo } from "@/lib/env";
import { PageHeader, PageSkeleton, Panel, Pill } from "@/components/admin/ui";
import {
  signupCodeEmail, resetCodeEmail, passwordChangedEmail, welcomeEmail, inviteEmail, guardianNoticeEmail, guardianPrizeEmail,
  webLoginCodeEmail, deleteCodeEmail, inactiveNoticeEmail, phoneAppealEmail, accountBannedEmail, accountUnbannedEmail, secondAccountBlockedEmail,
  phoneAllowedEmail, banAppealEmail, paymentReceiptEmail, prizePaidEmail, guardianTurnedOffEmail, deleteAppCodeEmail, accountDeletedEmail,
} from "@/lib/email-templates";
import { TestButton, Preview } from "./email-ui";

export const metadata: Metadata = { title: "Emails" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Emails /></Suspense>;
}

type BrevoStatus = { ok: boolean; plan?: string; senders: { email: string; active: boolean }[]; domains: { domain: string; ok: boolean }[] };

async function brevoStatus(): Promise<BrevoStatus> {
  if (!hasBrevo()) return { ok: false, senders: [], domains: [] };
  const h = { "api-key": env.brevo.apiKey, accept: "application/json" };
  try {
    const [acc, snd, dom] = await Promise.all(["/account", "/senders", "/senders/domains"].map((p) =>
      fetch(`https://api.brevo.com/v3${p}`, { headers: h, cache: "no-store" }).then((r) => (r.ok ? r.json() : null))));
    return {
      ok: Boolean(acc),
      plan: (acc?.plan ?? []).map((p: { type: string; credits?: number; creditsType?: string }) => `${p.type} (${p.credits ?? ""} ${p.creditsType === "sendLimit" ? "per day" : p.creditsType ?? ""})`).join(", "),
      senders: (snd?.senders ?? []).map((s: { email: string; active: boolean }) => ({ email: s.email, active: s.active })),
      domains: (dom?.domains ?? []).map((d: { domain_name: string; authenticated: boolean; verified: boolean }) => ({ domain: d.domain_name, ok: d.authenticated && d.verified })),
    };
  } catch {
    return { ok: false, senders: [], domains: [] };
  }
}

async function Emails() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [status, sent, outbox] = await Promise.all([brevoStatus(), supabase.rpc("email_sent_last_24h"), supabase.rpc("admin_email_outbox")]);
  const ob = (outbox.data ?? { waiting: 0, failed: 0, sent_7d: {} }) as { waiting: number; failed: number; sent_7d: Record<string, number> };
  const used = Number(sent.data ?? 0);
  const templates = [
    ["Sign-up code", signupCodeEmail("Tolu Adeyemi", "48213907")],
    ["Password reset code", resetCodeEmail("70315264")],
    ["Password changed", passwordChangedEmail("27 Oct 2026, 14:30 (Lagos time)")],
    ["Welcome", welcomeEmail("Tolu Adeyemi")],
    ["Staff invite", inviteEmail("https://solutiontee.com/admin/accept?token_hash=example", "Editor", "Ada Okoye")],
    ["Parent or guardian notice (13 to 17)", guardianNoticeEmail("Tolu Adeyemi", "tolu@example.com", "https://admin.solutiontee.com/guardian/stop?t=example")],
    ["Parent told about a prize (13 to 17)", guardianPrizeEmail("Tolu Adeyemi", 5000, "Weekly JAMB challenge", "challenge")],
    ["Website log-in code (to pay)", webLoginCodeEmail("482139")],
    ["Delete account code (website)", deleteCodeEmail("731904")],
    ["24 months inactive: last notice", inactiveNoticeEmail("Tolu Adeyemi", "9 December 2026", "https://cbt.solutiontee.com")],
    ["Phone ban appeal: accepted", phoneAppealEmail(true, "Thank you for explaining. Please keep to one account per phone.")],
    ["Account suspended (ban)", accountBannedEmail("Tolu Adeyemi", "More than one account to collect rewards")],
    ["Account open again (ban removed)", accountUnbannedEmail("Tolu Adeyemi")],
    ["Second account paused on a phone", secondAccountBlockedEmail("Tolu Adeyemi")],
    ["Allowed on a shared phone", phoneAllowedEmail("Tolu Adeyemi")],
    ["Ban appeal decided", banAppealEmail("Tolu Adeyemi", false, "We found several accounts made on the same day.")],
    ["Payment receipt", paymentReceiptEmail("Tolu Adeyemi", { reference: "st_8f2a91c04b7e3d5a6f10", provider: "paystack", amount_kobo: 507500, fee_kobo: 7500, plan: "3 Months", at: "2026-11-08T12:00:00Z", expires_at: "2027-02-06T12:00:00Z" })],
    ["Prize paid", prizePaidEmail("Tolu Adeyemi", 5000, "Weekly JAMB challenge", "GTBank")],
    ["Parent turned the account off (to the student)", guardianTurnedOffEmail("Tolu Adeyemi")],
    ["Delete account code (app)", deleteAppCodeEmail("528391")],
    ["Account deleted (goodbye)", accountDeletedEmail("Tolu Adeyemi")],
  ] as const;
  return (
    <>
      <PageHeader title="Emails" description="Login codes, password resets and notices are sent by SolutionTee through your Brevo account, with SolutionTee branding. Supabase does not send these emails." actions={<TestButton />} />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)]">
        <div className="space-y-4">
          <Panel title="Brevo connection">
            <ul className="space-y-2.5 text-sm">
              <li className="flex items-center justify-between">Account {status.ok ? <Pill tone="ok">Connected</Pill> : <Pill tone="error">Not connected</Pill>}</li>
              {status.plan ? <li className="flex items-center justify-between">Plan <span className="text-muted-foreground">{status.plan}</span></li> : null}
              <li className="flex items-center justify-between">Sent in the last 24 hours <b className="tnum">{used} / 280</b></li>
              {status.domains.map((d) => <li key={d.domain} className="flex items-center justify-between">{d.domain} {d.ok ? <Pill tone="ok">Verified</Pill> : <Pill>Not verified (not used)</Pill>}</li>)}
            </ul>
          </Panel>
          <Panel title="Automatic emails">
            <ul className="space-y-2.5 text-sm">
              <li className="flex items-center justify-between">Waiting to send <b className="tnum">{ob.waiting}</b></li>
              <li className="flex items-center justify-between">Failed 5 times {ob.failed ? <Pill tone="error">{ob.failed}</Pill> : <b className="tnum">0</b>}</li>
              {Object.entries(ob.sent_7d).map(([k, n]) => <li key={k} className="flex items-center justify-between text-muted-foreground">{k.replace(/_/g, " ")} (7 days) <b className="tnum text-foreground">{n}</b></li>)}
            </ul>
            <p className="mt-3 text-xs text-muted-foreground">Bans, paused phones, appeals, receipts, prizes and parent turn-offs are sent within 5 minutes. They stop when 220 emails were sent in a day, so log-in codes always get through.</p>
          </Panel>
          <Panel title="Who sends what">
            <ul className="space-y-2 text-sm">
              <li><b>Codes and security notices:</b> {env.mail.noreply}</li>
              <li><b>Welcome and staff invites:</b> {env.mail.info}</li>
              <li><b>Replies go to:</b> {env.mail.support}</li>
            </ul>
            <p className="mt-3 text-xs text-muted-foreground">Limits that protect your 300-a-day Brevo plan: one code per email per minute, 5 per email per hour, 20 per network per hour, 280 per day in total.</p>
          </Panel>
          <Panel title="Active senders">
            <ul className="space-y-1.5 text-sm">{status.senders.map((s) => <li key={s.email} className="flex items-center justify-between">{s.email}{s.active ? <Pill tone="ok">Active</Pill> : <Pill tone="warn">Inactive</Pill>}</li>)}</ul>
          </Panel>
        </div>
        <Panel title="Templates (preview)">
          <div className="space-y-4">{templates.map(([label, t]) => <Preview key={label} label={label} subject={t.subject} html={t.html} />)}</div>
        </Panel>
      </div>
    </>
  );
}
