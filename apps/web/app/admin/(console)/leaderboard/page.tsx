import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { RecentList, SettingsForm, type LbSettings, type Recent } from "./lb-ui";
import { normalise, RewardsForm, WinnersList, type LbRewards, type Winner } from "./rewards-ui";
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
  const [set, recent, flag, winners] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle(),
    supabase.rpc("admin_leaderboard_recent", { p_limit: 40 }),
    supabase.from("feature_flags").select("enabled").eq("key", "leaderboard_enabled").maybeSingle(),
    supabase.from("lb_winners").select("board, period, label, rank, score, xp_given, days_given, profiles(full_name)").order("period_start", { ascending: false }).order("board").order("rank").limit(40),
  ]);
  const won = (winners.data ?? []).map((w) => ({ ...w, name: (w.profiles as { full_name?: string } | null)?.full_name ?? "Student" })) as unknown as Winner[];
  if (recent.error) return <ErrorState message={recent.error.message} />;
  const now = seasonNow();
  const v = (set.data?.value ?? {}) as Partial<LbSettings>;
  const settings: LbSettings = {
    on: v.on ?? false, past_seasons: v.past_seasons ?? [], min_mocks: v.min_mocks ?? 1, names: v.names ?? "first-initial",
    min_questions: v.min_questions ?? 100, fast_minutes: v.fast_minutes ?? 15, include_staff: v.include_staff ?? false,
    exams: { JAMB: v.exams?.JAMB ?? true, WAEC: v.exams?.WAEC ?? true, NECO: v.exams?.NECO ?? true },
    subject_min_questions: v.subject_min_questions ?? 40, subject_fast_minutes: v.subject_fast_minutes ?? 5,
    fair_hold: v.fair_hold ?? 50,
  };
  const rows = (recent.data ?? []) as unknown as Recent[];
  return (
    <>
      <PageHeader title="Leaderboard" description={`Ranks students by their best test this week, month, year, all time or season (season ${now}): JAMB by the full mock, WAEC and NECO by subject, and a Challenges board by challenge points.`} />
      <Panel title="How a student gets on the board" className="mb-4">
        <ol className="list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
          <li><b className="text-foreground">JAMB board:</b> in the app, Test → <b className="text-foreground">Start full exam</b> (English + 3 subjects, out of 400). It needs at least {settings.min_questions} questions and must not be finished in under {settings.fast_minutes || "—"} minutes.</li>
          <li><b className="text-foreground">WAEC and NECO boards:</b> one board per subject. In the app, Test → WAEC (or NECO) → a subject paper (out of 100). It needs at least {settings.subject_min_questions} questions and must not be finished in under {settings.subject_fast_minutes || "—"} minutes.</li>
          <li>Quick tests and topic drills never count. The student needs at least <b className="text-foreground">{settings.min_mocks} counting test{settings.min_mocks === 1 ? "" : "s"}</b>; their best one counts, and a tie goes to the faster time. Held tests count only after you tap “Let it count”.</li>
          <li>Staff accounts, banned students and students who hid themselves are left out.</li>
        </ol>
        <p className="mt-3 rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft"><b>Testing with the sample questions?</b> The sample bank is small (20 questions in a JAMB mock, 5 in a WAEC paper). Set the questions needed to 20 (JAMB) and 5 (WAEC/NECO), both “Too fast” to 0, and tick “Include staff accounts”, then save. Before launch: JAMB 180 / 15, WAEC/NECO 50 / 5, staff off.</p>
      </Panel>
      <div className="grid gap-4 xl:grid-cols-[1fr_1.3fr]">
        <Panel title="Settings">
          {flag.data && !flag.data.enabled ? <p className="mb-3 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">The “Leaderboard” switch in Settings → Feature flags is off, so students see nothing even if this is on.</p> : null}
          <SettingsForm settings={settings} seasonNow={now} />
        </Panel>
        <Panel title="Latest tests that can count" bodyClassName="p-0">
          {rows.length ? <RecentList rows={rows} /> : (
            <EmptyState icon={<Exam />} title="Nothing yet">Full JAMB mocks and WAEC/NECO subject papers show here, with whether each counts and why.</EmptyState>
          )}
        </Panel>
      </div>
      <div className="mt-4 grid gap-4 xl:grid-cols-[1.3fr_1fr]">
        <Panel title="Weekly and monthly top-10 rewards">
          <RewardsForm initial={normalise((v as { rewards?: Partial<LbRewards> }).rewards)} />
        </Panel>
        <Panel title="Rewards paid">
          <WinnersList rows={won} />
        </Panel>
      </div>
    </>
  );
}
