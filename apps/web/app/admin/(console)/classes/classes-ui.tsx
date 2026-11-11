"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill, when } from "@/components/admin/ui";
import { classStudents, deleteClass, saveClass } from "./actions";

export type AdminClass = {
  id: string; title: string; about: string | null; subject_id: number | null; exam: string | null; teacher: string; starts_at: string;
  minutes: number; access: "free" | "premium" | "paid"; price_kobo: number | null; seats: number | null; status: "draft" | "published" | "cancelled";
  web_only: boolean; join_url: string | null; recording_url: string | null; counts: { reg: number; joined: number; paid: number };
};
type Subject = { id: number; name: string };
type Student = { name: string; email: string | null; registered_at: string; joined_at: string | null; paid: boolean };

/** "2026-11-12T18:00" in Lagos time for a datetime-local input. */
const lagos = (iso: string) => new Date(new Date(iso).getTime() + 3600000).toISOString().slice(0, 16);
const ACCESS = { free: "Free", premium: "Premium", paid: "Paid" } as const;

function Editor({ c, subjects, exams, onDone }: { c?: AdminClass; subjects: Subject[]; exams: string[]; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({
    title: c?.title ?? "", about: c?.about ?? "", subject_id: c?.subject_id ? String(c.subject_id) : "", exam: c?.exam ?? "JAMB", teacher: c?.teacher ?? "",
    starts_at: c ? lagos(c.starts_at) : "", minutes: String(c?.minutes ?? 60), access: c?.access ?? "free",
    price_naira: c?.price_kobo ? String(c.price_kobo / 100) : "", seats: c?.seats ? String(c.seats) : "", status: c?.status ?? "draft",
    web_only: c?.web_only ?? false, join_url: c?.join_url ?? "", recording_url: c?.recording_url ?? "",
  });
  const id = c?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const submit = () => start(async () => {
    const r = await saveClass({ id: c?.id, ...f });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    onDone();
    router.refresh();
  });
  const field = (k: keyof typeof f, label: string, extra?: React.InputHTMLAttributes<HTMLInputElement>) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><input id={`${k}-${id}`} className={inputCls} value={String(f[k])} onChange={set(k)} {...extra} /></div>
  );
  return (
    <div className="grid gap-4">
      <div className="grid gap-3 md:grid-cols-[2fr_1fr]">
        {field("title", "Class title", { maxLength: 120, placeholder: "JAMB Physics: waves and sound" })}
        {field("teacher", "Teacher", { maxLength: 80 })}
      </div>
      <div><Label htmlFor={`about-${id}`}>What the class covers (optional)</Label>
        <textarea id={`about-${id}`} rows={3} maxLength={2000} className={inputCls} value={f.about} onChange={set("about")} /></div>
      <div className="grid gap-3 md:grid-cols-4">
        {field("starts_at", "Starts (Lagos time)", { type: "datetime-local" })}
        {field("minutes", "Minutes", { type: "number", min: 10, max: 480 })}
        <div><Label htmlFor={`subject-${id}`}>Subject</Label>
          <select id={`subject-${id}`} className={inputCls} value={f.subject_id} onChange={set("subject_id")}>
            <option value="">Any / several</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select></div>
        <div><Label htmlFor={`exam-${id}`}>Exam</Label>
          <select id={`exam-${id}`} className={inputCls} value={f.exam} onChange={set("exam")}>
            <option value="">Any</option>{exams.map((e) => <option key={e} value={e}>{e}</option>)}
          </select></div>
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        <div><Label htmlFor={`access-${id}`}>Who can join</Label>
          <select id={`access-${id}`} className={inputCls} value={f.access} onChange={set("access")}>
            <option value="free">Free: anyone who registers</option><option value="premium">Premium students</option><option value="paid">Paid: register and pay</option>
          </select></div>
        {f.access === "paid" ? field("price_naira", "Price (₦)", { type: "number", min: 50 }) : <div />}
        {field("seats", "Seats (empty = no limit)", { type: "number", min: 0 })}
        <div><Label htmlFor={`status-${id}`}>Status</Label>
          <select id={`status-${id}`} className={inputCls} value={f.status} onChange={set("status")}>
            <option value="draft">Draft (hidden)</option><option value="published">Published</option><option value="cancelled">Cancelled</option>
          </select></div>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {field("join_url", "Class link (Zoom, Google Meet…)", { placeholder: "https://", maxLength: 500 })}
        {field("recording_url", "Recording link (after the class)", { placeholder: "https://", maxLength: 500 })}
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.web_only} onChange={(e) => setF({ ...f, web_only: e.target.checked })} /> Website JAMB classes only (not in the app list)</label>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{c ? "Save" : "Add class"}</Button></div>
      </div>
    </div>
  );
}

function Students({ id }: { id: string }) {
  const [rows, setRows] = useState<Student[] | null>(null);
  const [pending, start] = useTransition();
  if (rows === null) return <Button size="sm" variant="ghost" disabled={pending} onClick={() => start(async () => { const r = await classStudents(id); if (r.ok) setRows(r.data ?? []); else toast.error(r.error); })}>Show students</Button>;
  if (!rows.length) return <p className="text-xs text-muted-foreground">Nobody has registered yet.</p>;
  return (
    <ul className="mt-2 max-h-56 w-full overflow-auto rounded-xl border text-xs">
      {rows.map((s, i) => (
        <li key={i} className="flex flex-wrap gap-2 border-b px-3 py-1.5 last:border-0">
          <b>{s.name}</b><span className="text-muted-foreground">{s.email}</span>
          <span className="ml-auto text-muted-foreground">{s.paid ? "Paid · " : ""}{s.joined_at ? `Joined ${when(s.joined_at)}` : "Not joined"}</span>
        </li>
      ))}
    </ul>
  );
}

export function ClassList({ classes, subjects, exams }: { classes: AdminClass[]; subjects: Subject[]; exams: string[] }) {
  const router = useRouter();
  const [editing, setEditing] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [now] = useState(() => new Date().getTime());
  const upcoming = classes.filter((c) => new Date(c.starts_at).getTime() + c.minutes * 60000 >= now);
  const past = classes.filter((c) => new Date(c.starts_at).getTime() + c.minutes * 60000 < now).reverse();
  const row = (c: AdminClass) => (
    <li key={c.id} className="p-4">
      {editing === c.id ? <Editor c={c} subjects={subjects} exams={exams} onDone={() => setEditing(null)} /> : (
        <div className="flex flex-wrap items-start gap-3">
          <div className="min-w-0 flex-1">
            <p className="font-bold">{c.title} <span className="font-normal text-muted-foreground">· {c.teacher}</span></p>
            <p className="text-sm text-muted-foreground">{when(c.starts_at)} · {c.minutes} min · {ACCESS[c.access]}{c.price_kobo ? ` ₦${(c.price_kobo / 100).toLocaleString("en-NG")}` : ""}{c.seats ? ` · ${c.seats} seats` : ""}</p>
            <p className="text-xs text-muted-foreground">{c.counts.reg} registered{c.counts.paid ? ` (${c.counts.paid} paid)` : ""} · {c.counts.joined} joined · {c.join_url ? "link set" : "no link yet"}{c.recording_url ? " · recording set" : ""}</p>
            <Students id={c.id} />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Pill tone={c.status === "published" ? "ok" : c.status === "cancelled" ? "error" : "neutral"}>{c.status === "published" ? "Published" : c.status === "cancelled" ? "Cancelled" : "Draft"}</Pill>
            {c.web_only ? <Pill tone="info">Website</Pill> : null}
            {!c.join_url && c.status === "published" ? <Pill tone="warn">Add the link</Pill> : null}
            <Button size="sm" variant="outline" disabled={pending} onClick={() => setEditing(c.id)}>Edit</Button>
            <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${c.title}?`)) start(async () => { const r = await deleteClass(c.id); if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error); }); }}>Delete</Button>
          </div>
        </div>
      )}
    </li>
  );
  return (
    <>
      <div className="mb-4 flex justify-end"><Button onClick={() => setEditing("new")} disabled={editing === "new"}><Plus size={18} weight="bold" /> Add class</Button></div>
      {editing === "new" ? <Panel title="New class" className="mb-4"><Editor subjects={subjects} exams={exams} onDone={() => setEditing(null)} /></Panel> : null}
      <Panel title={`Upcoming and live (${upcoming.length})`} bodyClassName="p-0" className="mb-4">
        {upcoming.length ? <ul className="divide-y">{upcoming.map(row)}</ul> : <EmptyState title="No classes coming up">Add a class: it shows in the app as soon as it is published.</EmptyState>}
      </Panel>
      <Panel title={`Past 60 days (${past.length})`} bodyClassName="p-0">
        {past.length ? <ul className="divide-y">{past.map(row)}</ul> : <EmptyState title="No past classes">Finished classes show here. Add the recording link so students can watch it.</EmptyState>}
      </Panel>
    </>
  );
}
