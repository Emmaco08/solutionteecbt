"use client";
import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { MagnifyingGlass, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { Pill } from "@/components/admin/ui";
import { clearDay, findQuestions, saveOwnQuestion, scheduleQuestion, type Candidate } from "./actions";
import { Label } from "@/components/ui/label";
import { MathText } from "@/components/admin/math-text";

export type QotdDay = {
  day: string; id: string; source: "admin" | "auto" | "own"; question_id: string | null; body: string; exam: string; subject: string;
  year: number; answer: string; answers: number; right: number;
};

const label = (d: string) => new Date(d + "T12:00:00Z").toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });

/** The main way to add one: 1) pick a day, 2) write your own question or pick one from the bank. */
export function AddPanel({ today, subjects }: { today: string; subjects: { id: number; name: string }[] }) {
  const router = useRouter();
  const tomorrow = new Date(new Date(today + "T12:00:00Z").getTime() + 86400_000).toISOString().slice(0, 10);
  const max = new Date(new Date(today + "T12:00:00Z").getTime() + 60 * 86400_000).toISOString().slice(0, 10);
  const [day, setDay] = useState(tomorrow);
  const [mode, setMode] = useState<"own" | "bank">("own");
  const [pending, start] = useTransition();
  const dayName = day === today ? "today" : label(day);
  return (
    <div className="space-y-5">
      <div className="space-y-1.5">
        <b className="text-sm">1. Choose the day</b>
        <input type="date" value={day} min={today} max={max} onChange={(e) => setDay(e.target.value)} className={`${inputCls} w-auto`} aria-label="Day" />
        <span className="block text-xs text-muted-foreground">{day === today ? "Today" : label(day)}. The question changes at midnight Lagos time.</span>
      </div>
      <div className="space-y-2">
        <b className="text-sm">2. Add the question</b>
        <div className="flex flex-wrap gap-2" role="tablist">
          <Button type="button" size="sm" variant={mode === "own" ? "default" : "outline"} onClick={() => setMode("own")}>Write my own question</Button>
          <Button type="button" size="sm" variant={mode === "bank" ? "default" : "outline"} onClick={() => setMode("bank")}>Pick from past questions</Button>
        </div>
        {mode === "own" ? <OwnForm day={day} dayName={dayName} /> : (
          <Picker subjects={subjects} pending={pending} useLabel={`Use for ${dayName}`} onPick={(q) => start(async () => {
            const r = await scheduleQuestion(day, q);
            if (r.ok) { toast.success(`Scheduled for ${dayName}.`); router.refresh(); } else toast.error(r.error);
          })} />
        )}
      </div>
    </div>
  );
}

/** Any question the admin likes: subject (optional), question, options A–D (E optional), answer, explanation. LaTeX with $...$. */
function OwnForm({ day, dayName }: { day: string; dayName: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [v, setV] = useState({ subject: "", body: "", A: "", B: "", C: "", D: "", E: "", answer: "", explanation: "" });
  const set = (k: keyof typeof v) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setV({ ...v, [k]: e.target.value });
  const area = "w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm";
  return (
    <form className="space-y-3 rounded-xl bg-surface-alt p-3" action={(f) => start(async () => {
      f.set("day", day);
      const r = await saveOwnQuestion(f);
      if (r.ok) { toast.success(`Saved for ${dayName}.`); setV({ subject: "", body: "", A: "", B: "", C: "", D: "", E: "", answer: "", explanation: "" }); router.refresh(); } else toast.error(r.error);
    })}>
      <div className="space-y-1.5"><Label htmlFor="oSub">Subject or topic (optional)</Label>
        <input id="oSub" name="subject" value={v.subject} onChange={set("subject")} maxLength={60} placeholder="e.g. Mathematics, General knowledge, Current affairs" className={inputCls} /></div>
      <div className="space-y-1.5"><Label htmlFor="oBody">Question</Label>
        <textarea id="oBody" name="body" value={v.body} onChange={set("body")} required rows={3} maxLength={4000} placeholder="Type the question. For maths use $...$, e.g. $x^2 + 2x = 0$" className={area} /></div>
      <div className="grid gap-2 sm:grid-cols-2">
        {(["A", "B", "C", "D", "E"] as const).map((k) => (
          <div key={k} className="space-y-1"><Label htmlFor={`o${k}`}>Option {k}{k === "E" ? " (optional)" : ""}</Label>
            <input id={`o${k}`} name={k} value={v[k]} onChange={set(k)} required={k !== "E"} maxLength={500} className={inputCls} /></div>
        ))}
        <div className="space-y-1"><Label htmlFor="oAns">Correct answer</Label>
          <select id="oAns" name="answer" value={v.answer} onChange={set("answer")} required className={inputCls}>
            <option value="">Choose…</option>{(["A", "B", "C", "D", "E"] as const).filter((k) => k !== "E" || v.E).map((k) => <option key={k} value={k}>{k}</option>)}
          </select></div>
      </div>
      <div className="space-y-1.5"><Label htmlFor="oExp">Explanation (shown after the student answers)</Label>
        <textarea id="oExp" name="explanation" value={v.explanation} onChange={set("explanation")} rows={3} maxLength={8000} placeholder="Why the answer is right. Optional but helpful." className={area} /></div>
      {v.body ? (
        <div className="rounded-xl border bg-card p-3 text-sm">
          <span className="text-xs font-bold text-muted-foreground">Preview</span>
          <p className="mt-1"><MathText text={v.body} /></p>
          <ul className="mt-2 space-y-1">{(["A", "B", "C", "D", "E"] as const).filter((k) => v[k]).map((k) => (
            <li key={k} className={v.answer === k ? "font-bold text-success" : ""}>{k}. <MathText text={v[k]} /></li>
          ))}</ul>
        </div>
      ) : null}
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save for {dayName}</Button></div>
    </form>
  );
}

export function DayList({ days, today, subjects }: { days: { day: string; row: QotdDay | null }[]; today: string; subjects: { id: number; name: string }[] }) {
  const router = useRouter();
  const [open, setOpen] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const run = (p: Promise<{ ok: boolean; message?: string; error?: string }>) => start(async () => {
    const r = await p;
    if (r.ok) { toast.success(r.message ?? "Done"); setOpen(null); router.refresh(); } else toast.error(r.error);
  });
  return (
    <ul className="divide-y">
      {days.map(({ day, row }) => (
        <li key={day} className="px-5 py-3 text-sm">
          <div className="flex flex-wrap items-center gap-2">
            <b className="w-28">{day === today ? "Today" : label(day)}</b>
            {row ? <Pill tone={row.source === "auto" ? "neutral" : "info"}>{row.source === "own" ? "Your question" : row.source === "admin" ? "Chosen" : "Automatic"}</Pill> : <Pill>Automatic</Pill>}
            {row && row.answers > 0 ? <span className="text-xs text-muted-foreground">{row.answers} answered · {Math.round((100 * row.right) / row.answers)}% right</span> : null}
            <span className="flex-1" />
            {!row || row.answers === 0 ? <Button variant="outline" size="sm" onClick={() => setOpen(open === day ? null : day)}>{row ? "Change" : "Choose"}</Button> : null}
            {row && row.source !== "auto" && row.answers === 0 ? <Button variant="ghost" size="sm" disabled={pending} onClick={() => run(clearDay(day))}>Automatic</Button> : null}
          </div>
          {row ? <p className="mt-1 line-clamp-2 text-muted-foreground">{row.body} <span className="text-xs">({row.exam ? `${row.exam} ${row.year} · ` : ""}{row.subject ? `${row.subject} · ` : ""}answer {row.answer})</span></p>
            : <p className="mt-1 text-xs text-muted-foreground">Picked automatically on the day from Free years.</p>}
          {open === day ? <Picker subjects={subjects} pending={pending} onPick={(q) => run(scheduleQuestion(day, q))} /> : null}
        </li>
      ))}
    </ul>
  );
}

function Picker({ subjects, pending, onPick, useLabel = "Use" }: { subjects: { id: number; name: string }[]; pending: boolean; onPick: (id: string) => void; useLabel?: string }) {
  const [q, setQ] = useState("");
  const [subject, setSubject] = useState("");
  const [list, setList] = useState<Candidate[] | null>(null);
  const [busy, start] = useTransition();
  useEffect(() => {
    let live = true;
    findQuestions("", null).then((r) => { if (live && r.ok) setList(r.data ?? []); });
    return () => { live = false; };
  }, []);
  const search = () => start(async () => {
    const r = await findQuestions(q, subject ? Number(subject) : null);
    if (r.ok) setList(r.data ?? []); else toast.error(r.error);
  });
  return (
    <div className="mt-3 space-y-3 rounded-xl bg-surface-alt p-3">
      <form className="flex flex-wrap gap-2" onSubmit={(e) => { e.preventDefault(); search(); }}>
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Words in the question" className={`${inputCls} min-w-40 flex-1`} aria-label="Search questions" />
        <select value={subject} onChange={(e) => setSubject(e.target.value)} className={`${inputCls} w-auto`} aria-label="Subject">
          <option value="">All subjects</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <Button type="submit" variant="outline" disabled={busy}>{busy ? <SpinnerGap size={16} className="animate-spin" /> : <MagnifyingGlass size={16} />} Find</Button>
      </form>
      <p className="text-xs text-muted-foreground">Leave the box empty and tap Find to see all questions you can use. Only published questions from years Free students can open (and without a reading passage) are listed, so every student can answer. To use another question, add it to the Question bank in a Free year first.</p>
      {list ? (list.length ? (
        <ul className="max-h-80 divide-y overflow-auto rounded-lg border bg-card">
          {list.map((c) => (
            <li key={c.id} className="flex items-start gap-3 px-3 py-2">
              <div className="min-w-0 flex-1"><p className="line-clamp-2">{c.body}</p>
                <span className="text-xs text-muted-foreground">{c.exam} {c.year}{c.number ? ` · Q${c.number}` : ""} · {c.subject}{c.used ? ` · used ${label(c.used)}` : ""}</span></div>
              <Button size="sm" disabled={pending} onClick={() => onPick(c.id)}>{useLabel}</Button>
            </li>
          ))}
        </ul>
      ) : <p className="text-sm text-muted-foreground">No questions found. Try other words or All subjects.</p>) : null}
    </div>
  );
}
