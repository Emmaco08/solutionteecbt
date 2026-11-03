import { Suspense } from "react";
import type { Metadata } from "next";
import { ShieldCheck } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { HeldList, SettingsForm, type Held, type LbSettings } from "./lb-ui";

export const metadata: Metadata = { title: "Leaderboard" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Leaderboard /></Suspense>;
}

/** The JAMB season now: from 1 July, practice counts for next year's UTME (same rule as the server). */
function seasonNow() {
  const d = new Date(Date.now() + 3600_000);
  return d.getUTCFullYear() + (d.getUTCMonth() >= 6 ? 1 : 0);
}

async function Leaderboard() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [set, held, flag] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle(),
    supabase.rpc("admin_leaderboard_held", {}),
    supabase.from("feature_flags").select("enabled").eq("key", "leaderboard_enabled").maybeSingle(),
  ]);
  if (held.error) return <ErrorState message={held.error.message} />;
  const now = seasonNow();
  const value = (set.data?.value ?? {}) as Partial<LbSettings>;
  const settings: LbSettings = { on: value.on ?? false, past_seasons: value.past_seasons ?? [], min_mocks: value.min_mocks ?? 1, names: value.names ?? "first-initial" };
  const rows = (held.data ?? []) as unknown as Held[];
  return (
    <>
      <PageHeader title="Leaderboard" description={`Best full JAMB mock (out of 400) per student for each JAMB year. A tie goes to the faster time, then to who finished first. This season is JAMB ${now} (from 1 July practice counts for the next year).`} />
      <div className="grid gap-4 xl:grid-cols-[1fr_1.2fr]">
        <Panel title="Settings">
          {flag.data && !flag.data.enabled ? <p className="mb-3 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">The “Leaderboard” switch in Settings → Feature flags is off, so students see nothing even if this is on.</p> : null}
          <SettingsForm settings={settings} seasonNow={now} />
        </Panel>
        <Panel title={`Held for review (JAMB ${now})`} bodyClassName="p-0">
          {rows.length ? <HeldList rows={rows} /> : (
            <EmptyState icon={<ShieldCheck />} title="Nothing held">Mocks finished very fast, or near-perfect very fast, wait here until you decide. Until then they do not count.</EmptyState>
          )}
        </Panel>
      </div>
    </>
  );
}
