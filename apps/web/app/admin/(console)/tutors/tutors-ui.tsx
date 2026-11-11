"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import type { ActionResult } from "@/lib/result";
import { deletePlan, savePlan, saveTutor } from "./actions";

type Tutor = { id: string; name: string; subjects: string | null; bio: string | null; whatsapp: string | null; phone: string | null; active: boolean; user_id: string | null };
type Plan = { id: string; name: string; description: string | null; price_kobo: number; days: number; sessions: number | null; active: boolean; sort: number; play_product_id: string | null };

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
    sessions: p?.sessions ? String(p.sessions) : "", sort: String(p?.sort ?? 0), active: p?.active ?? true, play_product_id: p?.play_product_id ?? "" });
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
      <div><Label htmlFor={`pplay-${id}`}>Google Play product id (for the Play Store app)</Label><input id={`pplay-${id}`} className={inputCls} maxLength={100} value={f.play_product_id} onChange={set("play_product_id")} placeholder="tutor_monthly_8" /></div>
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

export function TutorAdmin({ tutors, plans }: { tutors: Tutor[]; plans: Plan[] }) {
  const [editT, setEditT] = useState<string | null>(null);
  const [editP, setEditP] = useState<string | null>(null);
  const { pending, run } = useAct();
  return (
    <div className="grid gap-4">
      <Panel title={`Tutor plans (${plans.length})`} actions={<Button size="sm" onClick={() => setEditP("new")} disabled={editP === "new"}><Plus size={16} weight="bold" /> Add plan</Button>}>
        {editP === "new" ? <div className="mb-4 rounded-2xl border p-3"><PlanForm onDone={() => setEditP(null)} /></div> : null}
        {plans.length ? (
          <ul className="divide-y">
            {plans.map((p) => (
              <li key={p.id} className="py-3">
                {editP === p.id ? <PlanForm p={p} onDone={() => setEditP(null)} /> : (
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1"><p className="font-bold">{p.name} · {naira(p.price_kobo)}</p>
                      <p className="text-sm text-muted-foreground">{p.days} days{p.sessions ? ` · ${p.sessions} lessons` : ""}{p.description ? ` · ${p.description}` : ""}</p>
                      <p className="text-xs text-muted-foreground">{p.play_product_id ? `Google Play: ${p.play_product_id}` : "No Google Play product yet: the Play app sends students to the website to pay"}</p></div>
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
                      <p className="text-sm text-muted-foreground">{t.user_id ? "Has a tutor login: can chat with students" : "No login yet: invite them in Staff with the Tutor role"}</p></div>
                    <Pill tone={t.active ? "ok" : "neutral"}>{t.active ? "Active" : "Not taking students"}</Pill>
                    <Button size="sm" variant="outline" onClick={() => setEditT(t.id)}>Edit</Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        ) : editT !== "new" ? <EmptyState title="No tutors yet">Invite each tutor in Staff with the Tutor role: their profile shows here and they can chat with the students you assign.</EmptyState> : null}
      </Panel>
    </div>
  );
}
