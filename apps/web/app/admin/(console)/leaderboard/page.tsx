import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { RecentList, SettingsForm, type LbSettings, type Recent } from "./lb-ui";
import { RewardsForm, WinnersList } from "./rewards-ui";
import { normalise, type LbRewards, type Winner } from "./lb-shared";
import { Exam, Ranking, Trophy } from "@phosphor-icons/react/dist/ssr";
import { Stat } from "@/components/admin/charts";
import { Pill } from "@/components/admin/ui";

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
  const [set, recent, flag, winners, jWeek, jMonth, cWeek, bodies] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle(),
    supabase.rpc("admin_leaderboard_recent", { p_limit: 40 }),
    supabase.from("feature_flags").select("enabled").eq("key", "leaderboard_enabled").maybeSingle(),
    supabase.from("lb_winners").select("board, period, label, rank, score, xp_given, days_given, profiles(full_name)").order("period_start", { ascending: false }).order("board").order("rank").limit(40),
    supabase.rpc("leaderboard_for", { p_exam: "JAMB", p_scope: "national", p_period: "week", p_offset: 0 }),
    supabase.rpc("leaderboard_for", { p_exam: "JAMB", p_scope: "national", p_period: "month", p_offset: 0 }),
    supabase.rpc("leaderboard_challenges", { p_period: "week", p_offset: 0 }),
    supabase.from("exam_bodies").select("id, code, is_active, exam_configs(score_scale)").eq("is_active", true).order("id"),
  ]);
  const won = (winners.data ?? []).map((w) => ({ ...w, name: (w.profiles as { full_name?: string } | null)?.full_name ?? "Student" })) as unknown as Winner[];
  if (recent.error) return <ErrorState message={recent.error.message} />;
  const now = seasonNow();
  const v = (set.data?.value ?? {}) as Partial<LbSettings>;
  const settings: LbSettings = {
    on: v.on ?? false, past_seasons: v.past_seasons ?? [], min_mocks: v.min_mocks ?? 1, names: v.names ?? "first-initial",
    min_questions: v.min_questions ?? 100, fast_minutes: v.fast_minutes ?? 15, include_staff: v.include_staff ?? false,
    exams: v.exams ?? {},
    subject_min_questions: v.subject_min_questions ?? 40, subject_fast_minutes: v.subject_fast_minutes ?? 5,
    fair_hold: v.fair_hold ?? 50,
  };
  const order = ["JAMB", "WAEC", "NECO"];
  const examList = (bodies.data ?? [])
    .map((b) => {
      const cfg = b.exam_configs as unknown as { score_scale?: number } | { score_scale?: number }[] | null;
      const scale = (Array.isArray(cfg) ? cfg[0]?.score_scale : cfg?.score_scale) ?? 100;
      return { code: b.code as string, scale, rank: order.includes(b.code as string) ? order.indexOf(b.code as string) : 10 + b.id };
    })
    .sort((a, b) => a.rank - b.rank);
  const rows = (recent.data ?? []) as unknown as Recent[];
  const counting = rows.filter((r) => !r.reason && !r.held).length;
  const held = rows.filter((r) => r.held).length;
  const live = settings.on && (!flag.data || flag.data.enabled);
  return (
    <>
      <PageHeader title="Leaderboard" description={`Ranks students by their best test this week, month, year, all time or season (season ${now}): JAMB by the full mock, WAEC, NECO and your own exams by subject, and a Challenges board by challenge points.`}
        actions={live ? <Pill tone="ok">Live in the app</Pill> : <Pill tone="warn">Hidden from students</Pill>} />
      {!live ? (
        <p className="mb-4 rounded-2xl bg-warning-soft px-4 py-3 text-sm text-on-warning-soft">
          Students do not see the leaderboard now: {!settings.on ? "it is switched off in Settings below" : "the “Leaderboard” switch in Flags & settings is off"}.
        </p>
      ) : null}
      <div className="mb-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="Recent tests that count" value={counting} sub={`of the last ${rows.length}`} />
        <Stat label="Held for your review" value={held} sub={held ? "Let them count or keep them off below" : "Nothing waiting"} />
        <Stat label="Rewards paid" value={won.length} sub="Top-10 weekly and monthly" />
        <Stat label="Season" value={now} sub="JAMB season (from 1 July)" />
      </div>

      <div className="mb-4 grid gap-4 lg:grid-cols-3">
        <Board title="JAMB · this week" data={jWeek.data} unit="/ 400" />
        <Board title="JAMB · this month" data={jMonth.data} unit="/ 400" />
        <Board title="Challenges · this week" data={cWeek.data} unit="points" />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_1.3fr]">
        <Panel title="Settings">
          <SettingsForm settings={settings} seasonNow={now} exams={examList} />
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

      <details className="mt-4 rounded-2xl border bg-card p-5">
        <summary className="cursor-pointer text-sm font-bold">How a student gets on the board</summary>
        <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
          <li><b className="text-foreground">JAMB board:</b> in the app, Test → <b className="text-foreground">Start full exam</b> (English + 3 subjects, out of 400). It needs at least {settings.min_questions} questions and must not be finished in under {settings.fast_minutes || "—"} minutes.</li>
          <li><b className="text-foreground">WAEC and NECO boards:</b> one board per subject. In the app, Test → WAEC (or NECO) → a subject paper (out of 100). It needs at least {settings.subject_min_questions} questions and must not be finished in under {settings.subject_fast_minutes || "—"} minutes.</li>
          <li>Quick tests and topic drills never count. The student needs at least <b className="text-foreground">{settings.min_mocks} counting test{settings.min_mocks === 1 ? "" : "s"}</b>; their best one counts, and a tie goes to the faster time. Held tests count only after you tap “Let it count”.</li>
          <li>Staff accounts, banned students and students who hid themselves are left out.</li>
        </ol>
        <p className="mt-3 rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft"><b>Testing with the sample questions?</b> The sample bank is small (20 questions in a JAMB mock, 5 in a WAEC paper). Set the questions needed to 20 (JAMB) and 5 (WAEC/NECO), both “Too fast” to 0, and tick “Include staff accounts”, then save. Before launch: JAMB 180 / 15, WAEC/NECO 50 / 5, staff off.</p>
      </details>
    </>
  );
}

type Top = { rank: number; name: string; state: string | null; score: number; played?: number; mocks?: number };
/** The top 10 exactly as students see it in the app (names shortened the same way). */
function Board({ title, data, unit }: { title: string; data: unknown; unit: string }) {
  const b = (data ?? {}) as { top?: Top[]; label?: string };
  const top = (b.top ?? []).slice(0, 10);
  return (
    <Panel title={title} actions={b.label ? <span className="text-xs text-muted-foreground">{b.label}</span> : null} bodyClassName="p-0">
      {top.length ? (
        <ol className="divide-y">
          {top.map((t) => (
            <li key={t.rank + t.name} className="flex items-center gap-3 px-4 py-2.5 text-sm">
              <span className={`grid size-7 flex-none place-items-center rounded-full text-xs font-black ${t.rank === 1 ? "bg-gold-soft text-on-gold-soft" : t.rank <= 3 ? "bg-info-soft text-on-info-soft" : "bg-sunken text-muted-foreground"}`}>{t.rank}</span>
              <span className="min-w-0 grow"><b className="block truncate">{t.name}</b><span className="text-xs text-muted-foreground">{t.state ?? "—"}</span></span>
              <span className="whitespace-nowrap font-bold tabular-nums">{t.score} <span className="text-xs font-normal text-muted-foreground">{unit}</span></span>
            </li>
          ))}
        </ol>
      ) : (
        <EmptyState icon={title.startsWith("Challenges") ? <Trophy /> : <Ranking />} title="No one yet">Students appear here after a counting test.</EmptyState>
      )}
    </Panel>
  );
}
