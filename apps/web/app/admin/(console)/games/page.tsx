import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { ArenaList, GamesSettingsForm, type AdminArena, type GamesSettings } from "./games-ui";
import { GzCards, GzSettingsForm, GzWords, type GzCard, type GzWord } from "./gamezone-ui";
import { GZ_GAMES } from "./gamezone-shared";
import { GzQuestions, GzSourceForm } from "./gz-questions-ui";
import { GzAdminTabs, GzCardsCsv, GzGuide, GzPassages, GzPassagesCsv, GzReadingForm, GzWordsCsv } from "./gz-content-ui";

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
  const [arenas, players, settings, stats, cat, gzStats, words, cards, gzCounts] = await Promise.all([
    supabase.from("arenas").select("id, title, exam_id, subject_id, starts_at, q_count, seconds, gap, max_players, status, rewarded_at").gte("starts_at", since()).order("starts_at"),
    supabase.from("arena_players").select("arena_id"),
    supabase.from("app_settings").select("value").eq("key", "games").maybeSingle(),
    supabase.rpc("admin_games_stats"),
    getCatalogue(),
    supabase.rpc("admin_gz_stats"),
    supabase.from("gz_words").select("id, kind, word, answer, wrong, active").order("active").order("id"),
    supabase.from("gz_cards").select("id, subject_id, front, back, active").order("active").order("subject_id").order("id"),
    supabase.rpc("admin_gz_question_counts"),
  ]);
  if (arenas.error) return <ErrorState message={arenas.error.message} />;
  const count = new Map<string, number>();
  for (const p of players.data ?? []) count.set(p.arena_id, (count.get(p.arena_id) ?? 0) + 1);
  const s = (settings.data?.value ?? {}) as Partial<GamesSettings>;
  const st = (stats.data ?? {}) as { today?: number; week?: number; players_week?: number; xp_week?: number; by_mode?: Record<string, number> };
  const isAdmin = staff.role === "super_admin" || staff.role === "admin";
  const gs = (gzStats.data ?? {}) as { today?: number; playing?: number; students_today?: number; week?: number; vs_students_week?: number; xp_week?: number; by_game?: Record<string, number> };
  const gz = ((s as Record<string, unknown>).gz ?? {}) as Record<string, unknown> & { games?: Record<string, Record<string, unknown>> };
  const num = (v: unknown, d: number) => (typeof v === "number" ? v : d);
  const str = (v: unknown) => (typeof v === "number" ? String(v) : "");
  const subjectList = cat.subjects.map((x) => ({ id: x.id, name: x.name }));
  const src = (v: unknown): "jamb" | "own" | "both" | null => (v === "jamb" || v === "own" || v === "both" ? v : null);
  const tile = (label: string, value: number | string) => (
    <div className="rounded-2xl border bg-card p-4"><p className="text-xs text-muted-foreground">{label}</p><p className="text-2xl font-bold tabular-nums">{value}</p></div>
  );
  const wpm = num(gz.games?.reading?.wpm, 240);
  const QUESTION_GAMES = "These SolutionTee questions are shared by JAMB Duel, Speed Rush, Knowledge Survival and Team Relay. Where they come from (JAMB, ours or both) is set in Overview.";
  const gameStat = (id: string) => (
    <p className="text-xs text-muted-foreground">Matches in the last 7 days: <b>{(gs.by_game?.[id] ?? 0).toLocaleString("en-NG")}</b>. On/off, XP, seconds and rounds for this game are in Overview → settings.</p>
  );
  const questions = (id: "duel" | "rush" | "survival" | "relay") => (
    <>
      <GzGuide game={id} shared={QUESTION_GAMES} />
      {gameStat(id)}
      <GzQuestions subjects={subjectList} />
    </>
  );
  const overview = (
    <>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        {tile("Game Zone matches today", gs.today ?? 0)}{tile("Playing now", gs.playing ?? 0)}{tile("Students today", gs.students_today ?? 0)}
        {tile("Matches in 7 days", gs.week ?? 0)}{tile("Student vs student, 7 days", gs.vs_students_week ?? 0)}
      </div>
      <p className="text-xs text-muted-foreground">Last 7 days by game: {GZ_GAMES.map((g) => `${g.name} ${gs.by_game?.[g.id] ?? 0}`).join(" · ")} · XP given {(gs.xp_week ?? 0).toLocaleString("en-NG")}</p>
      {isAdmin ? (
        <Panel title="Game Zone settings and XP">
          <GzSettingsForm initial={{
            queue_seconds: num(gz.queue_seconds, 15), daily_matches: num(gz.daily_matches, 80),
            xp_play: num(gz.xp_play, 5), xp_win: num(gz.xp_win, 15), xp_ranked_win: num(gz.xp_ranked_win, 10), xp_streak: num(gz.xp_streak, 10),
            games: Object.fromEntries(GZ_GAMES.map((g) => {
              const r = gz.games?.[g.id] ?? {};
              return [g.id, { on: r.on !== false, xp_play: str(r.xp_play), xp_win: str(r.xp_win), seconds: str(r.seconds), rounds: str(r.rounds) }];
            })),
          }} />
        </Panel>
      ) : null}
      {isAdmin ? (
        <Panel title="Where game questions come from">
          <GzSourceForm subjects={subjectList}
            source={src(gz.source) ?? "both"}
            sources={Object.fromEntries(Object.entries((gz.sources ?? {}) as Record<string, unknown>).flatMap(([k, v]) => { const x = src(v); return x ? [[k, x] as const] : []; }))}
            counts={(gzCounts.data ?? {}) as Record<string, { all: number; live: number }>} />
          <p className="mt-2 text-xs text-muted-foreground">Comprehension Clash follows the Use of English setting: JAMB comprehension passages, SolutionTee passages, or both.</p>
        </Panel>
      ) : null}
    </>
  );
  const classic = (
    <>
      <PageHeader title="" description="Study → Games in the app: Speed Quiz Duel (against the SolutionTee bot or a friend with a 6-letter code), Beat the AI Tutor, and Live Exam Arenas you schedule here. Answers are checked on the server; games with other people only use years open on the free plan." />
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {tile("Games today", st.today ?? 0)}{tile("Games in 7 days", st.week ?? 0)}{tile("Players in 7 days", st.players_week ?? 0)}{tile("XP from games, 7 days", (st.xp_week ?? 0).toLocaleString("en-NG"))}
      </div>
      <ArenaList arenas={(arenas.data ?? []).map((a) => ({ ...a, players: count.get(a.id) ?? 0 })) as AdminArena[]}
        subjects={cat.subjects} exams={cat.exams.map((e) => ({ id: e.id, code: e.code }))} />
      {isAdmin ? (
        <Panel title="Settings and XP">
          <GamesSettingsForm initial={{
            on: s.on !== false, questions: s.questions ?? 10, seconds: s.seconds ?? 15, daily_games: s.daily_games ?? 40, daily_xp: s.daily_xp ?? 100,
            arena_min_players: s.arena_min_players ?? 5,
            xp: { play: s.xp?.play ?? 5, win: s.xp?.win ?? 15, beat_ai: s.xp?.beat_ai ?? 25, arena_play: s.xp?.arena_play ?? 5, arena_top: s.xp?.arena_top ?? [30, 20, 10] },
          }} />
        </Panel>
      ) : null}
    </>
  );
  return (
    <>
      <PageHeader title="Game Zone" description="Eight live games against students or the SolutionTee Bot, with Quick Match, Practice vs AI, friend codes and Ranked. Everything is timed and checked on the server; XP only. Each game has its own tab: how it works, the best content for it and its CSV format." />
      <GzAdminTabs tabs={[
        { id: "overview", label: "Overview", content: overview },
        { id: "duel", label: "JAMB Duel", content: questions("duel") },
        {
          id: "reading", label: "Comprehension Clash", content: (
            <>
              <GzGuide game="reading" />
              {gameStat("reading")}
              {isAdmin ? <GzReadingForm wpm={wpm} /> : null}
              <GzPassagesCsv />
              <GzPassages />
            </>
          ),
        },
        { id: "rush", label: "Speed Rush", content: questions("rush") },
        { id: "survival", label: "Knowledge Survival", content: questions("survival") },
        { id: "blitz", label: "Maths Blitz", content: (<><GzGuide game="blitz" />{gameStat("blitz")}</>) },
        {
          id: "words", label: "Word War", content: (
            <>
              <GzGuide game="words" />
              {gameStat("words")}
              <GzWordsCsv />
              <GzWords words={(words.data ?? []) as GzWord[]} />
            </>
          ),
        },
        {
          id: "memory", label: "Memory Flash", content: (
            <>
              <GzGuide game="memory" />
              {gameStat("memory")}
              <GzCardsCsv subjects={cat.subjects.map((x) => ({ id: x.id, name: x.name, code: x.code }))} />
              <GzCards cards={(cards.data ?? []) as GzCard[]} subjects={subjectList} />
            </>
          ),
        },
        { id: "relay", label: "Team Relay", content: questions("relay") },
        { id: "classic", label: "Classic games", content: classic },
      ]} />
    </>
  );
}
