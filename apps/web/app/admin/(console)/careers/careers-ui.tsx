"use client";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill } from "@/components/admin/ui";
import { deleteCareer, saveCareer, setCareerFlag } from "./actions";

export type Career = {
  id: number; name: string; field: string; course: string; years: number; summary: string; skills: string[]; universities: string[];
  earnings: string | null; jamb_subjects: string[]; jamb_note: string | null; olevel: string | null; after_school: string | null;
  checked: boolean; active: boolean; sort: number; updated_at: string;
};
type Subject = { code: string; name: string };

const FIELDS = ["Health", "Engineering and Tech", "Science and Agriculture", "Business", "Law and Social Sciences", "Arts and Education"];

function blank(sort: number) {
  return { name: "", field: FIELDS[0], course: "", years: "4", summary: "", skills: "", universities: "", earnings: "", s1: "", s2: "", s3: "",
    jamb_note: "", olevel: "", after_school: "", sort: String(sort), active: true, checked: false };
}
function fromCareer(c: Career) {
  const [s1 = "", s2 = "", s3 = ""] = c.jamb_subjects;
  return { name: c.name, field: c.field, course: c.course, years: String(c.years), summary: c.summary, skills: c.skills.join("\n"),
    universities: c.universities.join("\n"), earnings: c.earnings ?? "", s1, s2, s3, jamb_note: c.jamb_note ?? "", olevel: c.olevel ?? "",
    after_school: c.after_school ?? "", sort: String(c.sort), active: c.active, checked: c.checked };
}

function Editor({ career, subjects, fields, nextSort, onDone }: { career?: Career; subjects: Subject[]; fields: string[]; nextSort: number; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState(career ? fromCareer(career) : blank(nextSort));
  const id = career?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const submit = () =>
    start(async () => {
      const { s1, s2, s3, ...rest } = f;
      const r = await saveCareer({ id: career?.id, ...rest, jamb_subjects: [s1, s2, s3].filter(Boolean) });
      if (!r.ok) return void toast.error(r.error);
      toast.success(r.message);
      onDone();
      router.refresh();
    });
  const others = subjects.filter((s) => s.code !== "eng");
  const field = (k: keyof typeof f, label: string, extra?: React.InputHTMLAttributes<HTMLInputElement>) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><input id={`${k}-${id}`} className={inputCls} value={String(f[k])} onChange={set(k)} {...extra} /></div>
  );
  const area = (k: keyof typeof f, label: string, rows: number, max: number, hint?: string) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><textarea id={`${k}-${id}`} rows={rows} maxLength={max} className={inputCls} value={String(f[k])} onChange={set(k)} />
      {hint ? <p className="mt-1 text-xs text-muted-foreground">{hint}</p> : null}</div>
  );
  return (
    <div className="grid gap-4">
      <div className="grid gap-3 md:grid-cols-[1fr_1fr_1fr_90px_90px]">
        {field("name", "Career", { maxLength: 80, placeholder: "Medical Doctor" })}
        <div><Label htmlFor={`field-${id}`}>Group</Label>
          <input id={`field-${id}`} list={`fields-${id}`} className={inputCls} value={f.field} maxLength={40} onChange={set("field")} />
          <datalist id={`fields-${id}`}>{fields.map((x) => <option key={x} value={x} />)}</datalist>
        </div>
        {field("course", "University course", { maxLength: 120, placeholder: "Medicine and Surgery (MBBS)" })}
        {field("years", "Years", { type: "number", min: 1, max: 8 })}
        {field("sort", "Order", { type: "number", min: 0 })}
      </div>
      {area("summary", "What the job is", 2, 600)}
      <div>
        <Label>JAMB subjects</Label>
        <div className="mt-1 grid gap-2 md:grid-cols-4">
          <div className={`${inputCls} flex items-center text-muted-foreground`}>Use of English (always)</div>
          {(["s1", "s2", "s3"] as const).map((k, i) => (
            <select key={k} aria-label={`JAMB subject ${i + 2}`} className={inputCls} value={f[k]} onChange={set(k)}>
              <option value="">Choose…</option>
              {others.map((s) => <option key={s.code} value={s.code}>{s.name}</option>)}
            </select>
          ))}
        </div>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {area("jamb_note", "Note on the combination (optional)", 2, 300, "For example: Mathematics can replace Physics in some schools.")}
        {area("olevel", "O'level (WAEC / NECO) credits", 2, 300)}
        {area("skills", "Skills (one per line)", 4, 1000)}
        {area("universities", "Good universities (one per line)", 4, 2000)}
        {area("after_school", "After school", 2, 300, "Internship, NYSC, licence or professional exams.")}
        {area("earnings", "Pay (rough guide)", 2, 300)}
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Show in the app</label>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.checked} onChange={(e) => setF({ ...f, checked: e.target.checked })} /> Checked against this year&apos;s brochure</label>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{career ? "Save" : "Add career"}</Button></div>
      </div>
    </div>
  );
}

export function CareerList({ careers, subjects }: { careers: Career[]; subjects: Subject[] }) {
  const router = useRouter();
  const [editing, setEditing] = useState<number | "new" | null>(null);
  const [q, setQ] = useState("");
  const [group, setGroup] = useState("");
  const [pending, start] = useTransition();
  const names = useMemo(() => new Map(subjects.map((s) => [s.code, s.name])), [subjects]);
  const fields = useMemo(() => [...new Set([...FIELDS, ...careers.map((c) => c.field)])], [careers]);
  const nextSort = (careers.at(-1)?.sort ?? 0) + 10;
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) =>
    start(async () => {
      const r = await fn();
      if (!r.ok) toast.error(r.error ?? "Could not save");
      else { toast.success(r.message ?? "Done"); router.refresh(); }
    });
  const needle = q.trim().toLowerCase();
  const shown = careers.filter((c) => (!group || c.field === group) && (!needle || `${c.name} ${c.course}`.toLowerCase().includes(needle)));
  const checked = careers.filter((c) => c.checked).length;
  const sel = "h-10 rounded-xl border border-input bg-card px-3 text-sm";

  return (
    <>
      <Panel className="mb-4">
        <div className="flex flex-wrap items-center gap-3">
          <p className="text-sm">
            <b>{checked} of {careers.length}</b> checked against the brochure.{" "}
            <span className="text-muted-foreground">The sample careers are a starting point: check each JAMB combination before you tick it.</span>
          </p>
          <Button className="ml-auto" onClick={() => setEditing("new")} disabled={editing === "new"}><Plus size={18} weight="bold" /> Add career</Button>
        </div>
      </Panel>
      {editing === "new" ? <Panel title="New career" className="mb-4"><Editor subjects={subjects} fields={fields} nextSort={nextSort} onDone={() => setEditing(null)} /></Panel> : null}
      <Panel title={`All careers (${shown.length})`} bodyClassName="p-0"
        actions={<div className="flex gap-2">
          <input aria-label="Search careers" placeholder="Search" className={`${sel} w-40`} value={q} onChange={(e) => setQ(e.target.value)} />
          <select aria-label="Group" className={sel} value={group} onChange={(e) => setGroup(e.target.value)}>
            <option value="">All groups</option>{fields.map((x) => <option key={x} value={x}>{x}</option>)}
          </select>
        </div>}>
        {shown.length === 0 ? <EmptyState title="No careers match">Clear the search, or add a career.</EmptyState> : (
          <ul className="divide-y">
            {shown.map((c) => (
              <li key={c.id} className="p-4">
                {editing === c.id ? <Editor career={c} subjects={subjects} fields={fields} nextSort={nextSort} onDone={() => setEditing(null)} /> : (
                  <div className="flex flex-wrap items-start gap-3">
                    <span className="w-10 pt-0.5 text-xs tabular-nums text-muted-foreground">#{c.sort}</span>
                    <div className={`min-w-0 flex-1 ${c.active ? "" : "opacity-50"}`}>
                      <p className="font-bold">{c.name} <span className="font-normal text-muted-foreground">· {c.course}</span></p>
                      <p className="mt-0.5 text-sm">
                        <span className="text-muted-foreground">JAMB:</span> English, {c.jamb_subjects.map((s) => names.get(s) ?? s).join(", ") || "not set"}
                      </p>
                      {c.jamb_note ? <p className="text-xs text-muted-foreground">{c.jamb_note}</p> : null}
                      <p className="mt-0.5 text-xs text-muted-foreground">{c.field}</p>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      {c.checked ? <Pill tone="ok">Checked</Pill> : <Pill tone="warn">Not checked</Pill>}
                      {!c.active ? <Pill>Hidden</Pill> : null}
                      <Button size="sm" variant="outline" onClick={() => setEditing(c.id)} disabled={pending}>Edit</Button>
                      <Button size="sm" variant="outline" onClick={() => act(() => setCareerFlag(c.id, "checked", !c.checked))} disabled={pending}>{c.checked ? "Uncheck" : "Mark checked"}</Button>
                      <Button size="sm" variant="outline" onClick={() => act(() => setCareerFlag(c.id, "active", !c.active))} disabled={pending}>{c.active ? "Hide" : "Show"}</Button>
                      <Button size="sm" variant="ghost" onClick={() => { if (confirm(`Delete ${c.name}? Students who picked it will be asked to pick again.`)) act(() => deleteCareer(c.id)); }} disabled={pending}>Delete</Button>
                    </div>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </>
  );
}
