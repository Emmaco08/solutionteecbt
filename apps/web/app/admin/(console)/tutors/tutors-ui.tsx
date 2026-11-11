"use client";
import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill, when } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import type { ActionResult } from "@/lib/result";
import { deletePlan, replyTutor, savePlan, saveTutor, updateRequest } from "./actions";

export type TRequest = {
  id: string; user_id: string; name: string; email: string | null; phone: string | null; subject: string | null; level: string; goals: string;
  times: string | null; status: "new" | "replied" | "matched" | "closed"; tutor_id: string | null; created_at: string; updated_at: string;
  plan_until: string | null; messages: { from_staff: boolean; body: string; at: string }[];
};
type Tutor = { id: string; name: string; subjects: string | null; bio: string | null; whatsapp: string | null; phone: string | null; active: boolean };
type Plan = { id: string; name: string; description: string | null; price_kobo: number; days: number; sessions: number | null; active: boolean; sort: number };

const LEVEL: Record<string, string> = { jamb: "JAMB", waec: "WAEC", neco: "NECO", post_utme: "Post-UTME", other: "Other" };
const STATUS = { new: "New", replied: "Replied", matched: "Tutor assigned", closed: "Closed" } as const;
const TONE = { new: "warn", replied: "info", matched: "ok", closed: "neutral" } as const;
const FILTERS = [["open", "Open"], ["new", "New"], ["replied", "Replied"], ["matched", "Assigned"], ["closed", "Closed"], ["all", "All"]] as const;
const naira = (k: number) => `₦${(k / 100).toLocaleString("en-NG")}`;

function useAct() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<ActionResult>, after?: () => void) => start(async () => {
    const r = await fn();
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message ?? "Saved.");
    after?.();
    router.refresh();
  });
  return { pending, run };
}

function RequestRow({ r, tutors }: { r: TRequest; tutors: Tutor[] }) {
  const [open, setOpen] = useState(r.status === "new");
  const [reply, setReply] = useState("");
  const { pending, run } = useAct();
  const last = r.messages[r.messages.length - 1];
  return (
    <li className="p-4">
      <div className="flex flex-wrap items-start gap-3">
        <button type="button" className="min-w-0 flex-1 text-left" onClick={() => setOpen(!open)} aria-expanded={open}>
          <p className="font-bold">{r.name} <span className="font-normal text-muted-foreground">· {LEVEL[r.level] ?? r.level}{r.subject ? ` · ${r.subject}` : ""}</span></p>
          <p className="line-clamp-2 text-sm">{r.goals}</p>
          <p className="text-xs text-muted-foreground">
            Asked {when(r.created_at)}{r.times ? ` · Free times: ${r.times}` : ""}{last ? ` · Last: ${last.from_staff ? "us" : "student"} ${when(last.at)}` : ""}
          </p>
        </button>
        <div className="flex flex-wrap items-center gap-2">
          <Pill tone={TONE[r.status]}>{STATUS[r.status]}</Pill>
          {r.plan_until ? <Pill tone="ok">Plan until {new Date(r.plan_until).toLocaleDateString("en-NG", { day: "numeric", month: "short" })}</Pill> : <Pill tone="neutral">No plan</Pill>}
        </div>
      </div>
      {open ? (
        <div className="mt-3 grid gap-3 rounded-2xl border p-3">
          <p className="text-xs text-muted-foreground">{r.email ?? "No email"}{r.phone ? ` · ${r.phone}` : ""}</p>
          <ul className="grid max-h-80 gap-2 overflow-auto">
            {r.messages.map((m, i) => (
              <li key={i} className={cn("max-w-[85%] whitespace-pre-wrap rounded-2xl px-3 py-2 text-sm", m.from_staff ? "ml-auto bg-info-soft text-on-info-soft" : "bg-muted")}>
                {m.body}<span className="mt-1 block text-[11px] opacity-70">{m.from_staff ? "SolutionTee" : "Student"} · {when(m.at)}</span>
              </li>
            ))}
          </ul>
          <div>
            <Label htmlFor={`reply-${r.id}`}>Reply (in the app chat and by email)</Label>
            <textarea id={`reply-${r.id}`} rows={3} maxLength={2000} className={inputCls} value={reply} onChange={(e) => setReply(e.target.value)}
              placeholder="Hi! Thanks for asking. Here are our tutor plans…" />
          </div>
          <div className="flex flex-wrap items-end gap-3">
            <div><Label htmlFor={`tutor-${r.id}`}>Tutor</Label>
              <select id={`tutor-${r.id}`} className={inputCls} value={r.tutor_id ?? ""} disabled={pending}
                onChange={(e) => run(() => updateRequest(r.id, { tutor_id: e.target.value || null }))}>
                <option value="">Not assigned</option>
                {tutors.filter((t) => t.active || t.id === r.tutor_id).map((t) => <option key={t.id} value={t.id}>{t.name}{t.subjects ? ` (${t.subjects})` : ""}</option>)}
              </select></div>
            <div><Label htmlFor={`status-${r.id}`}>Status</Label>
              <select id={`status-${r.id}`} className={inputCls} value={r.status} disabled={pending} onChange={(e) => run(() => updateRequest(r.id, { status: e.target.value }))}>
                {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </select></div>
            <Button className="ml-auto" disabled={pending || !reply.trim()} onClick={() => run(() => replyTutor(r.id, reply), () => setReply(""))}>Send reply</Button>
          </div>
          {r.tutor_id && !r.plan_until ? <p className="text-xs text-muted-foreground">The tutor&apos;s contacts show to the student once they buy a plan.</p> : null}
        </div>
      ) : null}
    </li>
  );
}

function TutorForm({ t, onDone }: { t?: Tutor; onDone: () => void }) {
  const [f, setF] = useState({ name: t?.name ?? "", subjects: t?.subjects ?? "", bio: t?.bio ?? "", whatsapp: t?.whatsapp ?? "", phone: t?.phone ?? "", active: t?.active ?? true });
  const { pending, run } = useAct();
  const id = t?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => setF({ ...f, [k]: e.target.value });
  return (
    <div className="grid gap-3">
      <div className="grid gap-3 md:grid-cols-2">
        <div><Label htmlFor={`tn-${id}`}>Name</Label><input id={`tn-${id}`} className={inputCls} maxLength={80} value={f.name} onChange={set("name")} /></div>
        <div><Label htmlFor={`ts-${id}`}>Subjects</Label><input id={`ts-${id}`} className={inputCls} maxLength={200} value={f.subjects} onChange={set("subjects")} placeholder="Physics, Mathematics" /></div>
        <div><Label htmlFor={`tw-${id}`}>WhatsApp number</Label><input id={`tw-${id}`} className={inputCls} inputMode="tel" value={f.whatsapp} onChange={set("whatsapp")} placeholder="+2348012345678" /></div>
        <div><Label htmlFor={`tp-${id}`}>Phone number</Label><input id={`tp-${id}`} className={inputCls} inputMode="tel" value={f.phone} onChange={set("phone")} placeholder="08012345678" /></div>
      </div>
      <div><Label htmlFor={`tb-${id}`}>Short bio (students see it)</Label><textarea id={`tb-${id}`} rows={2} maxLength={600} className={inputCls} value={f.bio} onChange={set("bio")} /></div>
      <div className="flex flex-wrap items-center gap-3">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Taking new students</label>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button>
          <Button disabled={pending} onClick={() => run(() => saveTutor({ id: t?.id, ...f }), onDone)}>{t ? "Save" : "Add tutor"}</Button></div>
      </div>
    </div>
  );
}

function PlanForm({ p, onDone }: { p?: Plan; onDone: () => void }) {
  const [f, setF] = useState({ name: p?.name ?? "", description: p?.description ?? "", price_naira: p ? String(p.price_kobo / 100) : "", days: String(p?.days ?? 30),
    sessions: p?.sessions ? String(p.sessions) : "", sort: String(p?.sort ?? 0), active: p?.active ?? true });
  const { pending, run } = useAct();
  const id = p?.id ?? "new";
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => setF({ ...f, [k]: e.target.value });
  return (
    <div className="grid gap-3">
      <div className="grid gap-3 md:grid-cols-[2fr_1fr_1fr_1fr]">
        <div><Label htmlFor={`pn-${id}`}>Plan name</Label><input id={`pn-${id}`} className={inputCls} maxLength={80} value={f.name} onChange={set("name")} placeholder="Monthly: 8 lessons" /></div>
        <div><Label htmlFor={`pp-${id}`}>Price (₦)</Label><input id={`pp-${id}`} type="number" min={50} className={inputCls} value={f.price_naira} onChange={set("price_naira")} /></div>
        <div><Label htmlFor={`pd-${id}`}>Days</Label><input id={`pd-${id}`} type="number" min={1} max={366} className={inputCls} value={f.days} onChange={set("days")} /></div>
        <div><Label htmlFor={`ps-${id}`}>Lessons (optional)</Label><input id={`ps-${id}`} type="number" min={0} max={200} className={inputCls} value={f.sessions} onChange={set("sessions")} /></div>
      </div>
      <div><Label htmlFor={`pdesc-${id}`}>What is included</Label><textarea id={`pdesc-${id}`} rows={2} maxLength={400} className={inputCls} value={f.description} onChange={set("description")} /></div>
      <div className="flex flex-wrap items-center gap-3">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Shown in the app</label>
        <div className="flex items-center gap-2 text-sm"><Label htmlFor={`po-${id}`}>Order</Label><input id={`po-${id}`} type="number" min={0} className={cn(inputCls, "w-20")} value={f.sort} onChange={set("sort")} /></div>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button>
          <Button disabled={pending} onClick={() => run(() => savePlan({ id: p?.id, ...f }), onDone)}>{p ? "Save" : "Add plan"}</Button></div>
      </div>
    </div>
  );
}

export function TutorAdmin({ status, requests, tutors, plans }: { status: string; requests: TRequest[]; tutors: Tutor[]; plans: Plan[] }) {
  const [editT, setEditT] = useState<string | null>(null);
  const [editP, setEditP] = useState<string | null>(null);
  const { pending, run } = useAct();
  return (
    <div className="grid gap-4">
      <nav className="flex flex-wrap gap-2" aria-label="Filter requests">
        {FILTERS.map(([k, label]) => (
          <Link key={k} href={k === "open" ? "/admin/tutors" : `/admin/tutors?show=${k}`}
            className={cn("rounded-full border px-3 py-1.5 text-sm font-bold", status === k ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted")}>{label}</Link>
        ))}
      </nav>
      <Panel title={`Requests (${requests.length})`} bodyClassName="p-0">
        {requests.length ? <ul className="divide-y">{requests.map((r) => <RequestRow key={r.id} r={r} tutors={tutors} />)}</ul>
          : <EmptyState title="No requests here">When a student asks for a tutor in the app, the request shows here.</EmptyState>}
      </Panel>
      <Panel title={`Tutor plans (${plans.length})`} actions={<Button size="sm" onClick={() => setEditP("new")} disabled={editP === "new"}><Plus size={16} weight="bold" /> Add plan</Button>}>
        {editP === "new" ? <div className="mb-4 rounded-2xl border p-3"><PlanForm onDone={() => setEditP(null)} /></div> : null}
        {plans.length ? (
          <ul className="divide-y">
            {plans.map((p) => (
              <li key={p.id} className="py-3">
                {editP === p.id ? <PlanForm p={p} onDone={() => setEditP(null)} /> : (
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1"><p className="font-bold">{p.name} · {naira(p.price_kobo)}</p>
                      <p className="text-sm text-muted-foreground">{p.days} days{p.sessions ? ` · ${p.sessions} lessons` : ""}{p.description ? ` · ${p.description}` : ""}</p></div>
                    <Pill tone={p.active ? "ok" : "neutral"}>{p.active ? "Shown" : "Hidden"}</Pill>
                    <Button size="sm" variant="outline" onClick={() => setEditP(p.id)}>Edit</Button>
                    <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${p.name}?`)) run(() => deletePlan(p.id)); }}>Delete</Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        ) : editP !== "new" ? <EmptyState title="No tutor plans yet">Add your plans and prices. Students pay in the app with card, transfer, USSD or bank apps; buying again adds more days.</EmptyState> : null}
      </Panel>
      <Panel title={`Tutors (${tutors.length})`} actions={<Button size="sm" onClick={() => setEditT("new")} disabled={editT === "new"}><Plus size={16} weight="bold" /> Add tutor</Button>}>
        {editT === "new" ? <div className="mb-4 rounded-2xl border p-3"><TutorForm onDone={() => setEditT(null)} /></div> : null}
        {tutors.length ? (
          <ul className="divide-y">
            {tutors.map((t) => (
              <li key={t.id} className="py-3">
                {editT === t.id ? <TutorForm t={t} onDone={() => setEditT(null)} /> : (
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1"><p className="font-bold">{t.name}{t.subjects ? <span className="font-normal text-muted-foreground"> · {t.subjects}</span> : null}</p>
                      <p className="text-sm text-muted-foreground">{[t.whatsapp && `WhatsApp ${t.whatsapp}`, t.phone && `Phone ${t.phone}`].filter(Boolean).join(" · ") || "No contacts yet"}</p></div>
                    <Pill tone={t.active ? "ok" : "neutral"}>{t.active ? "Active" : "Not taking students"}</Pill>
                    <Button size="sm" variant="outline" onClick={() => setEditT(t.id)}>Edit</Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        ) : editT !== "new" ? <EmptyState title="No tutors yet">Add the tutors you work with. Students only see a tutor&apos;s WhatsApp and phone while their plan is active.</EmptyState> : null}
      </Panel>
    </div>
  );
}
