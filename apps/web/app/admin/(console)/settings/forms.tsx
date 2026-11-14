"use client";
import { useOptimistic, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Switch } from "@/components/ui/switch";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Panel } from "@/components/admin/ui";
import { saveSettings, setAppSwitch, setFlag, setGoogleClientId } from "./actions";

const LABELS: Record<string, string> = {
  challenges_enabled: "Challenges & events", referrals_enabled: "Referral programme", ai_photo_questions: "AI photo questions",
  paystack_in_play_build: "Paystack in the Play Store app", paid_events_in_play_build: "Paid entry in the Play Store app",
  cash_challenges_on_web: "Cash challenges in the web app", leaderboard_enabled: "Leaderboards",
};

export function FlagRow({ k, enabled, description }: { k: string; enabled: boolean; description: string }) {
  const router = useRouter();
  const [, start] = useTransition();
  const [on, setOn] = useOptimistic(enabled);
  return (
    <label className="flex cursor-pointer items-center gap-4 py-3.5">
      <span className="grow">
        <b className="block text-sm">{LABELS[k] ?? k}</b>
        <small className="block text-[13px] text-muted-foreground">{description}</small>
        <code className="mt-1.5 inline-block rounded-md bg-muted px-1.5 py-0.5 font-mono text-xs text-muted-foreground">{k}</code>
      </span>
      <Switch checked={on} aria-label={LABELS[k] ?? k}
        onCheckedChange={(v) => start(async () => {
          setOn(v);
          const r = await setFlag(k, v);
          if (r.ok) { toast.success(`${LABELS[k] ?? k} turned ${v ? "on" : "off"}.`); router.refresh(); } else toast.error(r.error);
        })} />
    </label>
  );
}

type V = Record<string, Record<string, unknown> | string>;
const get = (v: V, k: string, f: string) => String((v[k] as Record<string, unknown> | undefined)?.[f] ?? "");
/** A stored time → the "yyyy-mm-ddThh:mm" a datetime-local field wants, in Lagos time (UTC+1). */
const lagos = (iso: string) => { const t = Date.parse(iso); return Number.isFinite(t) ? new Date(t + 3600e3).toISOString().slice(0, 16) : ""; };

export function SettingsForm({ values: v, builds = {} }: { values: V; builds?: { play?: number | null; direct?: number | null } }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const input = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
  const field = (name: string, label: string, def: string, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="space-y-1.5"><Label htmlFor={name}>{label}</Label><input id={name} name={name} defaultValue={def} className={input} {...props} /></div>
  );
  return (
    <form action={(f) => start(async () => { const r = await saveSettings(f); if (r.ok) { toast.success("Settings saved."); router.refresh(); } else toast.error(r.error); })}
      className="grid items-start gap-4 lg:grid-cols-2">
      <Panel title="Maintenance mode">
        <div className="space-y-4">
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Maintenance mode</b><br /><span className="text-muted-foreground">Every app shows a “We are making SolutionTee better” screen with your message. It opens again by itself when you switch this off (within a minute).</span></span>
            <Switch name="maintenance" defaultChecked={get(v, "maintenance", "enabled") === "true"} /></label>
          {field("maintenance_message", "Message students see", get(v, "maintenance", "message"))}
          {field("maintenance_until", "Back by (Lagos time, optional)", lagos(get(v, "maintenance", "until")), { type: "datetime-local" })}
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Staff can still use the app</b><br /><span className="text-muted-foreground">So you and your team can test while students wait. Tutors are not included.</span></span>
            <Switch name="maintenance_staff" defaultChecked={get(v, "maintenance", "staff_bypass") !== "false"} /></label>
        </div>
      </Panel>
      <Panel title="App updates (Play Store app and every app)">
        <div className="space-y-4">
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Show the update pop-up</b><br /><span className="text-muted-foreground">When Google Play has a newer version, students see a pop-up that opens the Play Store. “Later” hides it for a day.</span></span>
            <Switch name="play_prompt" defaultChecked={get(v, "play_update", "prompt") !== "false"} /></label>
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Students must update (Play Store app)</b><br /><span className="text-muted-foreground">When Google Play has a newer version, the app is blocked until they update. Turn on only after the new version is live on Play.</span></span>
            <Switch name="play_force" defaultChecked={get(v, "play_update", "force") === "true"} /></label>
          <div className="space-y-1.5"><Label htmlFor="play_notes">What&apos;s new (optional, one point per line)</Label>
            <textarea id="play_notes" name="play_notes" rows={3} defaultValue={get(v, "play_update", "notes")} placeholder={"New Game Zone games\nFaster question bank"} className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" /></div>
          {field("min_build", "Minimum build (every app, 0 = off)", get(v, "min_build", "build") || "0", { type: "number", min: 0, inputMode: "numeric", className: `${input} font-mono` })}
          <p className="text-xs text-muted-foreground">Any app (Play Store or website) with a lower build number must update before it opens. Newest builds: Play Store {builds.play ? <b className="font-mono">{builds.play}</b> : "not known"} · website app {builds.direct ? <b className="font-mono">{builds.direct}</b> : "not known"}. Use the Play number only after that version is live on Google Play.</p>
        </div>
      </Panel>
      <Panel title="Support and company">
        <div className="grid gap-4 sm:grid-cols-2">
          {field("whatsapp", "WhatsApp support", get(v, "support", "whatsapp"), { inputMode: "tel" })}
          {field("support_email", "Support email", get(v, "support", "email"), { type: "email", placeholder: "Not set yet" })}
          {field("company_name", "Company", get(v, "company", "name"))}
          {field("rc_number", "Registered business", get(v, "company", "rc_number"))}
          <div className="sm:col-span-2">{field("address", "Address", get(v, "company", "address"))}</div>
          {field("website", "Website", get(v, "company", "website"))}
          {field("web_app", "Student web app", get(v, "company", "web_app"))}
          <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="disclaimer">Disclaimer (onboarding, About, Terms, store)</Label>
            <textarea id="disclaimer" name="disclaimer" rows={3} defaultValue={typeof v.disclaimer === "string" ? v.disclaimer : ""} className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" /></div>
        </div>
      </Panel>
      <div className="flex justify-end lg:col-span-2"><Button type="submit" disabled={pending} className="h-11 px-6">Save settings</Button></div>
    </form>
  );
}

/** An instant switch for one field of a JSON setting (screen protection, in-app updates). */
export function AppSwitch({ k, field, on: initial, title, text }: { k: string; field: string; on: boolean; title: string; text: string }) {
  const router = useRouter();
  const [, start] = useTransition();
  const [on, setOn] = useOptimistic(initial);
  return (
    <label className="flex cursor-pointer items-center gap-4 py-3.5">
      <span className="grow"><b className="block text-sm">{title}</b><small className="block text-[13px] text-muted-foreground">{text}</small></span>
      <Switch checked={on} aria-label={title} onCheckedChange={(v) => start(async () => {
        setOn(v);
        const r = await setAppSwitch(k, field, v);
        if (r.ok) { toast.success(`${title}: ${v ? "on" : "off"}. Phones get it the next time the app opens.`); router.refresh(); } else toast.error(r.error);
      })} />
    </label>
  );
}

/** The Google Web client ID field (Continue with Google). */
export function GoogleClientId({ value }: { value: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [v, setV] = useState(value);
  return (
    <div className="py-3.5">
      <label htmlFor="gcid" className="block text-sm font-bold">Google Web client ID</label>
      <small className="block text-[13px] text-muted-foreground">From Google Cloud → APIs &amp; Services → Credentials → the <b>Web application</b> client. Not a secret. Its secret goes only in Supabase → Authentication → Sign In / Providers → Google.</small>
      <div className="mt-2 flex gap-2">
        <input id="gcid" className="h-9 min-w-0 flex-1 rounded-md border bg-background px-3 font-mono text-xs" value={v} onChange={(e) => setV(e.target.value)} placeholder="1234567890-abc….apps.googleusercontent.com" />
        <Button size="sm" disabled={pending || v === value} onClick={() => start(async () => {
          const r = await setGoogleClientId(v);
          if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
        })}>Save</Button>
      </div>
    </div>
  );
}
