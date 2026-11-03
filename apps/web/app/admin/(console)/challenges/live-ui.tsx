"use client";
import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowsClockwise, Copy, DownloadSimple, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { MathText } from "@/components/admin/math-text";
import { Pill } from "@/components/admin/ui";
import { copyChallenge, liveData, type LiveData } from "./actions";

const LEVEL: Record<string, string> = { easy: "Easy", medium: "Medium", hard: "Hard", very_hard: "Very hard" };
const mmss = (ms: number | null | undefined) => {
  const s = Math.round((ms ?? 0) / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};
const nowLabel = () => new Date().toLocaleTimeString("en-NG", { hour: "2-digit", minute: "2-digit", second: "2-digit", timeZone: "Africa/Lagos" });

function Tile({ label, value, tone }: { label: string; value: string | number; tone?: "ok" | "warn" | "error" }) {
  const c = tone === "ok" ? "text-success" : tone === "warn" ? "text-warning" : tone === "error" ? "text-error" : "";
  return (
    <div className="rounded-xl border bg-card p-3">
      <div className={`text-xl font-bold tabular-nums ${c}`}>{value}</div>
      <div className="text-xs text-muted-foreground">{label}</div>
    </div>
  );
}

function Bar({ pct, label, sub }: { pct: number; label: string; sub: string }) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs"><span className="font-semibold">{label}</span><span className="tabular-nums text-muted-foreground">{sub}</span></div>
      <div className="h-2 overflow-hidden rounded-full bg-surface-alt"><div className="h-full rounded-full bg-secondary" style={{ width: `${Math.max(0, Math.min(100, pct))}%` }} /></div>
    </div>
  );
}

function csv(d: LiveData, title: string) {
  const esc = (v: unknown) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const head = ["rank", "name", "state", "status", "score", "answered", "total", "time", "exits", "flags", "disqualified_reason", "prize"];
  const lines = d.board.map((r) => [r.rank ?? "", r.name, r.state, r.review === "dq" ? "disqualified (review)" : r.status, r.score, r.answered, r.total, mmss(r.time_ms), r.exits, r.flags.join("; "), r.dq_reason, r.prize ?? ""].map(esc).join(","));
  const blob = new Blob([[head.join(","), ...lines].join("\n")], { type: "text/csv" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${title.replace(/[^a-z0-9]+/gi, "-").toLowerCase()}-results.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

/** Live leaderboard (refreshes every 15 s while the challenge runs) and the analysis. */
export function LivePanel({ id, title, initial }: { id: string; title: string; initial: LiveData }) {
  const [d, setD] = useState(initial);
  const [at, setAt] = useState<string>("");
  const [pending, start] = useTransition();
  const [all, setAll] = useState(false);
  const refresh = () => start(async () => {
    const r = await liveData(id);
    if (r.ok && r.data) { setD(r.data); setAt(nowLabel()); } else if (!r.ok) toast.error(r.error);
  });
  useEffect(() => {
    if (d.status !== "live") return;
    const t = setInterval(() => { if (document.visibilityState === "visible") refresh(); }, 15_000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [d.status, id]);
  const s = d.summary;
  const board = all ? d.board : d.board.slice(0, 50);
  const hardest = d.questions.filter((q) => q.answers > 0).slice(0, 10);
  const spreadMax = Math.max(1, ...d.spread.map((x) => x.students));
  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-2">
        {d.status === "live" ? <Pill tone="ok">Live · refreshes every 15 s</Pill> : <Pill tone="neutral">{d.status === "ended" ? "Ended" : "Not started"}</Pill>}
        {at ? <span className="text-xs text-muted-foreground">Updated {at}</span> : null}
        <div className="ml-auto flex gap-2">
          <Button type="button" size="sm" variant="outline" disabled={pending} onClick={refresh}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : <ArrowsClockwise size={16} />} Refresh</Button>
          <Button type="button" size="sm" variant="outline" disabled={!d.board.length} onClick={() => csv(d, title)}><DownloadSimple size={16} /> Results CSV</Button>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-8">
        <Tile label="Joined" value={s.joined} />
        <Tile label="Playing now" value={s.playing} tone={s.playing ? "ok" : undefined} />
        <Tile label="Finished" value={s.finished} />
        <Tile label="Disqualified" value={s.disqualified} tone={s.disqualified ? "error" : undefined} />
        <Tile label="Fair-play flags" value={s.flagged} tone={s.flagged ? "warn" : undefined} />
        <Tile label="Appeals waiting" value={s.appeals_pending} tone={s.appeals_pending ? "warn" : undefined} />
        <Tile label="Average score" value={s.avg_pct == null ? "–" : `${s.avg_pct}%`} />
        <Tile label="Average time" value={s.avg_ms == null ? "–" : mmss(s.avg_ms)} />
      </div>

      <div>
        <h3 className="mb-2 text-sm font-bold">Leaderboard{d.status === "live" ? " (live)" : ""}</h3>
        {d.board.length ? (
          <div className="overflow-x-auto rounded-xl border">
            <table className="w-full text-sm">
              <thead className="bg-surface-alt text-left text-xs text-muted-foreground">
                <tr><th className="px-3 py-2">#</th><th>Student</th><th>Status</th><th>Score</th><th>Progress</th><th>Time</th><th>Exits</th><th className="pr-3">Checks</th></tr>
              </thead>
              <tbody>{board.map((r) => (
                <tr key={r.id} className="border-t">
                  <td className="px-3 py-1.5 font-bold tabular-nums">{r.rank ?? "–"}</td>
                  <td>{r.name ?? "Student"}<span className="block text-xs text-muted-foreground">{r.state ?? ""}</span></td>
                  <td>{r.review === "dq" ? <Pill tone="error">Disqualified (review)</Pill> : r.status === "playing" ? <Pill tone="ok">Playing</Pill> : r.status === "disqualified" ? <Pill tone="error">Disqualified</Pill> : <Pill tone="neutral">Finished</Pill>}</td>
                  <td className="font-semibold tabular-nums">{r.score}/{r.total}{r.prize ? <span className="block text-xs text-success">₦{r.prize.toLocaleString("en-NG")}</span> : null}</td>
                  <td className="tabular-nums text-muted-foreground">{r.answered}/{r.total}</td>
                  <td className="tabular-nums">{mmss(r.time_ms)}</td>
                  <td className="tabular-nums">{r.exits}</td>
                  <td className="pr-3 text-xs text-warning">{[r.dq_reason, ...r.flags].filter(Boolean).join(" · ")}</td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        ) : <p className="text-sm text-muted-foreground">Nobody has started yet.</p>}
        {d.board.length > 50 ? <Button type="button" size="sm" variant="ghost" className="mt-1" onClick={() => setAll(!all)}>{all ? "Show the top 50" : `Show all ${d.board.length}`}</Button> : null}
      </div>

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-2">
          <h3 className="text-sm font-bold">% right by subject</h3>
          {d.by_subject.length ? d.by_subject.map((x) => <Bar key={x.subject} label={x.subject} pct={x.right_pct} sub={`${x.right_pct}% · ${x.answers} answers`} />) : <p className="text-xs text-muted-foreground">No answers yet.</p>}
        </div>
        <div className="space-y-2">
          <h3 className="text-sm font-bold">% right by level</h3>
          {d.by_level.length ? d.by_level.map((x) => <Bar key={x.level} label={LEVEL[x.level] ?? x.level} pct={x.right_pct} sub={`${x.right_pct}% · ${mmss(x.avg_ms)} avg`} />) : <p className="text-xs text-muted-foreground">No answers yet.</p>}
          <p className="text-xs text-muted-foreground">If “Easy” is not clearly higher than “Hard”, some levels may be wrong.</p>
        </div>
        <div className="space-y-2">
          <h3 className="text-sm font-bold">Scores (finished students)</h3>
          <div className="flex h-28 items-end gap-1">{d.spread.map((x) => (
            <div key={x.from} className="flex flex-1 flex-col items-center gap-1" title={`${x.from}–${x.from + 10}%: ${x.students}`}>
              <span className="text-[10px] tabular-nums text-muted-foreground">{x.students || ""}</span>
              <div className="w-full rounded-t bg-secondary" style={{ height: `${(x.students / spreadMax) * 80}px` }} />
            </div>
          ))}</div>
          <div className="flex justify-between text-[10px] text-muted-foreground"><span>0%</span><span>50%</span><span>100%</span></div>
        </div>
      </div>

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-2 lg:col-span-2">
          <h3 className="text-sm font-bold">Hardest questions</h3>
          {hardest.length ? (
            <ol className="space-y-2">{hardest.map((q) => (
              <li key={q.id} className="rounded-xl border p-2.5 text-sm">
                <MathText text={q.body} />
                <span className="mt-1 block text-xs text-muted-foreground">
                  {q.subject ?? "No subject"} · {LEVEL[q.level] ?? q.level} · <b className={(q.right_pct ?? 0) < 30 ? "text-error" : ""}>{q.right_pct ?? 0}% right</b> of {q.answers}
                  {q.top_wrong ? ` · most picked wrong: ${q.top_wrong} (answer ${q.answer})` : ""}{q.no_answer ? ` · ${q.no_answer} ran out of time` : ""}
                </span>
              </li>
            ))}</ol>
          ) : <p className="text-xs text-muted-foreground">No answers yet.</p>}
        </div>
        <div className="space-y-2">
          <h3 className="text-sm font-bold">Why students were disqualified</h3>
          {d.exits.length ? (
            <ul className="space-y-1 text-sm">{d.exits.map((x) => <li key={x.reason} className="flex justify-between gap-2"><span>{x.reason}</span><b className="tabular-nums">{x.students}</b></li>)}</ul>
          ) : <p className="text-xs text-muted-foreground">Nobody was disqualified.</p>}
        </div>
      </div>
    </div>
  );
}

/** Copy this challenge (settings and questions) to a new start time, hidden until published. */
export function CopyButton({ id, defaultStart }: { id: string; defaultStart: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [starts, setStarts] = useState(defaultStart);
  const [pending, start] = useTransition();
  if (!open) return <Button variant="outline" onClick={() => setOpen(true)}><Copy size={16} /> Copy for next time</Button>;
  return (
    <div className="flex flex-wrap items-center gap-2">
      <input type="datetime-local" aria-label="Copy starts (Lagos time)" value={starts} onChange={(e) => setStarts(e.target.value)} className={`${inputCls} w-auto`} />
      <Button disabled={pending} onClick={() => start(async () => {
        const r = await copyChallenge(id, starts);
        if (r.ok && r.data) { toast.success(r.message ?? "Copied"); router.push(`/admin/challenges/${r.data.id}`); } else if (!r.ok) toast.error(r.error);
      })}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Copy</Button>
      <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
    </div>
  );
}
