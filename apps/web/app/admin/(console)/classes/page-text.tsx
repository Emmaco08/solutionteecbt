"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { saveClassesPage } from "./actions";

export type ClassesPageText = { on: boolean; title: string; intro: string; price_note: string; teachers: { name: string; subject?: string; bio?: string }[]; faq: { q: string; a: string }[] };

/** One teacher or question per line: "Name | Subject | Short bio" and "Question | Answer". */
export function ClassesPageForm({ initial }: { initial: ClassesPageText }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({
    title: initial.title, intro: initial.intro, price_note: initial.price_note,
    teachers: initial.teachers.map((t) => [t.name, t.subject ?? "", t.bio ?? ""].join(" | ")).join("\n"),
    faq: initial.faq.map((q) => `${q.q} | ${q.a}`).join("\n"),
  });
  const save = () => start(async () => {
    const split = (s: string) => s.split("\n").map((l) => l.split("|").map((x) => x.trim())).filter((p) => p[0]);
    const r = await saveClassesPage({
      on: true, title: f.title, intro: f.intro, price_note: f.price_note,
      teachers: split(f.teachers).map(([name, subject, bio]) => ({ name, subject: subject || undefined, bio: bio || undefined })),
      faq: split(f.faq).filter((p) => p[1]).map(([q, a]) => ({ q, a })),
    });
    if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
  });
  return (
    <div className="grid gap-3 text-sm">
      <div><Label htmlFor="cp-title">Heading</Label><input id="cp-title" className={inputCls} maxLength={120} value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} /></div>
      <div><Label htmlFor="cp-intro">Introduction</Label><textarea id="cp-intro" rows={3} maxLength={800} className={inputCls} value={f.intro} onChange={(e) => setF({ ...f, intro: e.target.value })} /></div>
      <div><Label htmlFor="cp-price">About prices</Label><input id="cp-price" className={inputCls} maxLength={400} value={f.price_note} onChange={(e) => setF({ ...f, price_note: e.target.value })} /></div>
      <div><Label htmlFor="cp-teachers">Teachers (one per line: Name | Subject | Short bio)</Label><textarea id="cp-teachers" rows={3} className={inputCls} value={f.teachers} onChange={(e) => setF({ ...f, teachers: e.target.value })} /></div>
      <div><Label htmlFor="cp-faq">Questions (one per line: Question | Answer)</Label><textarea id="cp-faq" rows={4} className={inputCls} value={f.faq} onChange={(e) => setF({ ...f, faq: e.target.value })} /></div>
      <div className="flex items-center gap-3"><Button disabled={pending} onClick={save}>Save page</Button><a href="https://cbt.solutiontee.com/classes" target="_blank" rel="noopener noreferrer" className="text-sm font-bold text-link">Open the page</a></div>
    </div>
  );
}
