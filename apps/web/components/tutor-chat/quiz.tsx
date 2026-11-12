"use client";
import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { toast } from "sonner";
import { Check, Plus, Shuffle, Trash, X } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { cn } from "@/lib/utils";
import type { Chat } from "./lib";

const field = "w-full rounded-xl border bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
const KEYS = ["A", "B", "C", "D"] as const;
type Own = { body: string; options: Record<string, string>; answer: string; explanation: string };
const blank = (): Own => ({ body: "", options: { A: "", B: "", C: "", D: "" }, answer: "A", explanation: "" });

/**
 * Set a quiz for this student (D-154): random past questions from a subject, the tutor's own questions, or both.
 * The student gets a quiz card in the chat and sees it on Home and in Test; answers stay on the server until they submit.
 */
export function QuizDialog({ sb, chat, onClose, onSent }: { sb: SupabaseClient; chat: Chat; onClose: () => void; onSent: () => void }) {
  const [subjects, setSubjects] = useState<{ id: number; name: string }[]>([]);
  const [title, setTitle] = useState("");
  const [note, setNote] = useState("");
  const [minutes, setMinutes] = useState("");
  const [due, setDue] = useState("");
  const [usePq, setUsePq] = useState(true);
  const [subject, setSubject] = useState("");
  const [count, setCount] = useState("10");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [own, setOwn] = useState<Own[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void sb.from("subjects").select("id, name").order("sort").then(({ data }) => {
      const list = (data ?? []) as { id: number; name: string }[];
      setSubjects(list);
      const first = (chat.subject ?? "").split(",")[0]?.trim().toLowerCase();
      const hit = list.find((x) => x.name.toLowerCase() === first);
      if (hit) setSubject(String(hit.id));
      if (!title && hit) setTitle(`${hit.name} practice`);
    });
  }, [sb, chat.subject]); // eslint-disable-line react-hooks/exhaustive-deps

  const edit = (i: number, p: Partial<Own>) => setOwn((o) => o.map((q, j) => (j === i ? { ...q, ...p } : q)));
  const ownOk = own.every((q) => q.body.trim().length >= 2 && Object.values(q.options).filter((v) => v.trim()).length >= 2 && q.options[q.answer]?.trim());
  const ok = title.trim().length >= 2 && ((usePq && subject) || own.length > 0) && ownOk;

  async function send() {
    setBusy(true);
    const custom = own.map((q) => ({
      body: q.body.trim(), answer: q.answer, explanation: q.explanation.trim() || undefined,
      options: Object.fromEntries(Object.entries(q.options).filter(([, v]) => v.trim()).map(([k, v]) => [k, v.trim()])),
    }));
    const { data, error } = await sb.rpc("tutor_quiz_create", {
      p_request: chat.id, p_title: title.trim(), p_note: note.trim() || undefined,
      p_minutes: minutes ? Number(minutes) : undefined, p_due: due ? new Date(due).toISOString() : undefined,
      p_pq: usePq && subject ? { subject_id: Number(subject), count: Number(count), ...(from ? { year_from: Number(from) } : {}), ...(to ? { year_to: Number(to) } : {}) } : undefined,
      p_custom: custom.length ? custom : undefined,
    });
    setBusy(false);
    const d = (data ?? {}) as { ok?: boolean; error?: string; count?: number };
    if (error || !d.ok) {
      return void toast.error(d.error === "not_active" ? "This student's plan is not active." : d.error === "too_many" ? "That is many quizzes today. Try tomorrow."
        : d.error?.includes("no questions") ? "No questions found. Pick another subject or years, or add your own." : d.error ?? "Could not send the quiz.");
    }
    onSent();
    onClose();
  }

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader><DialogTitle>Set a quiz for {chat.name.split(" ")[0]}</DialogTitle></DialogHeader>
        <div className="grid gap-3">
          <label className="grid gap-1 text-sm font-medium">Title<input className={field} maxLength={120} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Waves and motion practice" autoFocus /></label>
          <label className="grid gap-1 text-sm font-medium">Note for the student (optional)<input className={field} maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Do it tonight before our class" /></label>
          <div className="grid grid-cols-2 gap-3">
            <label className="grid gap-1 text-sm font-medium">Time limit (minutes, optional)<input className={field} type="number" min={1} max={180} value={minutes} onChange={(e) => setMinutes(e.target.value)} placeholder="No limit" /></label>
            <label className="grid gap-1 text-sm font-medium">Due (optional)<input className={field} type="datetime-local" value={due} onChange={(e) => setDue(e.target.value)} /></label>
          </div>

          <section className={cn("rounded-2xl border p-3", usePq && "border-[#2563B3]")}>
            <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={usePq} onChange={(e) => setUsePq(e.target.checked)} /><Shuffle size={18} /> Random past questions</label>
            {usePq ? (
              <div className="mt-3 grid gap-3 sm:grid-cols-4">
                <label className="grid gap-1 text-sm font-medium sm:col-span-2">Subject
                  <select className={cn(field, "h-10")} value={subject} onChange={(e) => setSubject(e.target.value)}>
                    <option value="">Choose a subject</option>
                    {subjects.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                  </select>
                </label>
                <label className="grid gap-1 text-sm font-medium">How many
                  <select className={cn(field, "h-10")} value={count} onChange={(e) => setCount(e.target.value)}>{[5, 10, 15, 20, 30, 40, 50].map((n) => <option key={n}>{n}</option>)}</select>
                </label>
                <div className="grid gap-1 text-sm font-medium">Years (optional)
                  <div className="flex gap-1"><input aria-label="From year" className={field} inputMode="numeric" placeholder="From" value={from} onChange={(e) => setFrom(e.target.value.replace(/\D/g, "").slice(0, 4))} /><input aria-label="To year" className={field} inputMode="numeric" placeholder="To" value={to} onChange={(e) => setTo(e.target.value.replace(/\D/g, "").slice(0, 4))} /></div>
                </div>
              </div>
            ) : null}
          </section>

          <section className="rounded-2xl border p-3">
            <div className="flex items-center justify-between gap-2">
              <b className="text-sm">My own questions {own.length ? `(${own.length})` : ""}</b>
              <Button variant="outline" size="sm" onClick={() => setOwn((o) => [...o, blank()])}><Plus size={16} /> Add a question</Button>
            </div>
            {own.map((q, i) => (
              <div key={i} className="mt-3 rounded-xl bg-muted/60 p-3">
                <div className="flex items-start gap-2">
                  <b className="pt-2 text-sm">{i + 1}.</b>
                  <textarea className={cn(field, "min-h-16")} maxLength={4000} value={q.body} onChange={(e) => edit(i, { body: e.target.value })} placeholder="Type the question. Maths works with $…$, e.g. $v = f\lambda$" />
                  <button type="button" onClick={() => setOwn((o) => o.filter((_, j) => j !== i))} className="rounded-full p-2 text-red-600 hover:bg-red-50" aria-label="Remove question"><Trash size={18} /></button>
                </div>
                <div className="mt-2 grid gap-2 sm:grid-cols-2">
                  {KEYS.map((k) => (
                    <label key={k} className={cn("flex items-center gap-2 rounded-xl border bg-background px-2", q.answer === k && "border-emerald-500")}>
                      <button type="button" onClick={() => edit(i, { answer: k })} title="Mark as the right answer"
                        className={cn("grid size-7 shrink-0 place-items-center rounded-full text-xs font-bold", q.answer === k ? "bg-emerald-500 text-white" : "bg-muted")}>{q.answer === k ? <Check size={14} weight="bold" /> : k}</button>
                      <input className="h-10 flex-1 bg-transparent text-sm outline-none" maxLength={500} value={q.options[k]} onChange={(e) => edit(i, { options: { ...q.options, [k]: e.target.value } })} placeholder={`Option ${k}`} />
                    </label>
                  ))}
                </div>
                <input className={cn(field, "mt-2")} maxLength={4000} value={q.explanation} onChange={(e) => edit(i, { explanation: e.target.value })} placeholder="Why this answer (optional, shown after they submit)" />
              </div>
            ))}
            {!own.length ? <p className="mt-2 text-xs text-muted-foreground">Add your own questions, alone or with past questions. Tap a letter to mark the right answer.</p> : null}
          </section>

          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={onClose}>Cancel</Button>
            <Button disabled={!ok || busy} onClick={send} className="bg-[#F2B233] font-bold text-[#0B1F44] hover:bg-[#F6C970]">{busy ? "Sending…" : "Send quiz"}</Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

type Review = {
  quiz: { title: string; state: string; count: number; minutes: number | null };
  score: number | null; total: number | null; started_at: string | null; submitted_at: string | null;
  questions: { id: number; body: string; options: Record<string, string>; answer: string; explanation: string | null; chosen: string | null; correct: boolean }[];
};

/** The student's score and every question: what they chose, the right answer, and the explanation. */
export function QuizResults({ sb, quizId, name, onClose }: { sb: SupabaseClient; quizId: string; name: string; onClose: () => void }) {
  const [r, setR] = useState<Review | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [onlyMissed, setOnlyMissed] = useState(false);
  useEffect(() => {
    void sb.rpc("tutor_quiz_review", { p_quiz: quizId }).then(({ data, error }) => {
      if (error) setErr("Could not open the quiz.");
      else setR(data as unknown as Review);
    });
  }, [sb, quizId]);
  const done = r?.submitted_at;
  const mins = r?.started_at && r?.submitted_at ? Math.max(1, Math.round((new Date(r.submitted_at).getTime() - new Date(r.started_at).getTime()) / 60000)) : null;
  const shown = (r?.questions ?? []).filter((q) => !onlyMissed || !q.correct);
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader><DialogTitle>{r?.quiz.title ?? "Quiz"}</DialogTitle></DialogHeader>
        {err ? <p className="text-sm text-red-600">{err}</p> : !r ? <div className="h-40 animate-pulse rounded-xl bg-muted" /> : (
          <div className="grid gap-3">
            <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-muted/60 p-4">
              {done ? (
                <>
                  <span className="text-3xl font-bold tabular-nums">{r.score}/{r.total}</span>
                  <span className="text-sm text-muted-foreground">{Math.round(100 * (r.score ?? 0) / Math.max(1, r.total ?? 1))}% · {name.split(" ")[0]} took {mins} min · {new Date(r.submitted_at!).toLocaleString("en-NG", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" })}</span>
                </>
              ) : <span className="text-sm">{r.started_at ? `${name.split(" ")[0]} has started but not finished.` : `${name.split(" ")[0]} has not started yet.`} {r.quiz.count} questions.</span>}
              {done ? <label className="ml-auto flex items-center gap-2 text-sm"><input type="checkbox" checked={onlyMissed} onChange={(e) => setOnlyMissed(e.target.checked)} /> Only what they missed</label> : null}
            </div>
            <ol className="grid gap-3">
              {shown.map((q) => (
                <li key={q.id} className={cn("rounded-2xl border p-3", done && (q.correct ? "border-emerald-300 dark:border-emerald-800" : "border-red-300 dark:border-red-900"))}>
                  <p className="whitespace-pre-wrap text-sm font-medium">{(r.questions.findIndex((x) => x.id === q.id) + 1)}. {q.body}</p>
                  <ul className="mt-2 grid gap-1 text-sm">
                    {Object.entries(q.options).map(([k, v]) => (
                      <li key={k} className={cn("flex items-start gap-2 rounded-lg px-2 py-1", k === q.answer && "bg-emerald-50 font-bold text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200",
                        done && k === q.chosen && k !== q.answer && "bg-red-50 text-red-800 dark:bg-red-950 dark:text-red-200")}>
                        <b className="w-4">{k}</b><span className="flex-1">{v}</span>
                        {k === q.answer ? <Check size={16} weight="bold" /> : done && k === q.chosen ? <X size={16} weight="bold" /> : null}
                      </li>
                    ))}
                  </ul>
                  {done && !q.chosen ? <p className="mt-1 text-xs font-bold text-amber-700">Not answered</p> : null}
                  {q.explanation ? <p className="mt-2 rounded-lg bg-muted px-2 py-1.5 text-xs">{q.explanation}</p> : null}
                </li>
              ))}
            </ol>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
