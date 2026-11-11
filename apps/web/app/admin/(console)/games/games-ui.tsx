"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill, when } from "@/components/admin/ui";
import { deleteArena, saveArena, saveGamesSettings } from "./actions";

export type AdminArena = {
  id: string; title: string; exam_id: number; subject_id: number | null; starts_at: string; q_count: number; seconds: number; gap: number;
  max_players: number; status: "draft" | "published" | "cancelled"; rewarded_at: string | null; players: number;
};
export type GamesSettings = {
  on: boolean; questions: number; seconds: number; daily_games: number; daily_xp: number; arena_min_players: number;
  xp: { play: number; win: number; beat_ai: number; arena_play: number; arena_top: number[] };
};
type Subject = { id: number; name: string };
type Exam = { id: number; code: string };

/** "2026-11-12T18:00" in Lagos time for a datetime-local input. */
const lagos = (iso: string) => new Date(new Date(iso).getTime() + 3600000).toISOString().slice(0, 16);
const endsAt = (a: AdminArena) => new Date(a.starts_at).getTime() + a.q_count * (a.seconds + a.gap) * 1000;

function ArenaForm({ a, subjects, exams, onDone }: { a?: AdminArena; subjects: Subject[]; exams: Exam[]; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({
    title: a?.title ?? "", exam_id: String(a?.exam_id ?? exams[0]?.id ?? 1), subject_id: String(a?.subject_id ?? subjects[0]?.id ?? 1),
    starts_at: a ? lagos(a.starts_at) : "", q_count: String(a?.q_count ?? 20), seconds: String(a?.seconds ?? 20), gap: String(a?.gap ?? 5),
    max_players: String(a?.max_players ?? 50), status: a?.status ?? "draft",
  });
  const id = a?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const field = (k: keyof typeof f, label: string, extra?: React.InputHTMLAttributes<HTMLInputElement>) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><input id={`${k}-${id}`} className={inputCls} value={f[k]} onChange={set(k)} {...extra} /></div>
  );
  const minutes = Math.ceil((Number(f.q_count) * (Number(f.seconds) + Number(f.gap))) / 60);
  const submit = () => start(async () => {
    const r = await saveArena({ id: a?.id, ...f });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    onDone();
    router.refresh();
  });
  return (
    <div className="grid gap-3">
      <div className="grid gap-3 md:grid-cols-[2fr_1fr_1fr]">
        {field("title", "Arena title", { maxLength: 80, placeholder: "Friday night JAMB English Arena" })}
        <div><Label htmlFor={`exam-${id}`}>Exam</Label>
          <select id={`exam-${id}`} className={inputCls} value={f.exam_id} onChange={set("exam_id")}>{exams.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}</select></div>
        <div><Label htmlFor={`subject-${id}`}>Subject</Label>
          <select id={`subject-${id}`} className={inputCls} value={f.subject_id} onChange={set("subject_id")}>
            {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select></div>
      </div>
      <div className="grid gap-3 md:grid-cols-5">
        {field("starts_at", "Starts (Lagos time)", { type: "datetime-local" })}
        {field("q_count", "Questions", { type: "number", min: 5, max: 60 })}
        {field("seconds", "Seconds per question", { type: "number", min: 8, max: 60 })}
        {field("gap", "Seconds to show the answer", { type: "number", min: 3, max: 15 })}
        {field("max_players", "Most players", { type: "number", min: 2, max: 500 })}
      </div>
      <div className="flex flex-wrap items-end gap-3">
        <div><Label htmlFor={`status-${id}`}>Status</Label>
          <select id={`status-${id}`} className={inputCls} value={f.status} onChange={set("status")}>
            <option value="draft">Draft (hidden)</option><option value="published">Published</option><option value="cancelled">Cancelled</option>
          </select></div>
        <p className="text-xs text-muted-foreground">Takes about {Number.isFinite(minutes) ? minutes : "?"} minutes. Questions come from years open on the free plan, so everyone can play.</p>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{a ? "Save" : "Add arena"}</Button></div>
      </div>
    </div>
  );
}

export function ArenaList({ arenas, subjects, exams }: { arenas: AdminArena[]; subjects: Subject[]; exams: Exam[] }) {
  const router = useRouter();
  const [editing, setEditing] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [now] = useState(() => new Date().getTime());
  const subject = (id: number | null) => (id ? subjects.find((s) => s.id === id)?.name : "Use of English") ?? "Subject";
  const exam = (id: number) => exams.find((e) => e.id === id)?.code ?? "";
  return (
    <Panel title="Live Exam Arenas" bodyClassName="p-0"
      actions={<Button size="sm" onClick={() => setEditing("new")} disabled={editing === "new"}><Plus size={16} weight="bold" /> Add arena</Button>}>
      {editing === "new" ? <div className="border-b p-4"><ArenaForm subjects={subjects} exams={exams} onDone={() => setEditing(null)} /></div> : null}
      {arenas.length ? (
        <ul className="divide-y">
          {arenas.map((a) => {
            const live = new Date(a.starts_at).getTime() <= now && endsAt(a) > now;
            const over = endsAt(a) <= now;
            return (
              <li key={a.id} className="p-4">
                {editing === a.id ? <ArenaForm a={a} subjects={subjects} exams={exams} onDone={() => setEditing(null)} /> : (
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="font-bold">{a.title}</p>
                      <p className="text-sm text-muted-foreground">{when(a.starts_at)} · {exam(a.exam_id)} {subject(a.subject_id)} · {a.q_count} questions × {a.seconds} s · {a.players}/{a.max_players} players</p>
                    </div>
                    <Pill tone={a.status === "cancelled" ? "error" : live ? "warn" : over ? "neutral" : a.status === "published" ? "ok" : "neutral"}>
                      {a.status === "cancelled" ? "Cancelled" : live ? "Live now" : over ? (a.rewarded_at ? "Ended · XP paid" : "Ended") : a.status === "published" ? "Published" : "Draft"}
                    </Pill>
                    {!over ? <Button size="sm" variant="outline" onClick={() => setEditing(a.id)}>Edit</Button> : null}
                    {!a.players ? <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${a.title}?`)) start(async () => { const r = await deleteArena(a.id); if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error); }); }}>Delete</Button> : null}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      ) : editing !== "new" ? <EmptyState title="No arenas yet">Schedule an arena: students join from Study → Games and get a reminder 5 minutes before it starts.</EmptyState> : null}
    </Panel>
  );
}

export function GamesSettingsForm({ initial }: { initial: GamesSettings }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState(initial);
  const num = (label: string, value: number, onChange: (v: number) => void, id: string, max = 1000) => (
    <div><Label htmlFor={id}>{label}</Label><input id={id} type="number" min={0} max={max} className={inputCls} value={value} onChange={(e) => onChange(Number(e.target.value))} /></div>
  );
  const xp = (k: keyof Omit<GamesSettings["xp"], "arena_top">) => (v: number) => setF({ ...f, xp: { ...f.xp, [k]: v } });
  const top = (i: number) => (v: number) => setF({ ...f, xp: { ...f.xp, arena_top: f.xp.arena_top.map((x, j) => (j === i ? v : x)) } });
  return (
    <div className="grid gap-4">
      <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={f.on} onChange={(e) => setF({ ...f, on: e.target.checked })} /> Games on in the app</label>
      <div className="grid gap-3 md:grid-cols-5">
        {num("Questions per duel", f.questions, (v) => setF({ ...f, questions: v }), "g-q", 20)}
        {num("Seconds per question", f.seconds, (v) => setF({ ...f, seconds: v }), "g-s", 60)}
        {num("Games a student can start a day", f.daily_games, (v) => setF({ ...f, daily_games: v }), "g-d", 500)}
        {num("Most XP from games a day", f.daily_xp, (v) => setF({ ...f, daily_xp: v }), "g-x")}
        {num("Players needed for arena top-3 XP", f.arena_min_players, (v) => setF({ ...f, arena_min_players: v }), "g-m", 500)}
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        {num("XP for finishing a duel", f.xp.play, xp("play"), "x-play", 100)}
        {num("XP for winning a duel", f.xp.win, xp("win"), "x-win", 200)}
        {num("XP for beating the AI Tutor", f.xp.beat_ai, xp("beat_ai"), "x-ai", 300)}
        {num("XP for playing an arena", f.xp.arena_play, xp("arena_play"), "x-ap", 100)}
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        {num("Arena 1st place XP", f.xp.arena_top[0] ?? 0, top(0), "x-t1", 500)}
        {num("Arena 2nd place XP", f.xp.arena_top[1] ?? 0, top(1), "x-t2", 500)}
        {num("Arena 3rd place XP", f.xp.arena_top[2] ?? 0, top(2), "x-t3", 500)}
        <div className="flex items-end justify-end"><Button disabled={pending} onClick={() => start(async () => {
          const r = await saveGamesSettings(f);
          if (!r.ok) return void toast.error(r.error);
          toast.success(r.message);
          router.refresh();
        })}>Save settings</Button></div>
      </div>
      <p className="text-xs text-muted-foreground">Game XP also counts toward the normal daily XP cap (XP & streaks). XP is never cash.</p>
    </div>
  );
}
