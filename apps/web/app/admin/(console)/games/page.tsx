import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { ArenaList, GamesSettingsForm, type AdminArena, type GamesSettings } from "./games-ui";

export const metadata: Metadata = { title: "Games" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Games /></Suspense>;
}

/** Arenas from the last 14 days and later. */
function since() {
  return new Date(new Date().getTime() - 14 * 86400000).toISOString();
}

async function Games() {
  const staff = await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [arenas, players, settings, stats, cat] = await Promise.all([
    supabase.from("arenas").select("id, title, exam_id, subject_id, starts_at, q_count, seconds, gap, max_players, status, rewarded_at").gte("starts_at", since()).order("starts_at"),
    supabase.from("arena_players").select("arena_id"),
    supabase.from("app_settings").select("value").eq("key", "games").maybeSingle(),
    supabase.rpc("admin_games_stats"),
    getCatalogue(),
  ]);
  if (arenas.error) return <ErrorState message={arenas.error.message} />;
  const count = new Map<string, number>();
  for (const p of players.data ?? []) count.set(p.arena_id, (count.get(p.arena_id) ?? 0) + 1);
  const s = (settings.data?.value ?? {}) as Partial<GamesSettings>;
  const st = (stats.data ?? {}) as { today?: number; week?: number; players_week?: number; xp_week?: number; by_mode?: Record<string, number> };
  const isAdmin = staff.role === "super_admin" || staff.role === "admin";
  const tile = (label: string, value: number | string) => (
    <div className="rounded-2xl border bg-card p-4"><p className="text-xs text-muted-foreground">{label}</p><p className="text-2xl font-bold tabular-nums">{value}</p></div>
  );
  return (
    <>
      <PageHeader title="Games" description="Study → Games in the app: Speed Quiz Duel (against the SolutionTee bot or a friend with a 6-letter code), Beat the AI Tutor, and Live Exam Arenas you schedule here. Answers are checked on the server; games with other people only use years open on the free plan." />
      <div className="mb-4 grid grid-cols-2 gap-3 md:grid-cols-4">
        {tile("Games today", st.today ?? 0)}{tile("Games in 7 days", st.week ?? 0)}{tile("Players in 7 days", st.players_week ?? 0)}{tile("XP from games, 7 days", (st.xp_week ?? 0).toLocaleString("en-NG"))}
      </div>
      <ArenaList arenas={(arenas.data ?? []).map((a) => ({ ...a, players: count.get(a.id) ?? 0 })) as AdminArena[]}
        subjects={cat.subjects} exams={cat.exams.map((e) => ({ id: e.id, code: e.code }))} />
      {isAdmin ? (
        <Panel title="Settings and XP" className="mt-4">
          <GamesSettingsForm initial={{
            on: s.on !== false, questions: s.questions ?? 10, seconds: s.seconds ?? 15, daily_games: s.daily_games ?? 40, daily_xp: s.daily_xp ?? 100,
            arena_min_players: s.arena_min_players ?? 5,
            xp: { play: s.xp?.play ?? 5, win: s.xp?.win ?? 15, beat_ai: s.xp?.beat_ai ?? 25, arena_play: s.xp?.arena_play ?? 5, arena_top: s.xp?.arena_top ?? [30, 20, 10] },
          }} />
        </Panel>
      ) : null}
    </>
  );
}
