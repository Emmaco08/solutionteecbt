"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { MagnifyingGlass, SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { MathText } from "@/components/admin/math-text";
import { Pill, when } from "@/components/admin/ui";
import { findQuestions, type Candidate } from "../qotd/actions";
import { addFromBank, addQuestion, closeNow, removeQuestion, reviewEntry, saveChallenge } from "./actions";

export type ChallengeRow = {
  id: string; title: string; subtitle: string | null; kind: "cash" | "event" | "practice"; icon: string; exam_code: string | null;
  starts_at: string; ends_at: string; seconds_per_question: number; prizes: number[]; reward_text: string | null;
  premium_days: number; premium_top: number; allowed_exits: number; published: boolean; closed_at: string | null;
};
export type QRow = { id: string; position: number; body: string; options: Record<string, string>; answer: string };
export type EntryRow = {
  id: string; name: string | null; state: string | null; status: string; score: number; answered: number; time_ms: number; exits: number;
  dq_reason: string | null; flags: string[]; review: string | null; rank: number | null; prize: number | null; started_at: string; claim: string | null;
};

/** ISO → "YYYY-MM-DDTHH:mm" in Lagos time (UTC+1) for datetime-local inputs. */
const toLocal = (iso?: string) => (iso ? new Date(Date.parse(iso) + 3600_000).toISOString().slice(0, 16) : "");
const ICONS = [["trophy", "Trophy"], ["function", "Maths"], ["atom", "Physics"], ["book-open-text", "English"], ["flask", "Chemistry"], ["globe", "Geography"], ["lightning", "Speed"], ["star", "Star"]];

export function ChallengeForm({ c }: { c?: ChallengeRow }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [kind, setKind] = useState(c?.kind ?? "cash");
  return (
    <form className="space-y-4" action={(f) => start(async () => {
      if (c) f.set("id", c.id);
      const r = await saveChallenge(f);
      if (r.ok) { toast.success(r.message ?? "Saved"); if (!c && r.data) router.push(`/admin/challenges/${r.data.id}`); else router.refresh(); } else toast.error(r.error);
    })}>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="cTitle">Title</Label>
          <input id="cTitle" name="title" defaultValue={c?.title} required maxLength={80} placeholder="Weekly Challenge #1" className={inputCls} /></div>
        <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="cSub">Short description (optional)</Label>
          <input id="cSub" name="subtitle" defaultValue={c?.subtitle ?? ""} maxLength={160} placeholder="Mixed JAMB subjects · new questions" className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cKind">Type</Label>
          <select id="cKind" name="kind" value={kind} onChange={(e) => setKind(e.target.value as typeof kind)} className={inputCls}>
            <option value="cash">Cash prize</option><option value="event">Event (prize or reward)</option><option value="practice">Practice (no prize)</option>
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="cIcon">Picture</Label>
          <select id="cIcon" name="icon" defaultValue={c?.icon ?? "trophy"} className={inputCls}>{ICONS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
        <div className="space-y-1.5"><Label htmlFor="cStart">Starts (Lagos time)</Label>
          <input id="cStart" name="starts" type="datetime-local" defaultValue={toLocal(c?.starts_at)} required className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cEnd">Ends and winners announced (Lagos time)</Label>
          <input id="cEnd" name="ends" type="datetime-local" defaultValue={toLocal(c?.ends_at)} required className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cSec">Seconds per question</Label>
          <input id="cSec" name="seconds" type="number" min={10} max={300} defaultValue={c?.seconds_per_question ?? 30} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cExits">Times a student may leave the screen</Label>
          <select id="cExits" name="allowed_exits" defaultValue={c?.allowed_exits ?? 0} className={inputCls}>
            <option value={0}>0 (leaving once disqualifies)</option><option value={1}>1</option><option value={2}>2</option><option value={3}>3</option>
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="cExam">Exam logo (optional)</Label>
          <select id="cExam" name="exam_code" defaultValue={c?.exam_code ?? ""} className={inputCls}><option value="">None</option><option>JAMB</option><option>WAEC</option><option>NECO</option></select></div>
      </div>
      {kind !== "practice" ? (
        <div className="space-y-1.5"><Label>Cash prizes in naira (leave 0 for none)</Label>
          <div className="grid grid-cols-3 gap-2">{[0, 1, 2].map((i) => (
            <input key={i} name={`p${i + 1}`} type="number" min={0} step={500} aria-label={`${i + 1} place prize`} defaultValue={c?.prizes?.[i] ?? 0} className={inputCls} placeholder={["1st", "2nd", "3rd"][i]} />
          ))}</div>
          <span className="text-xs text-muted-foreground">1st, 2nd and 3rd place.</span></div>
      ) : (<><input type="hidden" name="p1" value={0} /><input type="hidden" name="p2" value={0} /><input type="hidden" name="p3" value={0} /></>)}
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="space-y-1.5 sm:col-span-3"><Label htmlFor="cRew">Other reward text (optional)</Label>
          <input id="cRew" name="reward_text" defaultValue={c?.reward_text ?? ""} maxLength={160} placeholder="30 days of Premium for the top 10" className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cPd">Premium days as a reward</Label>
          <input id="cPd" name="premium_days" type="number" min={0} max={366} defaultValue={c?.premium_days ?? 0} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cPt">…for the top</Label>
          <input id="cPt" name="premium_top" type="number" min={0} max={100} defaultValue={c?.premium_top ?? 0} className={inputCls} /></div>
      </div>
      <label className="flex items-start gap-3 text-sm"><input type="checkbox" name="published" defaultChecked={c?.published ?? false} className="mt-1" />
        <span><b>Show to students</b><span className="block text-muted-foreground">Students see it on Home and in Test → Challenges. When it starts, everyone gets a “… is live” notification.</span></span></label>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button></div>
    </form>
  );
}

export function CloseButton({ id }: { id: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <Button variant="outline" disabled={pending} onClick={() => {
      if (!confirm("Close now? Winners are saved and told at once. This cannot be undone.")) return;
      start(async () => { const r = await closeNow(id); if (r.ok) { toast.success(r.message ?? "Closed"); router.refresh(); } else toast.error(r.error); });
    }}>Close now</Button>
  );
}

export function QuestionsPanel({ challengeId, rows, locked }: { challengeId: string; rows: QRow[]; locked: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [mode, setMode] = useState<"none" | "write" | "bank">(rows.length ? "none" : "write");
  const run = (p: Promise<{ ok: boolean; message?: string; error?: string }>) => start(async () => {
    const r = await p; if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error);
  });
  return (
    <div className="space-y-4">
      {rows.length ? (
        <ol className="space-y-2">{rows.map((q, i) => (
          <li key={q.id} className="flex gap-3 rounded-xl border p-3 text-sm">
            <b className="w-6 tabular-nums">{i + 1}.</b>
            <div className="min-w-0 flex-1"><MathText text={q.body} />
              <span className="mt-1 block text-xs text-muted-foreground">Answer {q.answer}: <MathText text={q.options[q.answer] ?? ""} /></span></div>
            {!locked ? <Button variant="ghost" size="icon" aria-label="Remove question" disabled={pending} onClick={() => run(removeQuestion(challengeId, q.id))}><Trash size={16} /></Button> : null}
          </li>
        ))}</ol>
      ) : <p className="text-sm text-muted-foreground">No questions yet. Add at least one before it starts. Every student gets them in a different order, one at a time.</p>}
      {locked ? <p className="text-xs text-muted-foreground">Students have started, so the questions cannot change.</p> : (
        <>
          <div className="flex flex-wrap gap-2">
            <Button type="button" size="sm" variant={mode === "write" ? "default" : "outline"} onClick={() => setMode("write")}>Write a new question</Button>
            <Button type="button" size="sm" variant={mode === "bank" ? "default" : "outline"} onClick={() => setMode("bank")}>Pick from past questions</Button>
          </div>
          {mode === "write" ? <WriteQuestion challengeId={challengeId} onDone={() => router.refresh()} /> : null}
          {mode === "bank" ? <Bank pending={pending} onPick={(qid) => run(addFromBank(challengeId, qid))} /> : null}
          <p className="text-xs text-muted-foreground">For cash prizes, new questions are best: past questions can be looked up during the challenge.</p>
        </>
      )}
    </div>
  );
}

function WriteQuestion({ challengeId, onDone }: { challengeId: string; onDone: () => void }) {
  const [pending, start] = useTransition();
  const empty = { body: "", A: "", B: "", C: "", D: "", answer: "", explanation: "" };
  const [v, setV] = useState(empty);
  const set = (k: keyof typeof v) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setV({ ...v, [k]: e.target.value });
  return (
    <form className="space-y-3 rounded-xl bg-surface-alt p-3" action={(f) => start(async () => {
      f.set("challenge_id", challengeId);
      const r = await addQuestion(f);
      if (r.ok) { toast.success(r.message ?? "Added"); setV(empty); onDone(); } else toast.error(r.error);
    })}>
      <div className="space-y-1.5"><Label htmlFor="wqBody">Question</Label>
        <textarea id="wqBody" name="body" value={v.body} onChange={set("body")} required rows={3} maxLength={4000} placeholder="For maths use $...$" className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" /></div>
      <div className="grid gap-2 sm:grid-cols-2">
        {(["A", "B", "C", "D"] as const).map((k) => (
          <div key={k} className="space-y-1"><Label htmlFor={`wq${k}`}>Option {k}</Label><input id={`wq${k}`} name={k} value={v[k]} onChange={set(k)} required maxLength={500} className={inputCls} /></div>
        ))}
        <div className="space-y-1"><Label htmlFor="wqAns">Correct answer</Label>
          <select id="wqAns" name="answer" value={v.answer} onChange={set("answer")} required className={inputCls}><option value="">Choose…</option><option>A</option><option>B</option><option>C</option><option>D</option></select></div>
      </div>
      <div className="space-y-1.5"><Label htmlFor="wqExp">Explanation (optional, for later)</Label>
        <textarea id="wqExp" name="explanation" value={v.explanation} onChange={set("explanation")} rows={2} maxLength={8000} className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" /></div>
      {v.body ? <div className="rounded-xl border bg-card p-3 text-sm"><span className="text-xs font-bold text-muted-foreground">Preview</span><p className="mt-1"><MathText text={v.body} /></p></div> : null}
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Add question</Button></div>
    </form>
  );
}

function Bank({ pending, onPick }: { pending: boolean; onPick: (id: string) => void }) {
  const [q, setQ] = useState("");
  const [list, setList] = useState<Candidate[] | null>(null);
  const [busy, start] = useTransition();
  const find = () => start(async () => { const r = await findQuestions(q, null); if (r.ok) setList(r.data ?? []); else toast.error(r.error); });
  return (
    <div className="space-y-2 rounded-xl bg-surface-alt p-3">
      <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); find(); }}>
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Words in the question (or leave empty)" aria-label="Search questions" className={`${inputCls} flex-1`} />
        <Button type="submit" variant="outline" disabled={busy}>{busy ? <SpinnerGap size={16} className="animate-spin" /> : <MagnifyingGlass size={16} />} Find</Button>
      </form>
      <p className="text-xs text-muted-foreground">Only questions from years Free students can open are listed, so nothing locked reaches Free students.</p>
      {list ? (
        <ul className="max-h-72 divide-y overflow-auto rounded-lg border bg-card">{list.map((c) => (
          <li key={c.id} className="flex items-start gap-3 px-3 py-2 text-sm">
            <div className="min-w-0 flex-1"><p className="line-clamp-2">{c.body}</p><span className="text-xs text-muted-foreground">{c.exam} {c.year} · {c.subject}</span></div>
            <Button size="sm" disabled={pending} onClick={() => onPick(c.id)}>Add</Button>
          </li>
        ))}</ul>
      ) : null}
    </div>
  );
}

const secs = (ms: number) => { const s = Math.round(ms / 1000); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; };

export function EntriesList({ challengeId, rows, canReview, closed }: { challengeId: string; rows: EntryRow[]; canReview: boolean; closed: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const act = (id: string, d: "ok" | "dq" | "reinstate") => start(async () => {
    const r = await reviewEntry(challengeId, id, d); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
  });
  if (!rows.length) return <p className="px-5 py-6 text-sm text-muted-foreground">Nobody has played yet.</p>;
  return (
    <ul className="divide-y">
      {rows.map((e) => (
        <li key={e.id} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm">
          <span className="w-10 text-center font-bold tabular-nums">{e.rank ? `#${e.rank}` : "–"}</span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><b>{e.name || "No name"}</b>{e.state ? <span className="text-muted-foreground">{e.state}</span> : null}
              {e.status === "disqualified" ? <Pill tone="error">Disqualified</Pill> : e.status === "playing" ? <Pill tone="info">Playing</Pill> : null}
              {e.review === "dq" ? <Pill tone="error">You disqualified</Pill> : e.review === "ok" ? <Pill tone="ok">Checked: fair</Pill> : null}
              {e.prize ? <Pill tone="warn">₦{e.prize.toLocaleString("en-NG")}{e.claim ? ` · claim ${e.claim}` : " · no claim yet"}</Pill> : null}</div>
            <span className="text-muted-foreground"><b className="tabular-nums text-foreground">{e.score}</b> right of {e.answered} · {secs(e.time_ms)} · left the screen {e.exits}× · started {when(e.started_at)}</span>
            {e.dq_reason ? <span className="block text-xs text-error">{e.dq_reason}</span> : null}
            {e.flags?.length ? <span className="block text-xs text-warning">Check: {e.flags.join(" · ")}</span> : null}
          </div>
          {canReview && e.status !== "playing" ? (
            <div className="flex gap-1">
              {e.status === "disqualified" ? <Button size="sm" variant="outline" disabled={pending} onClick={() => act(e.id, "reinstate")}>Reinstate</Button> : (
                <>
                  {e.review !== "ok" ? <Button size="sm" variant="outline" disabled={pending} onClick={() => act(e.id, "ok")}>Fair</Button> : null}
                  {e.review !== "dq" ? <Button size="sm" variant="ghost" disabled={pending || (!!e.claim && e.claim === "paid")} onClick={() => { if (confirm(closed ? "Disqualify and rank again? Prizes move to the next students (paid ones stay)." : "Disqualify this entry?")) act(e.id, "dq"); }}>Disqualify</Button> : null}
                </>
              )}
            </div>
          ) : null}
        </li>
      ))}
    </ul>
  );
}
