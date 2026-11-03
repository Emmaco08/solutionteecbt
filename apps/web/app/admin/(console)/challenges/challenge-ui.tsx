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
import { addFromBank, addQuestion, addRandom, closeNow, decideAppeal, importQuestions, removeQuestion, reviewEntry, saveChallenge, setLevel, type ImportRow } from "./actions";

export type ChallengeRow = {
  id: string; title: string; subtitle: string | null; kind: "cash" | "event" | "practice"; icon: string; exam_code: string | null;
  starts_at: string; ends_at: string; seconds_per_question: number; prizes: number[]; reward_text: string | null;
  premium_days: number; premium_top: number; allowed_exits: number; published: boolean; closed_at: string | null;
  mode: "mixed" | "subject" | "fixed"; subject_id: number | null; per_level: Record<string, number>; same_questions: boolean; allow_review: boolean;
};
export type QRow = { id: string; position: number; body: string; options: Record<string, string>; answer: string; subject_id: number | null; difficulty: string };
export type Subject = { id: number; name: string };
export type AppealRow = { id: string; status: string; reason: string; image: string | null; note: string | null; created_at: string; challenge: string; challenge_id: string; name: string | null; dq_reason: string | null; answered: number; exits: number };
export const LEVELS: [string, string][] = [["easy", "Easy"], ["medium", "Medium"], ["hard", "Hard"], ["very_hard", "Very hard"]];
export type EntryRow = {
  id: string; name: string | null; state: string | null; status: string; score: number; answered: number; time_ms: number; exits: number;
  dq_reason: string | null; flags: string[]; review: string | null; rank: number | null; prize: number | null; started_at: string; claim: string | null;
};

/** ISO → "YYYY-MM-DDTHH:mm" in Lagos time (UTC+1) for datetime-local inputs. */
const toLocal = (iso?: string) => (iso ? new Date(Date.parse(iso) + 3600_000).toISOString().slice(0, 16) : "");
const ICONS = [["trophy", "Trophy"], ["function", "Maths"], ["atom", "Physics"], ["book-open-text", "English"], ["flask", "Chemistry"], ["globe", "Geography"], ["lightning", "Speed"], ["star", "Star"]];

export function ChallengeForm({ c, subjects }: { c?: ChallengeRow; subjects: Subject[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [kind, setKind] = useState(c?.kind ?? "cash");
  const [mode, setMode] = useState<ChallengeRow["mode"]>(c?.mode ?? "mixed");
  const pl = c?.per_level ?? { easy: 3, medium: 3, hard: 3, very_hard: 1 };
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
        <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="cMode">Who plays and which questions</Label>
          <select id="cMode" name="mode" value={mode} onChange={(e) => setMode(e.target.value as ChallengeRow["mode"])} className={inputCls}>
            <option value="mixed">Weekly mixed: each student&apos;s own 4 JAMB subjects</option>
            <option value="subject">One subject: only students who take it see it</option>
            <option value="fixed">One list for everyone (any subjects)</option>
          </select></div>
        {mode === "subject" ? (
          <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="cSubj">Subject</Label>
            <select id="cSubj" name="subject_id" defaultValue={c?.subject_id ?? subjects[0]?.id} className={inputCls}>{subjects.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}</select></div>
        ) : <input type="hidden" name="subject_id" value={0} />}
        {mode !== "fixed" ? (
          <div className="space-y-1.5 sm:col-span-2"><Label>Questions per subject at each level (every student gets the same mix)</Label>
            <div className="grid grid-cols-4 gap-2">{LEVELS.map(([k, l]) => (
              <label key={k} className="text-xs text-muted-foreground">{l}
                <input name={k} type="number" min={0} max={50} defaultValue={pl[k] ?? 0} className={inputCls} /></label>
            ))}</div>
            <span className="text-xs text-muted-foreground">{mode === "mixed" ? "A student with 4 subjects gets 4 × this. " : ""}Add many more questions than this to each subject and level, so students get different questions.</span></div>
        ) : LEVELS.map(([k]) => <input key={k} type="hidden" name={k} value={0} />)}
        {mode !== "fixed" ? (
          <label className="flex items-start gap-3 text-sm sm:col-span-2"><input type="checkbox" name="same_questions" defaultChecked={c?.same_questions ?? false} className="mt-1" />
            <span><b>Same questions for every student</b><span className="block text-muted-foreground">Everyone who takes a subject gets the same questions for it, in a different order. Leave it off to give each student random questions from the pool (harder to copy).</span></span></label>
        ) : null}
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

export function QuestionsPanel({ challengeId, rows, locked, subjects, mode, perLevel, subjectId, students = {} }: { challengeId: string; rows: QRow[]; locked: boolean; subjects: Subject[]; mode: ChallengeRow["mode"]; perLevel: Record<string, number>; subjectId: number | null; students?: Record<string, number> }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [add, setAdd] = useState<"none" | "write" | "bank" | "csv" | "random">(rows.length ? "none" : "random");
  const [show, setShow] = useState(false);
  const name = (id: number | null) => subjects.find((x) => x.id === id)?.name ?? "No subject";
  const run = (p: Promise<{ ok: boolean; message?: string; error?: string }>) => start(async () => {
    const r = await p; if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error);
  });
  return (
    <div className="space-y-4">
      {mode !== "fixed" ? (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead><tr className="text-left text-xs text-muted-foreground"><th className="py-1">Subject</th><th>Students</th>{LEVELS.map(([k, l]) => <th key={k}>{l} ({perLevel[k] ?? 0} each)</th>)}</tr></thead>
            <tbody>{(mode === "subject" ? subjects.filter((x) => x.id === subjectId) : subjects).map((x) => {
              const have = (lvl: string) => rows.filter((r) => r.subject_id === x.id && r.difficulty === lvl).length;
              return (
                <tr key={x.id} className="border-t"><td className="py-1.5">{x.name}</td><td className="tabular-nums text-muted-foreground">{students[String(x.id)] ?? 0}</td>{LEVELS.map(([k]) => {
                  const n = have(k), need = perLevel[k] ?? 0;
                  return <td key={k} className={`tabular-nums ${need && n < need ? "font-bold text-error" : need && n < need * 3 ? "text-warning" : ""}`}>{n}</td>;
                })}</tr>
              );
            })}</tbody>
          </table>
          <p className="mt-1 text-xs text-muted-foreground">Students: how many students take that subject. Red: fewer than a paper needs. Amber: fewer than 3 × needed, so many students would get the same questions. Aim for 5 × or more.</p>
        </div>
      ) : null}
      {rows.length ? (
        <div>
          <Button type="button" size="sm" variant="ghost" onClick={() => setShow(!show)}>{show ? "Hide" : "Show"} all {rows.length} questions</Button>
          {show ? (
            <ol className="mt-2 max-h-[28rem] space-y-2 overflow-auto">{rows.map((q, i) => (
              <li key={q.id} className="flex gap-3 rounded-xl border p-3 text-sm">
                <b className="w-6 tabular-nums">{i + 1}.</b>
                <div className="min-w-0 flex-1"><MathText text={q.body} />
                  <span className="mt-1 flex flex-wrap items-center gap-1 text-xs text-muted-foreground">{name(q.subject_id)} ·{" "}
                    {locked ? LEVELS.find(([k]) => k === q.difficulty)?.[1] : (
                      <select aria-label="Level" value={q.difficulty} disabled={pending} onChange={(e) => run(setLevel(challengeId, q.id, e.target.value))} className="rounded-md border bg-card px-1 py-0.5 text-xs">
                        {LEVELS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select>
                    )} · answer {q.answer}: <MathText text={q.options[q.answer] ?? ""} /></span></div>
                {!locked ? <Button variant="ghost" size="icon" aria-label="Remove question" disabled={pending} onClick={() => run(removeQuestion(challengeId, q.id))}><Trash size={16} /></Button> : null}
              </li>
            ))}</ol>
          ) : null}
        </div>
      ) : <p className="text-sm text-muted-foreground">No questions yet. Add them by subject and level, one by one or from a CSV file.</p>}
      {locked ? <p className="text-xs text-muted-foreground">Students have started, so the questions cannot change.</p> : (
        <>
          <div className="flex flex-wrap gap-2">
            <Button type="button" size="sm" variant={add === "random" ? "default" : "outline"} onClick={() => setAdd("random")}>Add random past questions</Button>
            <Button type="button" size="sm" variant={add === "write" ? "default" : "outline"} onClick={() => setAdd("write")}>Write a new question</Button>
            <Button type="button" size="sm" variant={add === "csv" ? "default" : "outline"} onClick={() => setAdd("csv")}>Import a CSV file</Button>
            <Button type="button" size="sm" variant={add === "bank" ? "default" : "outline"} onClick={() => setAdd("bank")}>Pick from past questions</Button>
          </div>
          {add === "random" ? <RandomPast challengeId={challengeId} subjects={mode === "subject" ? subjects.filter((x) => x.id === subjectId) : subjects} single={mode === "subject"} onDone={() => router.refresh()} /> : null}
          {add === "write" ? <WriteQuestion challengeId={challengeId} subjects={subjects} onDone={() => router.refresh()} /> : null}
          {add === "csv" ? <CsvImport challengeId={challengeId} onDone={() => router.refresh()} /> : null}
          {add === "bank" ? <Bank pending={pending} onPick={(qid) => run(addFromBank(challengeId, qid))} /> : null}
          <p className="text-xs text-muted-foreground">For cash prizes, new questions are best: past questions can be looked up during the challenge.</p>
        </>
      )}
    </div>
  );
}

/** Pick random past questions by subject: the server copies them (Free years only) and gives each a level. */
function RandomPast({ challengeId, subjects, single, onDone }: { challengeId: string; subjects: Subject[]; single: boolean; onDone: () => void }) {
  const [pending, start] = useTransition();
  const [picked, setPicked] = useState<number[]>(subjects.map((x) => x.id));
  const [count, setCount] = useState(40);
  const [result, setResult] = useState<{ subject: string; added: number; left: number }[] | null>(null);
  const toggle = (id: number) => setPicked(picked.includes(id) ? picked.filter((x) => x !== id) : [...picked, id]);
  return (
    <div className="space-y-3 rounded-xl bg-surface-alt p-3 text-sm">
      <p className="text-muted-foreground">We pick random published past questions for each subject and set each one&apos;s level (its saved level, or from how students did on it). Only years Free students can open are used, so nothing locked reaches Free students. Change any level in the list after.</p>
      {!single ? (
        <div className="flex flex-wrap gap-2">
          <Button type="button" size="sm" variant="ghost" onClick={() => setPicked(picked.length === subjects.length ? [] : subjects.map((x) => x.id))}>{picked.length === subjects.length ? "Clear all" : "All JAMB subjects"}</Button>
          {subjects.map((x) => (
            <label key={x.id} className={`flex cursor-pointer items-center gap-1.5 rounded-full border px-3 py-1 text-xs ${picked.includes(x.id) ? "border-secondary bg-secondary/10 font-semibold" : ""}`}>
              <input type="checkbox" className="sr-only" checked={picked.includes(x.id)} onChange={() => toggle(x.id)} />{x.name}</label>
          ))}
        </div>
      ) : <p><b>{subjects[0]?.name}</b></p>}
      <div className="flex flex-wrap items-end gap-2">
        <label className="text-xs text-muted-foreground">How many per subject
          <input type="number" min={1} max={500} value={count} onChange={(e) => setCount(Number(e.target.value))} className={`${inputCls} w-32`} /></label>
        <Button type="button" disabled={pending || !picked.length} onClick={() => start(async () => {
          const r = await addRandom(challengeId, picked, count);
          if (r.ok) { toast.success(r.message ?? "Added"); setResult(r.data ?? null); onDone(); } else toast.error(r.error);
        })}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Add random questions</Button>
      </div>
      {result ? (
        <ul className="space-y-0.5 text-xs">{result.map((r) => (
          <li key={r.subject}><b>{r.subject}</b>: {r.added} added{r.left === 0 ? " · no more Free past questions in this subject" : ` · ${r.left} more available`}</li>
        ))}</ul>
      ) : null}
    </div>
  );
}

function WriteQuestion({ challengeId, subjects, onDone }: { challengeId: string; subjects: Subject[]; onDone: () => void }) {
  const [pending, start] = useTransition();
  const [subject, setSubject] = useState(String(subjects[0]?.id ?? 0));
  const [level, setLevel] = useState("medium");
  const empty = { body: "", A: "", B: "", C: "", D: "", answer: "", explanation: "" };
  const [v, setV] = useState(empty);
  const set = (k: keyof typeof v) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setV({ ...v, [k]: e.target.value });
  return (
    <form className="space-y-3 rounded-xl bg-surface-alt p-3" action={(f) => start(async () => {
      f.set("challenge_id", challengeId); f.set("subject_id", subject); f.set("difficulty", level);
      const r = await addQuestion(f);
      if (r.ok) { toast.success(r.message ?? "Added"); setV(empty); onDone(); } else toast.error(r.error);
    })}>
      <div className="grid gap-2 sm:grid-cols-2">
        <div className="space-y-1"><Label htmlFor="wqSub">Subject</Label>
          <select id="wqSub" value={subject} onChange={(e) => setSubject(e.target.value)} className={inputCls}>{subjects.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}</select></div>
        <div className="space-y-1"><Label htmlFor="wqLvl">Difficulty</Label>
          <select id="wqLvl" value={level} onChange={(e) => setLevel(e.target.value)} className={inputCls}>{LEVELS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></div>
      </div>
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

/** Reads a CSV file (quotes allowed) into rows keyed by the header, lower-case. */
function parseCsv(text: string): ImportRow[] {
  const out: string[][] = [];
  let row: string[] = [], cell = "", q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (ch === '"') q = false; else cell += ch;
    } else if (ch === '"') q = true;
    else if (ch === ",") { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") { if (ch === "\r" && text[i + 1] === "\n") i++; row.push(cell); cell = ""; if (row.some((x) => x.trim())) out.push(row); row = []; }
    else cell += ch;
  }
  row.push(cell); if (row.some((x) => x.trim())) out.push(row);
  const head = (out.shift() ?? []).map((h) => h.trim().toLowerCase().replace(/\s+/g, "_"));
  return out.map((r) => Object.fromEntries(head.map((h, i) => [h, r[i] ?? ""])));
}

function CsvImport({ challengeId, onDone }: { challengeId: string; onDone: () => void }) {
  const [rows, setRows] = useState<ImportRow[] | null>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [pending, start] = useTransition();
  return (
    <div className="space-y-3 rounded-xl bg-surface-alt p-3 text-sm">
      <p>Columns: <code>subject, difficulty, question, option_a, option_b, option_c, option_d, answer, explanation</code>. Subject is the name or code (e.g. Mathematics or mth); difficulty is easy, medium, hard or very hard; answer is A, B, C or D. Maths can use $...$.</p>
      <a href="/samples/challenge-questions-sample.csv" download className="font-bold text-primary hover:underline">Download the sample CSV</a>
      <input type="file" accept=".csv,text/csv" aria-label="CSV file" className="block text-sm" onChange={async (e) => {
        const f = e.target.files?.[0]; if (!f) return;
        const parsed = parseCsv(await f.text()); setRows(parsed); setErrors([]);
      }} />
      {rows ? (
        <div className="space-y-2">
          <p><b>{rows.length}</b> questions found.{rows[0] ? <> First: “{(rows[0].question ?? "").slice(0, 80)}”</> : null}</p>
          {errors.length ? <ul className="list-disc space-y-0.5 pl-5 text-xs text-error">{errors.map((x) => <li key={x}>{x}</li>)}</ul> : null}
          <Button disabled={pending || !rows.length} onClick={() => start(async () => {
            const r = await importQuestions(challengeId, rows);
            if (!r.ok) { toast.error(r.error); return; }
            if (r.data?.errors.length) { setErrors(r.data.errors); toast.error(r.message ?? "Fix the file"); return; }
            toast.success(r.message ?? "Imported"); setRows(null); onDone();
          })}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Import {rows.length} questions</Button>
        </div>
      ) : null}
    </div>
  );
}

/** Appeals from disqualified students: reason + screenshot; accept reinstates the entry. */
export function AppealsList({ rows }: { rows: AppealRow[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const act = (id: string, accept: boolean) => {
    const note = prompt(accept ? "Message to the student (optional)" : "Why is it rejected? (the student sees this)") ?? "";
    if (!accept && !note) return;
    start(async () => { const r = await decideAppeal(id, accept, note); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error); });
  };
  if (!rows.length) return <p className="px-5 py-6 text-sm text-muted-foreground">No appeals. Disqualified students can send one within 24 hours, with a screenshot.</p>;
  return (
    <ul className="divide-y">
      {rows.map((a) => (
        <li key={a.id} className="flex flex-wrap items-start gap-3 px-5 py-3 text-sm">
          {a.image ? <a href={`/admin/api/image?key=${encodeURIComponent(a.image)}`} target="_blank" rel="noreferrer"><img src={`/admin/api/image?key=${encodeURIComponent(a.image)}`} alt="Screenshot from the student" className="size-20 rounded-lg border object-cover" /></a> : null}
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><b>{a.name || "No name"}</b><span className="text-muted-foreground">{a.challenge}</span>
              <Pill tone={a.status === "pending" ? "warn" : a.status === "accepted" ? "ok" : "neutral"}>{a.status === "pending" ? "Waiting" : a.status === "accepted" ? "Accepted" : "Rejected"}</Pill></div>
            <p className="mt-1">“{a.reason}”</p>
            <span className="text-xs text-muted-foreground">Disqualified: {a.dq_reason} · after {a.answered} answers · {when(a.created_at)}</span>
            {a.note ? <span className="block text-xs text-muted-foreground">Your note: {a.note}</span> : null}
          </div>
          {a.status === "pending" ? (
            <div className="flex gap-1"><Button size="sm" disabled={pending} onClick={() => act(a.id, true)}>Accept</Button><Button size="sm" variant="ghost" disabled={pending} onClick={() => act(a.id, false)}>Reject</Button></div>
          ) : null}
        </li>
      ))}
    </ul>
  );
}
