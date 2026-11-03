import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { RecentList, SettingsForm, type LbSettings, type Recent } from "./lb-ui";
import { Exam } from "@phosphor-icons/react/dist/ssr";

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
  const [set, recent, flag] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle(),
    supabase.rpc("admin_leaderboard_recent", { p_limit: 40 }),
    supabase.from("feature_flags").select("enabled").eq("key", "leaderboard_enabled").maybeSingle(),
  ]);
  if (recent.error) return <ErrorState message={recent.error.message} />;
  const now = seasonNow();
  const v = (set.data?.value ?? {}) as Partial<LbSettings>;
  const settings: LbSettings = {
    on: v.on ?? false, past_seasons: v.past_seasons ?? [], min_mocks: v.min_mocks ?? 1, names: v.names ?? "first-initial",
    min_questions: v.min_questions ?? 100, fast_minutes: v.fast_minutes ?? 15, include_staff: v.include_staff ?? false,
  };
  const rows = (recent.data ?? []) as unknown as Recent[];
  return (
    <>
      <PageHeader title="Leaderboard" description={`Ranks students by their best full JAMB mock this season (JAMB ${now}).`} />
      <Panel title="How a student gets on the board" className="mb-4">
        <ol className="list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
          <li>In the app: <b className="text-foreground">Test → Start full exam</b> (the full JAMB simulation: English + 3 subjects, out of 400). Other tests (single subject, quick test, WAEC, NECO) do not count.</li>
          <li>The mock must have at least <b className="text-foreground">{settings.min_questions} questions</b> and must not be finished too fast (under {settings.fast_minutes || "—"} minutes), unless you let it count below.</li>
          <li>The student needs at least <b className="text-foreground">{settings.min_mocks} full mock{settings.min_mocks === 1 ? "" : "s"}</b> this season. Their best one counts; a tie goes to the faster time.</li>
          <li>Staff accounts, banned students and students who hid themselves are left out.</li>
        </ol>
        <p className="mt-3 rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft"><b>Testing with the sample questions?</b> The sample bank has only 20 questions in a full mock. Set “Questions needed” to 20, “Too fast” to 0 and tick “Include staff accounts”, then save. Put them back before launch (180 / 15 / off).</p>
      </Panel>
      <div className="grid gap-4 xl:grid-cols-[1fr_1.3fr]">
        <Panel title="Settings">
          {flag.data && !flag.data.enabled ? <p className="mb-3 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">The “Leaderboard” switch in Settings → Feature flags is off, so students see nothing even if this is on.</p> : null}
          <SettingsForm settings={settings} seasonNow={now} />
        </Panel>
        <Panel title="Latest full JAMB mocks" bodyClassName="p-0">
          {rows.length ? <RecentList rows={rows} /> : (
            <EmptyState icon={<Exam />} title="No full JAMB mocks yet">When students finish Test → Start full exam, each mock shows here with whether it counts and why.</EmptyState>
          )}
        </Panel>
      </div>
    </>
  );
}
