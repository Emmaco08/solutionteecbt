"use client";
import { useActionState, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CheckCircle, SpinnerGap, Trash, Function as FunctionIcon } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button, buttonVariants } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { MathText } from "@/components/admin/math-text";
import { ImageUpload } from "@/components/admin/image-upload";
import { cn } from "@/lib/utils";
import { ENGLISH_SECTIONS } from "@solutiontee/shared/csv";
import { saveQuestion, deleteQuestion, type SaveState } from "./actions";

export type EditorQuestion = {
  id?: string; exam_id?: number; subject_id?: number; year?: number; number?: number | null; topic?: string; passage_id?: string | null;
  body?: string; options?: Record<string, string>; answer?: string; explanation?: string | null; difficulty?: string | null;
  image_path?: string | null; status?: "draft" | "review" | "published"; section?: string | null; section_source?: string | null;
};
type Opt = { id: number; code?: string; name: string };
type PassageOpt = { id: string; label: string };
const KEYS = ["A", "B", "C", "D", "E"] as const;

export function QuestionEditor({ q, exams, subjects, passages, topics, canDelete }: {
  q: EditorQuestion; exams: Opt[]; subjects: Opt[]; passages: PassageOpt[]; topics: string[]; canDelete: boolean;
}) {
  const router = useRouter();
  const [state, action, saving] = useActionState<SaveState, FormData>(saveQuestion, {});
  const [body, setBody] = useState(q.body ?? "");
  const [opts, setOpts] = useState<Record<string, string>>({ A: "", B: "", C: "", D: "", E: "", ...(q.options ?? {}) });
  const [answer, setAnswer] = useState(q.answer ?? "");
  const [explanation, setExplanation] = useState(q.explanation ?? "");
  const [subjectId, setSubjectId] = useState(String(q.subject_id ?? ""));
  const isEnglish = subjects.find((s) => String(s.id) === subjectId)?.name === "Use of English";
  const [deleting, startDelete] = useTransition();
  const err = state.fieldErrors ?? {};

  const field = "h-11 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
  const insert = (setter: (fn: (s: string) => string) => void, el: string, snippet: string) => {
    const ta = document.getElementById(el) as HTMLTextAreaElement | null;
    if (!ta) return setter((s) => s + snippet);
    const [a, b] = [ta.selectionStart, ta.selectionEnd];
    setter((s) => s.slice(0, a) + snippet.replace("…", s.slice(a, b) || "x") + s.slice(b));
    requestAnimationFrame(() => ta.focus());
  };

  return (
    <form action={action} className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_420px]">
      {q.id ? <input type="hidden" name="id" value={q.id} /> : null}
      <div className="space-y-5">
        <section className="rounded-2xl border bg-card p-5">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="space-y-1.5"><Label htmlFor="exam_id">Exam</Label>
              <select id="exam_id" name="exam_id" defaultValue={q.exam_id ?? ""} className={cn(field, err.exam_id && "border-error")} required>
                <option value="" disabled>Choose…</option>{exams.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
              </select></div>
            <div className="space-y-1.5"><Label htmlFor="subject_id">Subject</Label>
              <select id="subject_id" name="subject_id" value={subjectId} onChange={(e) => setSubjectId(e.target.value)} className={cn(field, err.subject_id && "border-error")} required>
                <option value="" disabled>Choose…</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select></div>
            <div className="space-y-1.5"><Label htmlFor="year">Year</Label>
              <input id="year" name="year" type="number" min={1978} max={2100} defaultValue={q.year ?? ""} className={cn(field, err.year && "border-error")} required /></div>
            <div className="space-y-1.5"><Label htmlFor="number">Question no.</Label>
              <input id="number" name="number" type="number" min={1} max={500} defaultValue={q.number ?? ""} className={field} placeholder="Optional" /></div>
          </div>
          {err.exam_id || err.subject_id || err.year ? <p className="mt-2 text-sm font-bold text-error">{err.exam_id || err.subject_id || err.year}</p> : null}
        </section>

        <section className="space-y-2 rounded-2xl border bg-card p-5">
          <div className="flex items-center justify-between"><Label htmlFor="body">Question</Label><span className="text-xs text-muted-foreground">{"Maths: $x^2$ inline, $$\\frac{a}{b}$$ on its own line"}</span></div>
          <div className={cn("overflow-hidden rounded-xl border border-input focus-within:ring-2 focus-within:ring-ring", err.body && "border-error")}>
            <div className="flex gap-0.5 border-b bg-surface-alt p-1.5">
              <ToolButton label="Inline maths" onClick={() => insert(setBody, "body", "$…$")}><FunctionIcon size={17} /></ToolButton>
              <ToolButton label="Fraction" onClick={() => insert(setBody, "body", "$\\frac{…}{y}$")}><span className="text-xs font-bold">a/b</span></ToolButton>
              <ToolButton label="Square root" onClick={() => insert(setBody, "body", "$\\sqrt{…}$")}><span className="text-xs font-bold">√</span></ToolButton>
              <ToolButton label="Power" onClick={() => insert(setBody, "body", "$…^{2}$")}><span className="text-xs font-bold">x²</span></ToolButton>
            </div>
            <textarea id="body" name="body" value={body} onChange={(e) => setBody(e.target.value)} rows={4} required
              className="block min-h-28 w-full resize-y bg-card px-3.5 py-3 font-mono text-[13px] leading-5 outline-none" />
          </div>
          {err.body ? <p className="text-sm font-bold text-error">{err.body}</p> : null}
        </section>

        <section className="space-y-3 rounded-2xl border bg-card p-5">
          <div className="flex items-center justify-between"><b className="text-sm">Options</b><span className="text-xs text-muted-foreground">Tap a letter to mark the correct answer. E is optional.</span></div>
          <input type="hidden" name="answer" value={answer} />
          {KEYS.map((k) => (
            <div key={k} className="grid grid-cols-[44px_minmax(0,1fr)] items-start gap-2">
              <button type="button" onClick={() => setAnswer(k)} aria-pressed={answer === k} aria-label={`Mark ${k} as the correct answer`}
                className={cn("grid size-11 place-items-center rounded-xl font-bold transition-colors", answer === k ? "bg-success text-white" : "bg-muted hover:bg-sunken")}>
                {answer === k ? <CheckCircle size={20} weight="fill" /> : k}
              </button>
              <div>
                <input name={k} value={opts[k]} onChange={(e) => setOpts((o) => ({ ...o, [k]: e.target.value }))} required={k !== "E"}
                  placeholder={k === "E" ? "Option E (optional)" : `Option ${k}`} className={cn(field, err[k] && "border-error")} />
                {err[k] ? <p className="mt-1 text-xs font-bold text-error">{err[k]}</p> : null}
              </div>
            </div>
          ))}
          {err.answer ? <p className="text-sm font-bold text-error">{err.answer}</p> : null}
        </section>

        <section className="space-y-2 rounded-2xl border bg-card p-5">
          <Label htmlFor="explanation">Explanation (shown after answering)</Label>
          <textarea id="explanation" name="explanation" value={explanation} onChange={(e) => setExplanation(e.target.value)} rows={4}
            className={cn("block w-full resize-y rounded-xl border border-input bg-card px-3.5 py-3 font-mono text-[13px] leading-5 outline-none focus-visible:ring-2 focus-visible:ring-ring", err.explanation && "border-error")} />
          {err.explanation ? <p className="text-sm font-bold text-error">{err.explanation}</p> : null}
        </section>

        <section className="grid gap-4 rounded-2xl border bg-card p-5 sm:grid-cols-2">
          <div className="space-y-1.5"><Label htmlFor="topic">Topic</Label>
            <input id="topic" name="topic" list="topics" defaultValue={q.topic ?? ""} className={field} placeholder="e.g. Logarithms" />
            <datalist id="topics">{topics.map((t) => <option key={t} value={t} />)}</datalist></div>
          <div className="space-y-1.5"><Label htmlFor="difficulty">Difficulty</Label>
            <select id="difficulty" name="difficulty" defaultValue={q.difficulty ?? ""} className={field}>
              <option value="">Not set</option><option value="easy">Easy</option><option value="medium">Medium</option><option value="hard">Hard</option>
            </select></div>
          {isEnglish ? (
            <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="section">JAMB section</Label>
              <input type="hidden" name="section_orig" value={q.section ?? ""} />
              <select id="section" name="section" defaultValue={q.section ?? ""} className={cn(field, err.section && "border-error")}>
                <option value="">Not sorted</option>
                {ENGLISH_SECTIONS.map((x) => <option key={x.key} value={x.key}>{x.label}</option>)}
              </select>
              <p className="text-xs text-muted-foreground">
                {q.section_source === "rule" || q.section_source === "ai" ? `Sorted automatically (${q.section_source === "ai" ? "AI" : "rules"}). Pick a section to set it yourself.` : "Decides where this question sits in a JAMB English paper."}
              </p>
              {err.section ? <p className="text-xs font-bold text-error">{err.section}</p> : null}</div>
          ) : null}
          <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="passage_id">Comprehension passage</Label>
            <select id="passage_id" name="passage_id" defaultValue={q.passage_id ?? ""} className={field}>
              <option value="">No passage</option>{passages.map((p) => <option key={p.id} value={p.id}>{p.label}</option>)}
            </select></div>
          <div className="space-y-1.5 sm:col-span-2"><Label>Image (diagram, graph)</Label><ImageUpload name="image_path" kind="question" defaultKey={q.image_path} /></div>
        </section>
      </div>

      <aside className="space-y-4 xl:sticky xl:top-[88px]">
        <section className="rounded-2xl border bg-card p-5">
          <b className="text-sm text-muted-foreground">Student preview</b>
          <div className="mt-3 rounded-2xl bg-background p-4">
            <p className="text-[17px] leading-[27px]">{body ? <MathText text={body} /> : <span className="text-muted-foreground">The question shows here.</span>}</p>
            <div className="mt-4 space-y-2">
              {KEYS.filter((k) => opts[k]).map((k) => (
                <div key={k} className={cn("flex items-start gap-3 rounded-xl border bg-card px-3 py-2.5 text-sm", answer === k && "border-success bg-success-soft")}>
                  <b className={cn("grid size-7 flex-none place-items-center rounded-lg bg-muted text-xs", answer === k && "bg-success text-white")}>{k}</b>
                  <MathText text={opts[k] ?? ""} />
                </div>
              ))}
            </div>
            {explanation ? <div className="mt-4 rounded-xl bg-info-soft p-3 text-sm text-on-info-soft"><b>Explanation. </b><MathText text={explanation} /></div> : null}
          </div>
        </section>
        <section className="space-y-3 rounded-2xl border bg-card p-5">
          <Label htmlFor="status">Status</Label>
          <select id="status" name="status" defaultValue={q.status ?? "draft"} className={field}>
            <option value="draft">Draft (only staff see it)</option>
            <option value="review">Needs review</option>
            <option value="published">Published (students can get it)</option>
          </select>
          {state.error ? <p role="alert" className="rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{state.error}</p> : null}
          <div className="flex gap-2">
            <Button type="submit" disabled={saving} className="h-11 grow">{saving ? <SpinnerGap size={18} className="animate-spin" /> : null} Save question</Button>
            <Link href="/admin/questions" className={buttonVariants({ variant: "outline", className: "h-11" })}>Cancel</Link>
          </div>
          {q.id && canDelete ? (
            <Button type="button" variant="ghost" className="w-full text-error" disabled={deleting}
              onClick={() => { if (!confirm("Delete this question? Students will stop seeing it.")) return;
                startDelete(async () => { const r = await deleteQuestion(q.id!); if (r.ok) { toast.success("Question deleted."); router.push("/admin/questions"); } else toast.error(r.error); }); }}>
              <Trash size={16} /> Delete question
            </Button>
          ) : null}
        </section>
      </aside>
    </form>
  );
}

function ToolButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return <button type="button" title={label} aria-label={label} onClick={onClick} className="grid size-9 place-items-center rounded-lg text-muted-foreground hover:bg-sunken hover:text-foreground">{children}</button>;
}
