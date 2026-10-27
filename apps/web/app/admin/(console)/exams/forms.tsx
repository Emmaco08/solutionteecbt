"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { saveRules, saveSubjectRule } from "./actions";

type Cfg = { exam_id: number; subjects_per_candidate: number; total_minutes: number | null; score_scale: number; max_options: number };
type Rule = { question_count: number; minutes: number | null; compulsory: boolean } | null;
const input = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60";

export function RulesForm({ cfg, editable }: { cfg: Cfg; editable: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form action={(f) => start(async () => { const r = await saveRules(f); if (r.ok) { toast.success("Exam rules saved."); router.refresh(); } else toast.error(r.error); })}
      className="space-y-3 text-sm">
      <input type="hidden" name="exam_id" value={cfg.exam_id} />
      {[
        ["subjects_per_candidate", "Subjects per candidate", cfg.subjects_per_candidate],
        ["total_minutes", "Total time (minutes, empty = per subject)", cfg.total_minutes ?? ""],
        ["score_scale", "Score out of", cfg.score_scale],
        ["max_options", "Options per question (4 or 5)", cfg.max_options],
      ].map(([name, label, value]) => (
        <label key={name as string} className="block space-y-1"><span className="text-muted-foreground">{label}</span>
          <input name={name as string} type="number" defaultValue={value as number} disabled={!editable} className={input} /></label>
      ))}
      {editable ? <Button type="submit" disabled={pending} className="w-full">Save rules</Button> : <p className="text-xs text-muted-foreground">Only admins can change exam rules.</p>}
    </form>
  );
}

export function SubjectRuleRow({ examId, subjectId, name, rule, editable }: { examId: number; subjectId: number; name: string; rule: Rule; editable: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form action={(f) => start(async () => { const r = await saveSubjectRule(f); if (r.ok) { toast.success(`${name} saved.`); router.refresh(); } else toast.error(r.error); })}
      className="grid grid-cols-[minmax(0,1fr)_64px_64px_auto] items-center gap-2 px-5 py-2.5 text-sm">
      <input type="hidden" name="exam_id" value={examId} /><input type="hidden" name="subject_id" value={subjectId} />
      <span className="min-w-0"><b className="block truncate">{name}</b>
        <label className="flex items-center gap-1.5 text-xs text-muted-foreground"><input type="checkbox" name="compulsory" defaultChecked={rule?.compulsory} disabled={!editable} /> Compulsory</label></span>
      <input name="question_count" type="number" defaultValue={rule?.question_count ?? 40} aria-label={`${name}: questions`} title="Questions" disabled={!editable} className={input} />
      <input name="minutes" type="number" defaultValue={rule?.minutes ?? ""} aria-label={`${name}: minutes`} title="Minutes" placeholder="min" disabled={!editable} className={input} />
      {editable ? <Button type="submit" size="sm" variant={rule ? "outline" : "default"} disabled={pending}>{rule ? "Save" : "Add"}</Button> : <span />}
    </form>
  );
}
