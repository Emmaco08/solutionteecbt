"use client";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { addAssignment, addMaterial, classWork, markSubmission, removeAssignment, removeMaterial } from "./actions";

type Work = {
  materials: { id: string; title: string; url: string }[];
  assignments: { id: string; title: string; due_at: string | null; max_score: number }[];
  submissions: { assignment_id: string; assignment: string; max_score: number; user_id: string; name: string; answer: string; submitted_at: string; score: number | null; feedback: string | null }[];
};

/** Materials, assignments and marking for one class (D-148). */
export function ClassWork({ classId }: { classId: string }) {
  const [w, setW] = useState<Work | null>(null);
  const [pending, start] = useTransition();
  const [mat, setMat] = useState({ title: "", url: "" });
  const [asg, setAsg] = useState({ title: "", instructions: "", due_at: "", max_score: "10" });
  const [marks, setMarks] = useState<Record<string, { score: string; feedback: string }>>({});
  const load = () => start(async () => { const r = await classWork(classId); if (r.ok && r.data) setW(r.data); else if (!r.ok) toast.error(r.error); });
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>, after?: () => void) => start(async () => {
    const r = await fn();
    if (!r.ok) return void toast.error(r.error ?? "Could not save");
    toast.success(r.message ?? "Done");
    after?.();
    const x = await classWork(classId);
    if (x.ok && x.data) setW(x.data);
  });
  if (!w) return <Button size="sm" variant="ghost" disabled={pending} onClick={load}>Materials and assignments</Button>;
  return (
    <div className="mt-3 w-full space-y-4 rounded-xl border p-4 text-sm">
      <div>
        <b>Materials</b>
        <ul className="mt-1 space-y-1">{w.materials.map((m) => (
          <li key={m.id} className="flex items-center gap-2"><a href={m.url} target="_blank" rel="noopener noreferrer" className="text-link">{m.title}</a>
            <button className="text-xs text-muted-foreground hover:text-error" onClick={() => act(() => removeMaterial(m.id))}>remove</button></li>
        ))}</ul>
        <div className="mt-2 grid gap-2 md:grid-cols-[1fr_2fr_auto]">
          <input aria-label="Material title" placeholder="Notes PDF" className={inputCls} value={mat.title} onChange={(e) => setMat({ ...mat, title: e.target.value })} />
          <input aria-label="Material link" placeholder="https:// (Google Drive, PDF…)" className={inputCls} value={mat.url} onChange={(e) => setMat({ ...mat, url: e.target.value })} />
          <Button size="sm" disabled={pending} onClick={() => act(() => addMaterial(classId, mat.title, mat.url), () => setMat({ title: "", url: "" }))}>Add</Button>
        </div>
      </div>
      <div>
        <b>Assignments</b>
        <ul className="mt-1 space-y-1">{w.assignments.map((a) => (
          <li key={a.id} className="flex items-center gap-2">{a.title} <span className="text-xs text-muted-foreground">/ {a.max_score}</span>
            <button className="text-xs text-muted-foreground hover:text-error" onClick={() => { if (confirm("Remove this assignment and its answers?")) act(() => removeAssignment(a.id)); }}>remove</button></li>
        ))}</ul>
        <div className="mt-2 grid gap-2 md:grid-cols-[1fr_180px_90px_auto]">
          <input aria-label="Assignment title" placeholder="Waves worksheet" className={inputCls} value={asg.title} onChange={(e) => setAsg({ ...asg, title: e.target.value })} />
          <input aria-label="Due (Lagos time)" type="datetime-local" className={inputCls} value={asg.due_at} onChange={(e) => setAsg({ ...asg, due_at: e.target.value })} />
          <input aria-label="Marks" type="number" min={1} max={100} className={inputCls} value={asg.max_score} onChange={(e) => setAsg({ ...asg, max_score: e.target.value })} />
          <Button size="sm" disabled={pending} onClick={() => act(() => addAssignment({ class_id: classId, ...asg }), () => setAsg({ title: "", instructions: "", due_at: "", max_score: "10" }))}>Add</Button>
        </div>
        <textarea aria-label="Instructions" rows={2} placeholder="Instructions (optional)" className={`${inputCls} mt-2`} value={asg.instructions} onChange={(e) => setAsg({ ...asg, instructions: e.target.value })} />
      </div>
      <div>
        <b>Answers handed in ({w.submissions.length})</b>
        <ul className="mt-2 space-y-3">{w.submissions.map((s) => {
          const k = `${s.assignment_id}:${s.user_id}`;
          const m = marks[k] ?? { score: s.score === null ? "" : String(s.score), feedback: s.feedback ?? "" };
          return (
            <li key={k} className="rounded-lg bg-muted/50 p-3">
              <p className="text-xs text-muted-foreground"><b className="text-foreground">{s.name}</b> · {s.assignment}{s.score !== null ? ` · marked ${s.score}/${s.max_score}` : ""}</p>
              <p className="mt-1 whitespace-pre-wrap">{s.answer}</p>
              <div className="mt-2 grid gap-2 md:grid-cols-[90px_1fr_auto]">
                <input aria-label="Mark" type="number" min={0} max={s.max_score} className={inputCls} value={m.score} onChange={(e) => setMarks({ ...marks, [k]: { ...m, score: e.target.value } })} />
                <input aria-label="Feedback" placeholder="Feedback (optional)" className={inputCls} value={m.feedback} onChange={(e) => setMarks({ ...marks, [k]: { ...m, feedback: e.target.value } })} />
                <Button size="sm" disabled={pending || m.score === ""} onClick={() => act(() => markSubmission(s.assignment_id, s.user_id, Math.min(Number(m.score), s.max_score), m.feedback))}>Save mark</Button>
              </div>
            </li>
          );
        })}</ul>
      </div>
    </div>
  );
}
