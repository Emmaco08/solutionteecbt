"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { MagnifyingGlass, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { Pill } from "@/components/admin/ui";
import { clearDay, findQuestions, scheduleQuestion, type Candidate } from "./actions";

export type QotdDay = {
  day: string; id: string; source: "admin" | "auto"; question_id: string; body: string; exam: string; subject: string;
  year: number; answer: string; answers: number; right: number;
};

const label = (d: string) => new Date(d + "T12:00:00Z").toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });

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
            {row ? <Pill tone={row.source === "admin" ? "info" : "neutral"}>{row.source === "admin" ? "Chosen" : "Automatic"}</Pill> : <Pill>Automatic</Pill>}
            {row && row.answers > 0 ? <span className="text-xs text-muted-foreground">{row.answers} answered · {Math.round((100 * row.right) / row.answers)}% right</span> : null}
            <span className="flex-1" />
            {!row || row.answers === 0 ? <Button variant="outline" size="sm" onClick={() => setOpen(open === day ? null : day)}>{row ? "Change" : "Choose"}</Button> : null}
            {row && row.source === "admin" && row.answers === 0 ? <Button variant="ghost" size="sm" disabled={pending} onClick={() => run(clearDay(day))}>Automatic</Button> : null}
          </div>
          {row ? <p className="mt-1 line-clamp-2 text-muted-foreground">{row.body} <span className="text-xs">({row.exam} {row.year} · {row.subject} · answer {row.answer})</span></p>
            : <p className="mt-1 text-xs text-muted-foreground">Picked automatically on the day from Free years.</p>}
          {open === day ? <Picker subjects={subjects} pending={pending} onPick={(q) => run(scheduleQuestion(day, q))} /> : null}
        </li>
      ))}
    </ul>
  );
}

function Picker({ subjects, pending, onPick }: { subjects: { id: number; name: string }[]; pending: boolean; onPick: (id: string) => void }) {
  const [q, setQ] = useState("");
  const [subject, setSubject] = useState("");
  const [list, setList] = useState<Candidate[] | null>(null);
  const [busy, start] = useTransition();
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
      <p className="text-xs text-muted-foreground">Only published questions from years Free students can open, without a reading passage, so every student can answer.</p>
      {list ? (list.length ? (
        <ul className="max-h-80 divide-y overflow-auto rounded-lg border bg-card">
          {list.map((c) => (
            <li key={c.id} className="flex items-start gap-3 px-3 py-2">
              <div className="min-w-0 flex-1"><p className="line-clamp-2">{c.body}</p>
                <span className="text-xs text-muted-foreground">{c.exam} {c.year}{c.number ? ` · Q${c.number}` : ""} · {c.subject}{c.used ? ` · used ${label(c.used)}` : ""}</span></div>
              <Button size="sm" disabled={pending} onClick={() => onPick(c.id)}>Use</Button>
            </li>
          ))}
        </ul>
      ) : <p className="text-sm text-muted-foreground">No questions found. Try other words or All subjects.</p>) : null}
    </div>
  );
}
