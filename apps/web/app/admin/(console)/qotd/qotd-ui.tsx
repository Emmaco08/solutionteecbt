"use client";
import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { MagnifyingGlass, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { MathText } from "@/components/admin/math-text";
import { Pill } from "@/components/admin/ui";
import { clearDay, findQuestions, saveNotify, saveOwnQuestion, scheduleQuestion, type Candidate } from "./actions";

export type QotdDay = {
  day: string; id: string; source: "admin" | "auto" | "own"; question_id: string | null; subject_id: number | null; subject: string;
  body: string; exam: string | null; year: number | null; answer: string; answers: number; right: number; choices: Record<string, number>;
};
export type Stats = {
  today: { answers: number; right: number }; period: { answers: number; right: number; students: number };
  all_time_students: number; streak3: number;
  by_day: { day: string; answers: number; right: number }[]; by_subject: { subject: string; answers: number; right: number }[];
};
type Subject = { id: number; name: string };

const label = (d: string) => new Date(d + "T12:00:00Z").toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
const pct = (r: number, n: number) => (n ? Math.round((100 * r) / n) : 0);

export function Analysis({ stats }: { stats: Stats }) {
  const max = Math.max(1, ...stats.by_day.map((d) => d.answers));
  const card = (t: string, v: string, sub?: string) => (
    <div className="rounded-xl border bg-card p-3"><span className="text-xs text-muted-foreground">{t}</span><b className="block text-2xl tabular-nums">{v}</b>{sub ? <span className="text-xs text-muted-foreground">{sub}</span> : null}</div>
  );
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        {card("Answered today", String(stats.today.answers), `${pct(stats.today.right, stats.today.answers)}% right`)}
        {card("Answers (14 days)", String(stats.period.answers), `${pct(stats.period.right, stats.period.answers)}% right`)}
        {card("Students (14 days)", String(stats.period.students))}
        {card("Students ever", String(stats.all_time_students))}
        {card("3-day streak now", String(stats.streak3), "answered the last 3 days")}
      </div>
      <div>
        <span className="text-xs font-bold text-muted-foreground">Answers per day (green = right)</span>
        <div className="mt-2 flex h-32 items-end gap-1" role="img" aria-label="Answers per day">
          {stats.by_day.map((d) => (
            <div key={d.day} className="flex flex-1 flex-col items-center gap-1" title={`${label(d.day)}: ${d.answers} answered, ${pct(d.right, d.answers)}% right`}>
              <div className="flex w-full flex-col justify-end overflow-hidden rounded-t bg-surface-alt" style={{ height: `${Math.max(4, (100 * d.answers) / max)}%` }}>
                <div className="bg-success" style={{ height: `${pct(d.right, d.answers)}%` }} />
              </div>
              <span className="text-[10px] text-muted-foreground">{d.day.slice(8)}</span>
            </div>
          ))}
        </div>
      </div>
      {stats.by_subject.length ? (
        <table className="w-full text-sm">
          <thead><tr className="text-left text-xs text-muted-foreground"><th className="py-1">Subject</th><th>Answers</th><th>% right</th></tr></thead>
          <tbody>{stats.by_subject.map((s) => (
            <tr key={s.subject} className="border-t"><td className="py-1.5">{s.subject}</td><td className="tabular-nums">{s.answers}</td><td className="tabular-nums">{pct(s.right, s.answers)}%</td></tr>
          ))}</tbody>
        </table>
      ) : <p className="text-sm text-muted-foreground">No answers yet in the last 14 days.</p>}
    </div>
  );
}

/** Day × subject list: what each subject gets that day and how students answered. */
export function DayGrid({ days, rows, subjects, today, editable = false }: { days: string[]; rows: QotdDay[]; subjects: Subject[]; today: string; editable?: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <ul className="divide-y">
      {days.map((day) => {
        const dayRows = rows.filter((r) => r.day === day);
        if (!editable && !dayRows.length) return null;
        const total = dayRows.reduce((t, r) => t + r.answers, 0), right = dayRows.reduce((t, r) => t + r.right, 0);
        return (
          <li key={day} className="px-5 py-3 text-sm">
            <div className="flex items-center justify-between"><b>{day === today ? "Today" : label(day)}</b>
              {total ? <span className="text-xs text-muted-foreground">{total} answered · {pct(right, total)}% right</span> : null}</div>
            <ul className="mt-2 space-y-1.5">
              {(editable ? subjects.map((s) => ({ s, r: dayRows.find((x) => x.subject_id === s.id) ?? null })) : dayRows.map((r) => ({ s: { id: r.subject_id ?? 0, name: r.subject }, r }))).map(({ s, r }) => (
                <li key={s.id} className="rounded-lg bg-surface-alt px-3 py-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <b className="text-xs">{s.name}</b>
                    {r ? <Pill tone={r.source === "auto" ? "neutral" : "info"}>{r.source === "own" ? "Your question" : r.source === "admin" ? "Chosen" : "Automatic"}</Pill>
                      : <Pill>Automatic (picked when a student opens it)</Pill>}
                    {r && r.answers ? <span className="text-xs text-muted-foreground">{r.answers} answered · {pct(r.right, r.answers)}% right · picked {["A", "B", "C", "D", "E"].filter((k) => r.choices?.[k]).map((k) => `${k} ${r.choices[k]}`).join(", ")}</span> : null}
                    <span className="flex-1" />
                    {editable && r && r.source !== "auto" && r.answers === 0 ? (
                      <Button size="sm" variant="ghost" disabled={pending} onClick={() => start(async () => {
                        const x = await clearDay(day, s.id); if (x.ok) { toast.success(x.message ?? "Done"); router.refresh(); } else toast.error(x.error);
                      })}>Make automatic</Button>
                    ) : null}
                  </div>
                  {r ? <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">{r.body} {r.exam ? `(${r.exam} ${r.year} · answer ${r.answer})` : `(answer ${r.answer})`}</p> : null}
                </li>
              ))}
            </ul>
          </li>
        );
      })}
    </ul>
  );
}

/** 1) day, 2) subject, 3) write your own or pick a past question. */
export function AddPanel({ today, subjects }: { today: string; subjects: Subject[] }) {
  const router = useRouter();
  const tomorrow = new Date(new Date(today + "T12:00:00Z").getTime() + 86400_000).toISOString().slice(0, 10);
  const max = new Date(new Date(today + "T12:00:00Z").getTime() + 60 * 86400_000).toISOString().slice(0, 10);
  const [day, setDay] = useState(tomorrow);
  const [subject, setSubject] = useState<number>(subjects[0]?.id ?? 0);
  const [mode, setMode] = useState<"own" | "bank">("own");
  const [pending, start] = useTransition();
  const dayName = day === today ? "today" : label(day);
  const subjectName = subjects.find((s) => s.id === subject)?.name ?? "";
  return (
    <div className="space-y-5">
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><b className="text-sm">1. Day</b>
          <input type="date" value={day} min={today} max={max} onChange={(e) => setDay(e.target.value)} className={inputCls} aria-label="Day" /></div>
        <div className="space-y-1.5"><b className="text-sm">2. Subject</b>
          <select value={subject} onChange={(e) => setSubject(Number(e.target.value))} className={inputCls} aria-label="Subject">
            {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select></div>
      </div>
      <p className="text-xs text-muted-foreground">Students who take {subjectName || "this subject"} may get this question on {dayName}. Set one for every subject to choose all of them yourself.</p>
      <div className="space-y-2">
        <b className="text-sm">3. The question</b>
        <div className="flex flex-wrap gap-2">
          <Button type="button" size="sm" variant={mode === "own" ? "default" : "outline"} onClick={() => setMode("own")}>Write my own question</Button>
          <Button type="button" size="sm" variant={mode === "bank" ? "default" : "outline"} onClick={() => setMode("bank")}>Pick from past questions</Button>
        </div>
        {mode === "own" ? <OwnForm key={`${day}-${subject}`} day={day} subjectId={subject} label={`${subjectName}, ${dayName}`} /> : (
          <Picker key={subject} subject={subject} pending={pending} useLabel={`Use for ${subjectName}, ${dayName}`} onPick={(q) => start(async () => {
            const r = await scheduleQuestion(day, subject, q);
            if (r.ok) { toast.success(`Saved for ${subjectName}, ${dayName}.`); router.refresh(); } else toast.error(r.error);
          })} />
        )}
      </div>
    </div>
  );
}

function OwnForm({ day, subjectId, label: where }: { day: string; subjectId: number; label: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const empty = { body: "", A: "", B: "", C: "", D: "", E: "", answer: "", explanation: "" };
  const [v, setV] = useState(empty);
  const set = (k: keyof typeof v) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setV({ ...v, [k]: e.target.value });
  const area = "w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm";
  return (
    <form className="space-y-3 rounded-xl bg-surface-alt p-3" action={(f) => start(async () => {
      f.set("day", day); f.set("subject_id", String(subjectId));
      const r = await saveOwnQuestion(f);
      if (r.ok) { toast.success(`Saved for ${where}.`); setV(empty); router.refresh(); } else toast.error(r.error);
    })}>
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
        <textarea id="oExp" name="explanation" value={v.explanation} onChange={set("explanation")} rows={3} maxLength={8000} className={area} /></div>
      {v.body ? (
        <div className="rounded-xl border bg-card p-3 text-sm">
          <span className="text-xs font-bold text-muted-foreground">Preview</span>
          <p className="mt-1"><MathText text={v.body} /></p>
          <ul className="mt-2 space-y-1">{(["A", "B", "C", "D", "E"] as const).filter((k) => v[k]).map((k) => (
            <li key={k} className={v.answer === k ? "font-bold text-success" : ""}>{k}. <MathText text={v[k]} /></li>
          ))}</ul>
        </div>
      ) : null}
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save for {where}</Button></div>
    </form>
  );
}

function Picker({ subject, pending, onPick, useLabel }: { subject: number; pending: boolean; onPick: (id: string) => void; useLabel: string }) {
  const [q, setQ] = useState("");
  const [list, setList] = useState<Candidate[] | null>(null);
  const [busy, start] = useTransition();
  useEffect(() => {
    let live = true;
    findQuestions("", subject).then((r) => { if (live && r.ok) setList(r.data ?? []); });
    return () => { live = false; };
  }, [subject]);
  const search = () => start(async () => { const r = await findQuestions(q, subject); if (r.ok) setList(r.data ?? []); else toast.error(r.error); });
  return (
    <div className="space-y-3 rounded-xl bg-surface-alt p-3">
      <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); search(); }}>
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Words in the question" className={`${inputCls} flex-1`} aria-label="Search questions" />
        <Button type="submit" variant="outline" disabled={busy}>{busy ? <SpinnerGap size={16} className="animate-spin" /> : <MagnifyingGlass size={16} />} Find</Button>
      </form>
      <p className="text-xs text-muted-foreground">Only published questions in this subject, from years Free students can open, without a reading passage.</p>
      {list ? (list.length ? (
        <ul className="max-h-80 divide-y overflow-auto rounded-lg border bg-card">
          {list.map((c) => (
            <li key={c.id} className="flex items-start gap-3 px-3 py-2">
              <div className="min-w-0 flex-1"><p className="line-clamp-2">{c.body}</p>
                <span className="text-xs text-muted-foreground">{c.exam} {c.year}{c.number ? ` · Q${c.number}` : ""}{c.used ? ` · used ${label(c.used)}` : ""}</span></div>
              <Button size="sm" disabled={pending} onClick={() => onPick(c.id)}>{useLabel}</Button>
            </li>
          ))}
        </ul>
      ) : <p className="text-sm text-muted-foreground">No past questions in this subject yet. Write your own instead.</p>) : null}
    </div>
  );
}

export function NotifyForm({ notify, hour }: { notify: boolean; hour: number }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form className="flex flex-wrap items-end gap-3" action={(f) => start(async () => {
      const r = await saveNotify(f); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
    })}>
      <div className="space-y-1"><Label htmlFor="nHour">New question every day at (Lagos time)</Label>
        <select id="nHour" name="drop_hour" defaultValue={hour} className={`${inputCls} w-auto`}>
          {Array.from({ length: 24 }, (_, h) => <option key={h} value={h}>{String(h).padStart(2, "0")}:00</option>)}
        </select></div>
      <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="notify" defaultChecked={notify} /> Send “Your question of the day is ready” at that time</label>
      <Button type="submit" disabled={pending}>Save</Button>
      <p className="w-full text-xs text-muted-foreground">Until then students see the day before&apos;s question. The notification arrives within a few minutes. Students who switched off “New questions added” in Settings do not get it.</p>
    </form>
  );
}
