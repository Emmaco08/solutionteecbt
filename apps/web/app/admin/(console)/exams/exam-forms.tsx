"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { ImageUpload } from "@/components/admin/image-upload";
import { createExam, saveExam } from "./actions";

const input = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60";
export const BUILT_IN = ["JAMB", "WAEC", "NECO"];

type Exam = { id: number; code: string; name: string; subtitle: string | null; logo_path: string | null; sort: number; is_active: boolean };

/** Name, short line, logo (new exams only), order and Show in the app (D-138). */
export function ExamDetailsForm({ exam, editable }: { exam: Exam; editable: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [active, setActive] = useState(exam.is_active);
  const builtIn = BUILT_IN.includes(exam.code);
  return (
    <form key={exam.id} className="space-y-3 text-sm" action={(f) => start(async () => {
      const r = await saveExam({ id: exam.id, name: f.get("name"), subtitle: f.get("subtitle"), logo_path: f.get("logo_path") ?? "", sort: f.get("sort"), is_active: active });
      if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
    })}>
      <label className="block space-y-1"><span className="text-muted-foreground">Full name</span>
        <input name="name" defaultValue={exam.name} maxLength={60} disabled={!editable} className={input} /></label>
      <label className="block space-y-1"><span className="text-muted-foreground">Short line under the name</span>
        <input name="subtitle" defaultValue={exam.subtitle ?? ""} maxLength={80} placeholder="Objective papers per subject" disabled={!editable} className={input} /></label>
      {builtIn ? (
        <p className="rounded-xl bg-muted/50 p-3 text-xs text-muted-foreground">The {exam.code} logo comes from /brand/exam-bodies and follows the exam logos switch in App control.</p>
      ) : (
        <div className="space-y-1">
          <span className="text-muted-foreground">Logo (optional)</span>
          {editable ? <ImageUpload name="logo_path" kind="exam_logo" defaultKey={exam.logo_path} /> : null}
          <p className="text-xs text-muted-foreground">Upload only a logo you have permission to use. Without one the app shows a badge with &quot;{exam.code}&quot;.</p>
        </div>
      )}
      <label className="block space-y-1"><span className="text-muted-foreground">Order</span>
        <input name="sort" type="number" min={0} defaultValue={exam.sort} disabled={!editable} className={input} /></label>
      <div className="flex items-center justify-between gap-3 rounded-xl border p-3">
        <div><b>Show in the app</b><p className="text-xs text-muted-foreground">{exam.code === "JAMB" ? "JAMB is always shown." : "Turn on when it has published years."}</p></div>
        <Switch checked={active} onCheckedChange={setActive} disabled={!editable || exam.code === "JAMB"} aria-label="Show in the app" />
      </div>
      {editable ? <Button type="submit" disabled={pending} className="w-full">Save exam</Button> : <p className="text-xs text-muted-foreground">Only admins can change exams.</p>}
    </form>
  );
}

export function AddExam() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, start] = useTransition();
  if (!open) return <Button variant="outline" className="h-[52px] rounded-2xl" onClick={() => setOpen(true)}><Plus size={18} weight="bold" /> Add exam</Button>;
  return (
    <form className="flex w-full flex-wrap items-end gap-3 rounded-2xl border bg-card p-4 text-sm" action={(f) => start(async () => {
      const r = await createExam({ code: f.get("code"), name: f.get("name"), subtitle: f.get("subtitle") });
      if (!r.ok) return void toast.error(r.error);
      toast.success(r.message);
      setOpen(false);
      router.push(`/admin/exams?exam=${r.data?.id}`);
      router.refresh();
    })}>
      <div className="w-32"><Label htmlFor="new-code">Short name</Label><input id="new-code" name="code" placeholder="BECE" maxLength={12} className={`${input} uppercase`} required /></div>
      <div className="min-w-48 flex-1"><Label htmlFor="new-name">Full name</Label><input id="new-name" name="name" placeholder="BECE (Junior WAEC)" maxLength={60} className={input} required /></div>
      <div className="min-w-48 flex-1"><Label htmlFor="new-sub">Short line (optional)</Label><input id="new-sub" name="subtitle" placeholder="Objective papers per subject" maxLength={80} className={input} /></div>
      <div className="flex gap-2"><Button type="button" variant="ghost" onClick={() => setOpen(false)}>Cancel</Button><Button type="submit" disabled={pending}>Add exam</Button></div>
      <p className="w-full text-xs text-muted-foreground">New exams start hidden and locked for free students. Next: add its subjects and rules, import questions, publish years, set free years in Free vs Premium, then turn on Show in the app.</p>
    </form>
  );
}
