"use client";
import { Label } from "@/components/ui/label";
import { RowForm, inputCls } from "@/components/admin/row-form";
import { savePassage } from "./actions";

type Opt = { id: number; label: string };
type P = { id: string; exam_id: number; subject_id: number; year: number | null; title: string | null; body: string };

export function PassageForm({ exams, subjects, passage: p }: { exams: Opt[]; subjects: Opt[]; passage?: P }) {
  const k = p?.id ?? "new";
  return (
    <RowForm action={savePassage} success="Saved." submitLabel={p ? "Save passage" : "Add passage"}>
      {p ? <input type="hidden" name="id" value={p.id} /> : null}
      <div className="grid grid-cols-3 gap-2">
        <select name="exam_id" defaultValue={p?.exam_id ?? ""} aria-label="Exam" className={inputCls} required><option value="" disabled>Exam</option>{exams.map((e) => <option key={e.id} value={e.id}>{e.label}</option>)}</select>
        <select name="subject_id" defaultValue={p?.subject_id ?? ""} aria-label="Subject" className={inputCls} required><option value="" disabled>Subject</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}</select>
        <input name="year" type="number" min={1978} max={2100} defaultValue={p?.year ?? ""} placeholder="Year" aria-label="Year" className={inputCls} />
      </div>
      <div className="space-y-1.5"><Label htmlFor={`t${k}`}>Title</Label><input id={`t${k}`} name="title" defaultValue={p?.title ?? ""} placeholder="e.g. Passage I: The farmer" className={inputCls} /></div>
      <div className="space-y-1.5"><Label htmlFor={`b${k}`}>Passage text</Label>
        <textarea id={`b${k}`} name="body" defaultValue={p?.body ?? ""} rows={p ? 6 : 10} required className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm leading-6" /></div>
    </RowForm>
  );
}
