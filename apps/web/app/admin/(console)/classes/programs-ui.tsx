"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ArrowSquareOut, CalendarPlus, Copy, ImageSquare, Plus, Trash, UploadSimple } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill, when } from "@/components/admin/ui";
import { deleteClass, deleteProgram, programStudents, saveProgram, saveSession } from "./actions";
import { ClassWork } from "./class-work";

// Classes v2 (owner, 14 Nov 2026; D-163): a programme such as "JAMB Marathon Class" is made once (price, flyer, details);
// sessions are then added to it. Students pay once and attend every session.

export type AdminProgram = {
  id: string; slug: string; title: string; tagline: string | null; about: string | null; highlights: string[]; exam: string | null; subjects: string | null;
  teacher: string | null; teacher_bio: string | null; teacher_photo: string | null; flyer_path: string | null; schedule_note: string | null;
  access: "free" | "premium" | "paid"; price_kobo: number | null; compare_kobo: number | null; seats: number | null; starts_on: string | null; ends_on: string | null;
  faq: { q: string; a: string }[]; status: "draft" | "published" | "closed"; on_website: boolean; sort: number;
};
export type AdminSession = {
  id: string; program_id: string | null; title: string; about: string | null; teacher: string; starts_at: string; minutes: number;
  status: "draft" | "published" | "cancelled"; join_url: string | null; recording_url: string | null; counts: { reg: number; joined: number; paid: number };
};
type Stats = Record<string, { enrolled: number; paid: number; revenue_kobo: number }>;

const ngn = (kobo: number) => `₦${Math.round(kobo / 100).toLocaleString("en-NG")}`;
const lagos = (iso: string) => new Date(new Date(iso).getTime() + 3600000).toISOString().slice(0, 16);
const ACCESS = { free: "Free", premium: "Premium", paid: "Paid" } as const;

/** Uploads one picture to the private bucket and keeps its key. */
function ImageUpload({ label, value, preview, onChange, hint }: { label: string; value: string; preview?: string | null; onChange: (key: string) => void; hint: string }) {
  const [busy, setBusy] = useState(false);
  const [local, setLocal] = useState<string | null>(null);
  const src = local ?? (value ? preview ?? null : null);
  async function onFile(f: File) {
    setBusy(true);
    try {
      const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind: "class_image", contentType: f.type, size: f.size }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Could not upload.");
      const put = await fetch(j.url, { method: "PUT", headers: { "content-type": f.type }, body: f });
      if (!put.ok) throw new Error("The upload did not finish. Try again.");
      setLocal(URL.createObjectURL(f));
      onChange(j.key);
      toast.success("Picture uploaded. Save to keep it.");
    } catch (e) { toast.error(e instanceof Error ? e.message : "Could not upload."); } finally { setBusy(false); }
  }
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      <div className="flex items-center gap-3">
        <div className="grid size-20 shrink-0 place-items-center overflow-hidden rounded-xl border bg-muted">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          {src ? <img src={src} alt="" className="size-full object-cover" /> : <ImageSquare size={28} className="text-muted-foreground" />}
        </div>
        <div className="space-y-1">
          <label className="inline-flex h-9 cursor-pointer items-center gap-2 rounded-lg border px-3 text-sm font-semibold">
            <UploadSimple size={16} /> {busy ? "Uploading…" : value ? "Change" : "Upload"}
            <input type="file" accept="image/webp,image/png,image/jpeg" className="hidden" disabled={busy} onChange={(e) => { const f = e.target.files?.[0]; if (f) void onFile(f); e.target.value = ""; }} />
          </label>
          {value ? <button type="button" className="block text-xs text-muted-foreground underline" onClick={() => { setLocal(null); onChange(""); }}>Remove</button> : null}
          <p className="text-xs text-muted-foreground">{hint}</p>
        </div>
      </div>
    </div>
  );
}

function ProgramEditor({ p, previews, exams, onDone }: { p?: AdminProgram; previews: Record<string, string>; exams: string[]; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({
    title: p?.title ?? "", slug: p?.slug ?? "", tagline: p?.tagline ?? "", about: p?.about ?? "", highlights: (p?.highlights ?? []).join("\n"),
    exam: p?.exam ?? "JAMB", subjects: p?.subjects ?? "", teacher: p?.teacher ?? "", teacher_bio: p?.teacher_bio ?? "",
    teacher_photo: p?.teacher_photo ?? "", flyer_path: p?.flyer_path ?? "", schedule_note: p?.schedule_note ?? "", access: p?.access ?? "paid",
    price_naira: p?.price_kobo ? String(p.price_kobo / 100) : "", compare_naira: p?.compare_kobo ? String(p.compare_kobo / 100) : "",
    seats: p?.seats ? String(p.seats) : "", starts_on: p?.starts_on ?? "", ends_on: p?.ends_on ?? "", status: p?.status ?? "draft",
    on_website: p?.on_website ?? true, sort: String(p?.sort ?? 0),
  });
  const [faq, setFaq] = useState<{ q: string; a: string }[]>(p?.faq ?? []);
  const id = p?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const field = (k: keyof typeof f, label: string, extra?: React.InputHTMLAttributes<HTMLInputElement>) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><input id={`${k}-${id}`} className={inputCls} value={String(f[k])} onChange={set(k)} {...extra} /></div>
  );
  const area = (k: keyof typeof f, label: string, rows: number, max: number, ph?: string) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><textarea id={`${k}-${id}`} rows={rows} maxLength={max} placeholder={ph} className={inputCls} value={String(f[k])} onChange={set(k)} /></div>
  );
  const submit = () => start(async () => {
    const r = await saveProgram({ id: p?.id, ...f, faq: faq.filter((x) => x.q.trim() && x.a.trim()) });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    onDone();
    router.refresh();
  });
  return (
    <div className="grid gap-5">
      <div className="rounded-xl bg-muted/50 p-3 text-sm text-muted-foreground">
        Make the class once: name, price, flyer and details. Then add sessions to it (times and links). Students pay once and can join every session.
        Paid classes that are published and “on the website” show on <b>cbt.solutiontee.com/classes</b>.
      </div>
      <div className="grid gap-3 md:grid-cols-[2fr_1fr]">
        {field("title", "Class name", { maxLength: 120, placeholder: "JAMB Marathon Class" })}
        {field("slug", "Short web link (optional)", { maxLength: 80, placeholder: "jamb-marathon" })}
      </div>
      {field("tagline", "One line that sells it", { maxLength: 200, placeholder: "Cover the whole JAMB syllabus in 8 weeks, live with top teachers" })}
      <div className="grid gap-4 md:grid-cols-2">
        <ImageUpload label="Flyer (shown on the website and in the app)" value={f.flyer_path} preview={previews[f.flyer_path]} onChange={(k) => setF({ ...f, flyer_path: k })} hint="Portrait 4:5 (e.g. 1080 × 1350) works best. Max 3 MB." />
        <ImageUpload label="Teacher photo (optional)" value={f.teacher_photo} preview={previews[f.teacher_photo]} onChange={(k) => setF({ ...f, teacher_photo: k })} hint="A square face photo." />
      </div>
      {area("about", "About the class (full details)", 6, 6000, "What it is, who it is for, how it works, what students get…")}
      {area("highlights", "What students will learn or get (one per line)", 4, 3000, "Every JAMB topic, step by step\nWeekly mock tests and reviews\nRecordings of every session")}
      <div className="grid gap-3 md:grid-cols-3">
        <div><Label htmlFor={`exam-${id}`}>Exam</Label>
          <select id={`exam-${id}`} className={inputCls} value={f.exam} onChange={set("exam")}><option value="">Any</option>{exams.map((e) => <option key={e} value={e}>{e}</option>)}</select></div>
        {field("subjects", "Subjects", { maxLength: 200, placeholder: "English, Maths, Physics, Chemistry" })}
        {field("schedule_note", "When it holds", { maxLength: 200, placeholder: "Mon, Wed, Fri · 6–8 pm" })}
      </div>
      <div className="grid gap-3 md:grid-cols-[1fr_2fr]">
        {field("teacher", "Teacher", { maxLength: 80 })}
        {area("teacher_bio", "About the teacher (optional)", 2, 1200)}
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        <div><Label htmlFor={`access-${id}`}>Who can join</Label>
          <select id={`access-${id}`} className={inputCls} value={f.access} onChange={set("access")}>
            <option value="paid">Paid: pay once</option><option value="free">Free: anyone who registers</option><option value="premium">Premium students</option>
          </select></div>
        {f.access === "paid" ? field("price_naira", "Price (₦)", { type: "number", min: 50 }) : <div />}
        {f.access === "paid" ? field("compare_naira", "Old price (₦, optional)", { type: "number", min: 0 }) : <div />}
        {field("seats", "Seats (empty = no limit)", { type: "number", min: 0 })}
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        {field("starts_on", "Starts on", { type: "date" })}
        {field("ends_on", "Ends on (empty = no end)", { type: "date" })}
        <div><Label htmlFor={`status-${id}`}>Status</Label>
          <select id={`status-${id}`} className={inputCls} value={f.status} onChange={set("status")}>
            <option value="draft">Draft (hidden)</option><option value="published">Published (on sale)</option><option value="closed">Closed (no new students)</option>
          </select></div>
        {field("sort", "Order (0 first)", { type: "number", min: 0 })}
      </div>
      <div className="space-y-2">
        <Label>Questions and answers (shown on the class page)</Label>
        {faq.map((x, i) => (
          <div key={i} className="grid gap-2 rounded-xl border p-2 md:grid-cols-[1fr_2fr_auto]">
            <input className={inputCls} placeholder="Question" value={x.q} maxLength={200} onChange={(e) => setFaq(faq.map((y, j) => (j === i ? { ...y, q: e.target.value } : y)))} />
            <input className={inputCls} placeholder="Answer" value={x.a} maxLength={800} onChange={(e) => setFaq(faq.map((y, j) => (j === i ? { ...y, a: e.target.value } : y)))} />
            <Button variant="ghost" size="sm" onClick={() => setFaq(faq.filter((_, j) => j !== i))} aria-label="Remove question"><Trash size={16} /></Button>
          </div>
        ))}
        <Button variant="outline" size="sm" onClick={() => setFaq([...faq, { q: "", a: "" }])}><Plus size={16} /> Add a question</Button>
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.on_website} onChange={(e) => setF({ ...f, on_website: e.target.checked })} /> Show on cbt.solutiontee.com/classes (paid classes only)</label>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{p ? "Save class" : "Create class"}</Button></div>
      </div>
    </div>
  );
}

function SessionEditor({ program, s, count, onDone }: { program: AdminProgram; s?: AdminSession; count: number; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({
    title: s?.title ?? `${program.title} · Session ${count + 1}`, about: s?.about ?? "", teacher: s?.teacher ?? program.teacher ?? "",
    starts_at: s ? lagos(s.starts_at) : "", minutes: String(s?.minutes ?? 90), status: s?.status ?? "published",
    join_url: s?.join_url ?? "", recording_url: s?.recording_url ?? "",
  });
  const id = s?.id ?? `new-${program.id}`;
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });
  const field = (k: keyof typeof f, label: string, extra?: React.InputHTMLAttributes<HTMLInputElement>) => (
    <div><Label htmlFor={`${k}-${id}`}>{label}</Label><input id={`${k}-${id}`} className={inputCls} value={String(f[k])} onChange={set(k)} {...extra} /></div>
  );
  const submit = () => start(async () => {
    const r = await saveSession({ id: s?.id, program_id: program.id, ...f });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    onDone();
    router.refresh();
  });
  return (
    <div className="grid gap-3 rounded-xl border bg-card p-3">
      <div className="grid gap-3 md:grid-cols-[2fr_1fr]">{field("title", "Session title", { maxLength: 120 })}{field("teacher", "Teacher", { maxLength: 80 })}</div>
      <div className="grid gap-3 md:grid-cols-3">
        {field("starts_at", "Starts (Lagos time)", { type: "datetime-local" })}
        {field("minutes", "Length (minutes)", { type: "number", min: 10, max: 480 })}
        <div><Label htmlFor={`status-${id}`}>Status</Label>
          <select id={`status-${id}`} className={inputCls} value={f.status} onChange={set("status")}>
            <option value="published">Published</option><option value="draft">Draft (hidden)</option><option value="cancelled">Cancelled</option>
          </select></div>
      </div>
      <div className="grid gap-3 md:grid-cols-2">
        {field("join_url", "Class link (Zoom, Google Meet…)", { placeholder: "https://", maxLength: 500 })}
        {field("recording_url", "Recording link (after the session)", { placeholder: "https://", maxLength: 500 })}
      </div>
      <div className="flex justify-end gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{s ? "Save session" : "Add session"}</Button></div>
    </div>
  );
}

function Students({ id }: { id: string }) {
  const [rows, setRows] = useState<{ name: string; email: string | null; enrolled_at: string; paid: boolean }[] | null>(null);
  const [pending, start] = useTransition();
  if (rows === null) return <Button size="sm" variant="ghost" disabled={pending} onClick={() => start(async () => { const r = await programStudents(id); if (r.ok) setRows(r.data ?? []); else toast.error(r.error); })}>Show students</Button>;
  if (!rows.length) return <p className="text-xs text-muted-foreground">Nobody has joined yet.</p>;
  return (
    <ul className="mt-2 max-h-56 w-full overflow-auto rounded-xl border text-xs">
      {rows.map((s, i) => (
        <li key={i} className="flex flex-wrap gap-2 border-b px-3 py-1.5 last:border-0">
          <b>{s.name}</b><span className="text-muted-foreground">{s.email}</span><span className="ml-auto text-muted-foreground">{s.paid ? "Paid · " : ""}{when(s.enrolled_at)}</span>
        </li>
      ))}
    </ul>
  );
}

export function ProgramList({ programs, sessions, stats, previews, exams, site }: {
  programs: AdminProgram[]; sessions: AdminSession[]; stats: Stats; previews: Record<string, string>; exams: string[]; site: string;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState<string | null>(null);
  const [editSession, setEditSession] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [now] = useState(() => new Date().getTime());
  return (
    <Panel title={`Classes students buy once (${programs.length})`} className="mb-4"
      actions={<Button size="sm" onClick={() => setEditing("new")} disabled={editing === "new"}><Plus size={16} weight="bold" /> New class</Button>}>
      {editing === "new" ? <div className="mb-4 rounded-2xl border p-4"><ProgramEditor previews={previews} exams={exams} onDone={() => setEditing(null)} /></div> : null}
      {!programs.length && editing !== "new" ? (
        <EmptyState title="No classes yet">Create one (for example “JAMB Marathon Class”), set it to Paid with a price and flyer, then add its sessions.</EmptyState>
      ) : null}
      <ul className="grid gap-3">
        {programs.map((p) => {
          const st = stats[p.id] ?? { enrolled: 0, paid: 0, revenue_kobo: 0 };
          const mine = sessions.filter((s) => s.program_id === p.id);
          const upcoming = mine.filter((s) => new Date(s.starts_at).getTime() + s.minutes * 60000 >= now);
          const past = mine.filter((s) => new Date(s.starts_at).getTime() + s.minutes * 60000 < now).reverse();
          const url = `${site}/classes/${p.slug}`;
          return (
            <li key={p.id} className="rounded-2xl border p-4">
              {editing === p.id ? <ProgramEditor p={p} previews={previews} exams={exams} onDone={() => setEditing(null)} /> : (
                <>
                  <div className="flex flex-wrap items-start gap-4">
                    <div className="grid h-24 w-20 shrink-0 place-items-center overflow-hidden rounded-xl bg-muted">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      {p.flyer_path && previews[p.flyer_path] ? <img src={previews[p.flyer_path]} alt="" className="size-full object-cover" /> : <ImageSquare size={26} className="text-muted-foreground" />}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="text-lg font-bold">{p.title}</p>
                      {p.tagline ? <p className="text-sm text-muted-foreground">{p.tagline}</p> : null}
                      <p className="mt-1 text-sm">{ACCESS[p.access]}{p.price_kobo ? ` · ${ngn(p.price_kobo)}` : ""}{p.compare_kobo ? <s className="ml-1 text-muted-foreground">{ngn(p.compare_kobo)}</s> : null}{p.schedule_note ? ` · ${p.schedule_note}` : ""}</p>
                      <p className="text-xs text-muted-foreground">{st.enrolled} students{st.paid ? ` (${st.paid} paid · ${ngn(st.revenue_kobo)})` : ""} · {upcoming.length} sessions coming · {past.length} done{p.seats ? ` · ${p.seats} seats` : ""}</p>
                      <div className="mt-1 flex flex-wrap gap-2"><Students id={p.id} /></div>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <Pill tone={p.status === "published" ? "ok" : p.status === "closed" ? "neutral" : "warn"}>{p.status === "published" ? "On sale" : p.status === "closed" ? "Closed" : "Draft"}</Pill>
                      {p.access === "paid" && p.on_website && p.status === "published" ? <Pill tone="info">Website</Pill> : null}
                      {p.access === "paid" && p.on_website ? (
                        <>
                          <Button size="sm" variant="ghost" onClick={() => { void navigator.clipboard.writeText(url); toast.success("Link copied."); }}><Copy size={16} /> Link</Button>
                          <a href={url} target="_blank" rel="noreferrer" className="inline-flex h-8 items-center gap-1 rounded-lg px-2 text-sm font-semibold"><ArrowSquareOut size={16} /> View</a>
                        </>
                      ) : null}
                      <Button size="sm" variant="outline" onClick={() => setEditing(p.id)}>Edit</Button>
                      <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${p.title}? Its sessions stay as single classes.`)) start(async () => { const r = await deleteProgram(p.id); if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error); }); }}>Delete</Button>
                    </div>
                  </div>
                  <div className="mt-4 rounded-xl bg-muted/40 p-3">
                    <div className="mb-2 flex items-center justify-between gap-2">
                      <p className="text-sm font-bold">Sessions</p>
                      <Button size="sm" variant="outline" onClick={() => setAdding(p.id)} disabled={adding === p.id}><CalendarPlus size={16} /> Add session</Button>
                    </div>
                    {adding === p.id ? <SessionEditor program={p} count={mine.length} onDone={() => setAdding(null)} /> : null}
                    {!mine.length && adding !== p.id ? <p className="text-sm text-muted-foreground">No sessions yet. Add the first one: students who paid are reminded before each session.</p> : null}
                    <ul className="divide-y">
                      {[...upcoming, ...past].map((s) => (
                        <li key={s.id} className="py-2">
                          {editSession === s.id ? <SessionEditor program={p} s={s} count={mine.length} onDone={() => setEditSession(null)} /> : (
                            <div className="flex flex-wrap items-center gap-2 text-sm">
                              <div className="min-w-0 flex-1">
                                <p className="font-semibold">{s.title}</p>
                                <p className="text-xs text-muted-foreground">{when(s.starts_at)} · {s.minutes} min · {s.counts.joined} joined · {s.join_url ? "link set" : "no link yet"}{s.recording_url ? " · recording set" : ""}</p>
                                <ClassWork classId={s.id} />
                              </div>
                              {s.status !== "published" ? <Pill tone={s.status === "cancelled" ? "error" : "neutral"}>{s.status === "cancelled" ? "Cancelled" : "Draft"}</Pill> : null}
                              {!s.join_url && s.status === "published" && new Date(s.starts_at).getTime() + s.minutes * 60000 >= now ? <Pill tone="warn">Add the link</Pill> : null}
                              <Button size="sm" variant="outline" onClick={() => setEditSession(s.id)}>Edit</Button>
                              <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${s.title}?`)) start(async () => { const r = await deleteClass(s.id); if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error); }); }}>Delete</Button>
                            </div>
                          )}
                        </li>
                      ))}
                    </ul>
                  </div>
                </>
              )}
            </li>
          );
        })}
      </ul>
    </Panel>
  );
}
