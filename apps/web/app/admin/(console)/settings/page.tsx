import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { hasBrevo, hasR2 } from "@/lib/env";
import { ErrorState, PageHeader, PageSkeleton, Panel, Pill } from "@/components/admin/ui";
import { AppSwitch, FlagRow, GoogleClientId, SettingsForm } from "./forms";
import { readJson } from "@/lib/r2";
import type { ApkInfo } from "@/app/download/apk/route";

export const metadata: Metadata = { title: "Flags & settings" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Settings /></Suspense>;
}

async function Settings() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [flags, settings] = await Promise.all([
    supabase.from("feature_flags").select("key, enabled, description, updated_at").order("key"),
    supabase.from("app_settings").select("key, value"),
  ]);
  if (flags.error || settings.error) return <ErrorState message={(flags.error ?? settings.error)!.message} />;
  const v = Object.fromEntries((settings.data ?? []).map((r) => [r.key, r.value])) as Record<string, Record<string, unknown> | string>;
  const sw = (k: string, f: string, def: boolean) => { const o = v[k]; return o && typeof o === "object" && f in o ? o[f] === true : def; };
  const apk = hasR2() ? await readJson<ApkInfo>("apk/latest.json").catch(() => null) : null;
  return (
    <>
      <PageHeader title="Flags & settings" description="Turn features on or off and change app settings without an app update. Every change is logged." />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
        <Panel title="Feature flags" bodyClassName="divide-y py-1">
          {flags.data!.map((f) => <FlagRow key={f.key} k={f.key} enabled={f.enabled} description={f.description ?? ""} />)}
        </Panel>
        <div className="space-y-4">
          <Panel title="Screenshots and screen recording" bodyClassName="divide-y py-1">
            <AppSwitch k="screen_protection" field="whole_app" on={sw("screen_protection", "whole_app", false)} title="Block in the whole app"
              text="Off: students (and you) can take screenshots and screen recordings anywhere except the screens below." />
            <AppSwitch k="screen_protection" field="exams" on={sw("screen_protection", "exams", true)} title="Block in tests, challenges and Premium videos"
              text="CBT tests, challenges, challenge answer reviews and Premium videos. Recommended on, so questions are not shared." />
          </Panel>
          <Panel title="Sign in with Google" bodyClassName="divide-y py-1">
            <AppSwitch k="google_auth" field="enabled" on={sw("google_auth", "enabled", false)} title="Show “Continue with Google”"
              text="On: students can create an account and log in with their Google account on the sign-up and log-in screens. Turn on only after the Google setup in SETUP §17 is done." />
            <GoogleClientId value={String((v.google_auth as Record<string, unknown> | undefined)?.web_client_id ?? "")} />
          </Panel>
          <Panel title="App updates (direct app)" bodyClassName="divide-y py-1">
            <AppSwitch k="app_update" field="force" on={sw("app_update", "force", true)} title="Students must update to the newest app"
              text="On: when a newer app is built, the app shows “Update needed” and installs it from inside the app. Off: it only offers the update." />
            <p className="py-3 text-xs text-muted-foreground">Newest app: {apk ? <b className="font-mono">{apk.version}</b> : "not known"}. It is built and published automatically after every app change.</p>
          </Panel>
          <Panel title="Connections">
            <ul className="space-y-2.5 text-sm">
              <li className="flex items-center justify-between">Database (Supabase)<Pill tone="ok">Connected</Pill></li>
              <li className="flex items-center justify-between">Image storage (Cloudflare R2){hasR2() ? <Pill tone="ok">Set up</Pill> : <Pill tone="error">Not set up</Pill>}</li>
              <li className="flex items-center justify-between">Email API (Brevo){hasBrevo() ? <Pill tone="ok">Set up</Pill> : <Pill tone="warn">Not set up</Pill>}</li>
            </ul>
            <p className="mt-3 text-xs text-muted-foreground">Login codes for students are sent by Supabase through Brevo SMTP (set in the Supabase dashboard, see SETUP §7.4).</p>
          </Panel>
        </div>
      </div>
      <div className="mt-4">
        <SettingsForm values={v} />
      </div>
    </>
  );
}
