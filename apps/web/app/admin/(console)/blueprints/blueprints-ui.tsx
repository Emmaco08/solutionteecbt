"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowDown, ArrowUp, Plus, Trash, WarningCircle } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Panel, Pill } from "@/components/admin/ui";
import { addSubjectBlueprint, deleteBlueprint, saveBlueprint } from "./actions";

export type SectionRow = { key: string; label: string; count: number; instruction: string; passage: boolean };
export type BlueprintRow = { id: number; exam_id: number; subject_id: number | null; total: number; sections: SectionRow[] };


export function BlueprintCard({ bp, subject, examId, canDelete }: { bp: BlueprintRow; subject: string | null; examId: number; canDelete: boolean }) {
  void examId;
  const router = useRouter();
  const [pending, start] = useTransition();
  const [total, setTotal] = useState(String(bp.total));
  const [secs, setSecs] = useState<SectionRow[]>(bp.sections);
  const [open, setOpen] = useState(bp.sections.length > 0);
  const sum = secs.reduce((t, s) => t + (Number(s.count) || 0), 0);
  const mismatch = secs.length > 0 && sum !== Number(total);
  const dirty = total !== String(bp.total) || JSON.stringify(secs) !== JSON.stringify(bp.sections);

  const patch = (i: number, p: Partial<SectionRow>) => setSecs((a) => a.map((s, j) => (j === i ? { ...s, ...p } : s)));
  const move = (i: number, d: -1 | 1) => setSecs((a) => { const n = [...a]; const j = i + d; if (j < 0 || j >= n.length) return a; [n[i], n[j]] = [n[j]!, n[i]!]; return n; });
  const add = () => setSecs((a) => {
    let key = `section_${a.length + 1}`;
    while (a.some((s) => s.key === key)) key += "_x";
    return [...a, { key, label: "New section", count: 5, instruction: "", passage: false }];
  });
  const save = () => start(async () => {
    const r = await saveBlueprint({ id: bp.id, total, sections: secs });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    router.refresh();
  });
  const remove = () => {
    if (!confirm("Remove this blueprint? The subject goes back to the exam default.")) return;
    start(async () => { const r = await deleteBlueprint(bp.id); if (!r.ok) toast.error(r.error); else { toast.success(r.message); router.refresh(); } });
  };

  return (
    <Panel
      title={<span className="flex items-center gap-2">{subject ?? "Exam default"}{subject ? null : <Pill tone="info">All other subjects</Pill>}</span>}
      actions={<>
        <label className="flex items-center gap-2 text-sm font-bold" htmlFor={`t${bp.id}`}>Questions in a full paper
          <input id={`t${bp.id}`} type="number" min={1} max={300} value={total} onChange={(e) => setTotal(e.target.value)} className={`${inputCls} !h-10 !w-20`} />
        </label>
      </>}
    >
      {!open && !secs.length ? (
        <p className="text-sm text-muted-foreground">One block of {bp.total} questions, no sections. <button type="button" className="font-bold text-blue underline" onClick={() => setOpen(true)}>Add sections</button></p>
      ) : (
        <ol className="space-y-3">
          {secs.map((s, i) => (
            <li key={s.key} className="rounded-xl border bg-background p-3">
              <div className="grid gap-3 md:grid-cols-[28px_minmax(0,1fr)_100px_auto] md:items-end">
                <span className="hidden size-7 place-items-center rounded-full bg-muted text-xs font-bold md:grid">{i + 1}</span>
                <div><Label htmlFor={`l${bp.id}${s.key}`}>Name <span className="font-normal text-muted-foreground">({s.key})</span></Label>
                  <input id={`l${bp.id}${s.key}`} className={inputCls} value={s.label} maxLength={60} onChange={(e) => patch(i, { label: e.target.value })} /></div>
                <div><Label htmlFor={`c${bp.id}${s.key}`}>Questions</Label>
                  <input id={`c${bp.id}${s.key}`} type="number" min={0} max={200} className={inputCls} value={s.count} onChange={(e) => patch(i, { count: Number(e.target.value) })} /></div>
                <div className="flex items-center gap-1">
                  <button type="button" aria-label="Move up" disabled={i === 0} onClick={() => move(i, -1)} className="grid size-10 place-items-center rounded-full hover:bg-muted disabled:opacity-30"><ArrowUp size={18} /></button>
                  <button type="button" aria-label="Move down" disabled={i === secs.length - 1} onClick={() => move(i, 1)} className="grid size-10 place-items-center rounded-full hover:bg-muted disabled:opacity-30"><ArrowDown size={18} /></button>
                  <button type="button" aria-label="Remove section" onClick={() => setSecs((a) => a.filter((_, j) => j !== i))} className="grid size-10 place-items-center rounded-full text-error hover:bg-muted"><Trash size={18} /></button>
                </div>
              </div>
              <div className="mt-3 grid gap-3 md:grid-cols-[minmax(0,1fr)_auto] md:items-end md:pl-[40px]">
                <div><Label htmlFor={`i${bp.id}${s.key}`}>Instruction shown above the section</Label>
                  <input id={`i${bp.id}${s.key}`} className={inputCls} value={s.instruction} maxLength={300} onChange={(e) => patch(i, { instruction: e.target.value })} /></div>
                <label className="flex h-11 items-center gap-2 text-sm"><input type="checkbox" checked={s.passage} onChange={(e) => patch(i, { passage: e.target.checked })} /> Takes whole passages</label>
              </div>
            </li>
          ))}
        </ol>
      )}

      {open || secs.length ? (
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button type="button" variant="outline" onClick={add}><Plus size={16} weight="bold" /> Add section</Button>
          {secs.length ? (
            <span className={mismatch ? "inline-flex items-center gap-1.5 text-sm font-bold text-on-warning-soft" : "text-sm text-muted-foreground"}>
              {mismatch ? <WarningCircle size={18} weight="fill" /> : null}
              Sections add up to {sum} · paper total {Number(total) || 0}{mismatch ? ". These should match." : ""}
            </span>
          ) : null}
        </div>
      ) : null}

      <div className="mt-4 flex flex-wrap items-center gap-2 border-t pt-4">
        <Button type="button" onClick={save} disabled={pending || !dirty}>Save blueprint</Button>
        {dirty ? <Button type="button" variant="ghost" onClick={() => { setTotal(String(bp.total)); setSecs(bp.sections); }}>Undo changes</Button> : null}
        {bp.subject_id !== null && canDelete ? <Button type="button" variant="ghost" className="ml-auto text-error" disabled={pending} onClick={remove}>Remove blueprint</Button> : null}
      </div>
    </Panel>
  );
}

export function AddSubject({ examId, free }: { examId: number; free: { id: number; name: string }[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [sid, setSid] = useState("");
  if (!free.length) return null;
  return (
    <div className="mt-3 flex flex-wrap items-center gap-2">
      <select aria-label="Subject" className={`${inputCls} !w-60`} value={sid} onChange={(e) => setSid(e.target.value)}>
        <option value="">Add a blueprint for a subject…</option>{free.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select>
      <Button type="button" variant="outline" disabled={!sid || pending}
        onClick={() => start(async () => { const r = await addSubjectBlueprint(examId, Number(sid)); if (!r.ok) toast.error(r.error); else { toast.success(r.message); setSid(""); router.refresh(); } })}>
        <Plus size={16} weight="bold" /> Add
      </Button>
    </div>
  );
}
