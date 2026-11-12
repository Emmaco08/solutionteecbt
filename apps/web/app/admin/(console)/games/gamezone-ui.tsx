"use client";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill } from "@/components/admin/ui";
import { deleteGzContent, saveGzCard, saveGzSettings, saveGzWord, setGzContent } from "./gamezone-actions";
import { GZ_GAMES } from "./gamezone-shared";

// Game Zone v2 admin (D-157).



type GameRow = { on: boolean; xp_play: string; xp_win: string; seconds: string; rounds: string };
export type GzSettings = {
  queue_seconds: number; daily_matches: number; xp_play: number; xp_win: number; xp_ranked_win: number; xp_streak: number;
  games: Record<string, GameRow>;
};
export type GzWord = { id: number; kind: "synonym" | "antonym" | "spelling"; word: string; answer: string; wrong: string[]; active: boolean };
export type GzCard = { id: number; subject_id: number; front: string; back: string; active: boolean };
type Subject = { id: number; name: string };

function useAct() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>, after?: () => void) =>
    start(async () => {
      const r = await fn();
      if (!r.ok) return void toast.error(r.error ?? "Something went wrong");
      toast.success(r.message ?? "Saved");
      after?.();
      router.refresh();
    });
  return { pending, run };
}

export function GzSettingsForm({ initial }: { initial: GzSettings }) {
  const { pending, run } = useAct();
  const [f, setF] = useState(initial);
  const num = (k: keyof Omit<GzSettings, "games">, label: string, max: number) => (
    <div>
      <Label htmlFor={`gz-${k}`}>{label}</Label>
      <input id={`gz-${k}`} type="number" min={0} max={max} className={inputCls} value={f[k]} onChange={(e) => setF({ ...f, [k]: Number(e.target.value) })} />
    </div>
  );
  const game = (id: string, k: keyof GameRow, v: string | boolean) => setF({ ...f, games: { ...f.games, [id]: { ...f.games[id], [k]: v } } });
  return (
    <div className="grid gap-4">
      <div className="grid gap-3 md:grid-cols-3">
        {num("queue_seconds", "Seconds to wait for a student before a bot joins", 60)}
        {num("daily_matches", "Games a student can play a day", 500)}
      </div>
      <div>
        <p className="mb-2 text-sm font-bold">XP (every game, unless a game below has its own)</p>
        <div className="grid gap-3 md:grid-cols-4">
          {num("xp_play", "XP for finishing a game", 500)}
          {num("xp_win", "XP for winning", 500)}
          {num("xp_ranked_win", "Extra XP for a Ranked win", 500)}
          {num("xp_streak", "Extra XP for 3 wins in a row", 500)}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">A win only gives XP when at least 40% of the answers were right (no reward for guessing). Game XP counts toward the daily game XP cap above.</p>
      </div>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 text-left text-xs text-muted-foreground">
            <tr><th className="p-2">Game</th><th className="p-2">On</th><th className="p-2">XP for playing</th><th className="p-2">XP for winning</th><th className="p-2">Seconds</th><th className="p-2">Rounds</th></tr>
          </thead>
          <tbody className="divide-y">
            {GZ_GAMES.map((g) => {
              const r = f.games[g.id];
              const cell = (k: "xp_play" | "xp_win" | "seconds" | "rounds", ph: string | number | null) =>
                ph === null ? <span className="text-xs text-muted-foreground">—</span> : (
                  <input aria-label={`${g.name} ${k}`} type="number" min={0} className={`${inputCls} h-9 w-24`} placeholder={String(ph)} value={r[k]} onChange={(e) => game(g.id, k, e.target.value)} />
                );
              return (
                <tr key={g.id}>
                  <td className="p-2 font-bold">{g.name}</td>
                  <td className="p-2"><input aria-label={`${g.name} on`} type="checkbox" checked={r.on} onChange={(e) => game(g.id, "on", e.target.checked)} /></td>
                  <td className="p-2">{cell("xp_play", f.xp_play)}</td>
                  <td className="p-2">{cell("xp_win", f.xp_win)}</td>
                  <td className="p-2">{cell("seconds", g.seconds)}</td>
                  <td className="p-2">{cell("rounds", g.rounds)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground">Leave a box empty to use the default shown in grey. Seconds: per question for round games, the whole race for Speed Rush and Maths Blitz, and the whole game for Memory Flash.</p>
      <div className="flex justify-end">
        <Button disabled={pending} onClick={() => run(() => saveGzSettings(f))}>Save Game Zone settings</Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- Word War words

function WordForm({ w, onDone }: { w?: GzWord; onDone: () => void }) {
  const { pending, run } = useAct();
  const [f, setF] = useState({ kind: w?.kind ?? "synonym", word: w?.word ?? "", answer: w?.answer ?? "", wrong: [...(w?.wrong ?? []), "", "", ""].slice(0, 3), active: w?.active ?? true });
  const id = w?.id ?? "new";
  return (
    <div className="grid gap-3">
      <div className="grid gap-3 md:grid-cols-[1fr_2fr_2fr]">
        <div><Label htmlFor={`k-${id}`}>Type</Label>
          <select id={`k-${id}`} className={inputCls} value={f.kind} onChange={(e) => setF({ ...f, kind: e.target.value as GzWord["kind"] })}>
            <option value="synonym">Same meaning</option><option value="antonym">Opposite</option><option value="spelling">Spelling</option>
          </select></div>
        <div><Label htmlFor={`w-${id}`}>{f.kind === "spelling" ? "Word (optional)" : "Word"}</Label><input id={`w-${id}`} className={inputCls} value={f.word} maxLength={40} onChange={(e) => setF({ ...f, word: e.target.value })} /></div>
        <div><Label htmlFor={`a-${id}`}>{f.kind === "spelling" ? "Right spelling" : "Right answer"}</Label><input id={`a-${id}`} className={inputCls} value={f.answer} maxLength={40} onChange={(e) => setF({ ...f, answer: e.target.value })} /></div>
      </div>
      <div className="grid gap-3 md:grid-cols-3">
        {f.wrong.map((x, i) => (
          <div key={i}><Label htmlFor={`x${i}-${id}`}>Wrong answer {i + 1}</Label>
            <input id={`x${i}-${id}`} className={inputCls} value={x} maxLength={40} onChange={(e) => setF({ ...f, wrong: f.wrong.map((y, j) => (j === i ? e.target.value : y)) })} /></div>
        ))}
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Live in the app</label>
        <div className="ml-auto flex gap-2">
          <Button variant="ghost" onClick={onDone}>Cancel</Button>
          <Button disabled={pending} onClick={() => run(() => saveGzWord({ id: w?.id, ...f }), onDone)}>{w ? "Save" : "Add word"}</Button>
        </div>
      </div>
    </div>
  );
}

export function GzWords({ words }: { words: GzWord[] }) {
  const { pending, run } = useAct();
  const [editing, setEditing] = useState<number | "new" | null>(null);
  const [show, setShow] = useState<"all" | "waiting" | "live">(words.some((w) => !w.active) ? "waiting" : "all");
  const [q, setQ] = useState("");
  const list = useMemo(
    () => words.filter((w) => (show === "all" || (show === "live") === w.active) && (!q || `${w.word} ${w.answer} ${w.wrong.join(" ")}`.toLowerCase().includes(q.toLowerCase()))),
    [words, show, q],
  );
  const waiting = words.filter((w) => !w.active).length;
  const kind = { synonym: "Same meaning", antonym: "Opposite", spelling: "Spelling" };
  return (
    <Panel title={`Word War words (${words.length - waiting} live, ${waiting} waiting for review)`} bodyClassName="p-0"
      actions={<div className="flex gap-2">
        {waiting ? <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm(`Put all ${waiting} waiting words live?`)) run(() => setGzContent("words", "all", true)); }}>Approve all</Button> : null}
        <Button size="sm" onClick={() => setEditing("new")}><Plus size={16} weight="bold" /> Add word</Button>
      </div>}>
      <div className="flex flex-wrap items-center gap-2 border-b p-3">
        {(["waiting", "live", "all"] as const).map((s) => (
          <Button key={s} size="sm" variant={show === s ? "default" : "ghost"} onClick={() => setShow(s)}>{s === "waiting" ? "Waiting" : s === "live" ? "Live" : "All"}</Button>
        ))}
        <input aria-label="Search words" className={`${inputCls} ml-auto h-9 max-w-xs`} placeholder="Search" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {editing === "new" ? <div className="border-b p-4"><WordForm onDone={() => setEditing(null)} /></div> : null}
      {list.length ? (
        <ul className="max-h-[560px] divide-y overflow-y-auto">
          {list.map((w) => (
            <li key={w.id} className="p-3">
              {editing === w.id ? <WordForm w={w} onDone={() => setEditing(null)} /> : (
                <div className="flex flex-wrap items-center gap-3">
                  <Pill tone={w.kind === "spelling" ? "warn" : w.kind === "antonym" ? "error" : "ok"}>{kind[w.kind]}</Pill>
                  <div className="min-w-0 flex-1">
                    <p className="font-bold">{w.word || "Which is spelt right?"} → <span className="text-success">{w.answer}</span></p>
                    <p className="text-xs text-muted-foreground">Wrong: {w.wrong.join(", ")}</p>
                  </div>
                  <Pill tone={w.active ? "ok" : "neutral"}>{w.active ? "Live" : "Waiting"}</Pill>
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => setGzContent("words", [w.id], !w.active))}>{w.active ? "Hide" : "Approve"}</Button>
                  <Button size="sm" variant="ghost" onClick={() => setEditing(w.id)}>Edit</Button>
                  <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm("Delete this word?")) run(() => deleteGzContent("words", w.id)); }}>Delete</Button>
                </div>
              )}
            </li>
          ))}
        </ul>
      ) : <EmptyState title="Nothing here">No words match.</EmptyState>}
    </Panel>
  );
}

// ---------------------------------------------------------------- Memory Flash cards

function CardForm({ c, subjects, onDone }: { c?: GzCard; subjects: Subject[]; onDone: () => void }) {
  const { pending, run } = useAct();
  const [f, setF] = useState({ subject_id: String(c?.subject_id ?? subjects[0]?.id ?? 3), front: c?.front ?? "", back: c?.back ?? "", active: c?.active ?? true });
  const id = c?.id ?? "new";
  return (
    <div className="grid gap-3 md:grid-cols-[1fr_1fr_1fr_auto] md:items-end">
      <div><Label htmlFor={`s-${id}`}>Subject</Label>
        <select id={`s-${id}`} className={inputCls} value={f.subject_id} onChange={(e) => setF({ ...f, subject_id: e.target.value })}>
          {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select></div>
      <div><Label htmlFor={`f-${id}`}>Card A (e.g. Na)</Label><input id={`f-${id}`} className={inputCls} value={f.front} maxLength={30} onChange={(e) => setF({ ...f, front: e.target.value })} /></div>
      <div><Label htmlFor={`b-${id}`}>Card B (e.g. Sodium)</Label><input id={`b-${id}`} className={inputCls} value={f.back} maxLength={30} onChange={(e) => setF({ ...f, back: e.target.value })} /></div>
      <div className="flex items-center gap-2">
        <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Live</label>
        <Button variant="ghost" onClick={onDone}>Cancel</Button>
        <Button disabled={pending} onClick={() => run(() => saveGzCard({ id: c?.id, ...f }), onDone)}>{c ? "Save" : "Add pair"}</Button>
      </div>
    </div>
  );
}

export function GzCards({ cards, subjects }: { cards: GzCard[]; subjects: Subject[] }) {
  const { pending, run } = useAct();
  const [editing, setEditing] = useState<number | "new" | null>(null);
  const [subject, setSubject] = useState<number | "all">("all");
  const name = (id: number) => subjects.find((s) => s.id === id)?.name ?? `Subject ${id}`;
  const list = cards.filter((c) => subject === "all" || c.subject_id === subject);
  const waiting = cards.filter((c) => !c.active).length;
  const used = [...new Set(cards.map((c) => c.subject_id))];
  return (
    <Panel title={`Memory Flash cards (${cards.length - waiting} live, ${waiting} waiting for review)`} bodyClassName="p-0"
      actions={<div className="flex gap-2">
        {waiting ? <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm(`Put all ${waiting} waiting card pairs live?`)) run(() => setGzContent("cards", "all", true)); }}>Approve all</Button> : null}
        <Button size="sm" onClick={() => setEditing("new")}><Plus size={16} weight="bold" /> Add pair</Button>
      </div>}>
      <div className="flex flex-wrap gap-2 border-b p-3">
        <Button size="sm" variant={subject === "all" ? "default" : "ghost"} onClick={() => setSubject("all")}>All</Button>
        {used.map((s) => <Button key={s} size="sm" variant={subject === s ? "default" : "ghost"} onClick={() => setSubject(s)}>{name(s)}</Button>)}
      </div>
      {editing === "new" ? <div className="border-b p-4"><CardForm subjects={subjects} onDone={() => setEditing(null)} /></div> : null}
      {list.length ? (
        <ul className="max-h-[520px] divide-y overflow-y-auto">
          {list.map((c) => (
            <li key={c.id} className="p-3">
              {editing === c.id ? <CardForm c={c} subjects={subjects} onDone={() => setEditing(null)} /> : (
                <div className="flex flex-wrap items-center gap-3">
                  <span className="w-28 text-xs text-muted-foreground">{name(c.subject_id)}</span>
                  <p className="min-w-0 flex-1 font-bold">{c.front} ↔ {c.back}</p>
                  <Pill tone={c.active ? "ok" : "neutral"}>{c.active ? "Live" : "Waiting"}</Pill>
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => setGzContent("cards", [c.id], !c.active))}>{c.active ? "Hide" : "Approve"}</Button>
                  <Button size="sm" variant="ghost" onClick={() => setEditing(c.id)}>Edit</Button>
                  <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm("Delete this pair?")) run(() => deleteGzContent("cards", c.id)); }}>Delete</Button>
                </div>
              )}
            </li>
          ))}
        </ul>
      ) : <EmptyState title="No cards yet">Add pairs such as Na ↔ Sodium or F = ma ↔ Newton&apos;s second law.</EmptyState>}
    </Panel>
  );
}
