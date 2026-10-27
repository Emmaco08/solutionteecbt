import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { env, hasBrevo } from "@/lib/env";
import { PageHeader, PageSkeleton, Panel, Pill } from "@/components/admin/ui";
import { signupCodeEmail, resetCodeEmail, passwordChangedEmail, welcomeEmail, inviteEmail } from "@/lib/email-templates";
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
  const [status, sent] = await Promise.all([brevoStatus(), supabase.rpc("email_sent_last_24h")]);
  const used = Number(sent.data ?? 0);
  const templates = [
    ["Sign-up code", signupCodeEmail("Tolu Adeyemi", "48213907")],
    ["Password reset code", resetCodeEmail("70315264")],
    ["Password changed", passwordChangedEmail("27 Oct 2026, 14:30 (Lagos time)")],
    ["Welcome", welcomeEmail("Tolu Adeyemi")],
    ["Staff invite", inviteEmail("https://solutiontee.com/admin/accept?token_hash=example", "Editor", "Ada Okoye")],
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
