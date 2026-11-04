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

export function SettingsForm({ values: v }: { values: V }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const input = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
  const field = (name: string, label: string, def: string, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="space-y-1.5"><Label htmlFor={name}>{label}</Label><input id={name} name={name} defaultValue={def} className={input} {...props} /></div>
  );
  return (
    <form action={(f) => start(async () => { const r = await saveSettings(f); if (r.ok) { toast.success("Settings saved."); router.refresh(); } else toast.error(r.error); })}
      className="grid items-start gap-4 lg:grid-cols-2">
      <Panel title="App version and maintenance">
        <div className="space-y-4">
          {field("min_android", "Minimum Android app version", get(v, "min_app_version", "android") || "1.0.0", { className: `${input} font-mono` })}
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Force update</b><br /><span className="text-muted-foreground">Older versions must update before they can continue.</span></span>
            <Switch name="force_update" defaultChecked={get(v, "min_app_version", "force") === "true"} /></label>
          <label className="flex items-center justify-between gap-3 text-sm"><span><b>Maintenance mode</b><br /><span className="text-muted-foreground">Students see your message. Downloaded tests still work offline.</span></span>
            <Switch name="maintenance" defaultChecked={get(v, "maintenance", "enabled") === "true"} /></label>
          {field("maintenance_message", "Maintenance message", get(v, "maintenance", "message"))}
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
