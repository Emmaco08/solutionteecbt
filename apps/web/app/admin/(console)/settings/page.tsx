import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { hasBrevo, hasR2 } from "@/lib/env";
import { ErrorState, PageHeader, PageSkeleton, Panel, Pill } from "@/components/admin/ui";
import { FlagRow, SettingsForm } from "./forms";

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
  return (
    <>
      <PageHeader title="Flags & settings" description="Turn features on or off and change app settings without an app update. Every change is logged." />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
        <Panel title="Feature flags" bodyClassName="divide-y py-1">
          {flags.data!.map((f) => <FlagRow key={f.key} k={f.key} enabled={f.enabled} description={f.description ?? ""} />)}
        </Panel>
        <div className="space-y-4">
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
