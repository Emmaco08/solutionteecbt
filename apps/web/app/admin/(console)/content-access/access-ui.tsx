"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState } from "@/components/admin/ui";
import { saveDefaults, saveWelcome, saveYear } from "./actions";
import { KINDS, MODES, type AccessData, type Defaults, type Mode, type Rule, type Welcome } from "./shared";

const naira = (kobo: number) => "₦" + Math.round(kobo / 100).toLocaleString("en-NG");

/** One rule: the mode, then its numbers (videos + hours for "watch", price + "Premium pays too" for "pay"). */
function RuleEditor({ rule, onChange, defaultLabel }: { rule: Rule; onChange: (r: Rule) => void; defaultLabel?: string }) {
  const set = (p: Partial<Rule>) => onChange({ ...rule, ...p });
  return (
    <div className="flex flex-wrap items-end gap-3">
      <select className={`${inputCls} w-60`} value={rule.mode} onChange={(e) => set({ mode: e.target.value as Mode })}>
        {MODES.map((m) => <option key={m.id} value={m.id}>{m.id === "default" && defaultLabel ? defaultLabel : m.label}</option>)}
      </select>
      {rule.mode === "ads" ? (
        <>
          <label className="text-xs">Videos<input type="number" min={1} max={20} className={`${inputCls} mt-1 w-20`} value={rule.ads ?? 1} onChange={(e) => set({ ads: Number(e.target.value) })} /></label>
          <label className="text-xs">Open for hours (0 = for good)<input type="number" min={0} max={720} className={`${inputCls} mt-1 w-28`} value={rule.hours ?? 24} onChange={(e) => set({ hours: Number(e.target.value) })} /></label>
        </>
      ) : null}
      {rule.mode === "pay" ? (
        <>
          <label className="text-xs">Price ₦<input type="number" min={50} className={`${inputCls} mt-1 w-28`} value={rule.price_kobo ? rule.price_kobo / 100 : ""} onChange={(e) => set({ price_kobo: Math.round(Number(e.target.value) * 100) })} /></label>
          <label className="flex items-center gap-2 pb-2 text-xs"><input type="checkbox" className="size-4" checked={!!rule.premium_pays} onChange={(e) => set({ premium_pays: e.target.checked })} /> Premium students pay too</label>
        </>
      ) : null}
    </div>
  );
}

export function AccessBoard({ d }: { d: AccessData }) {
  const router = useRouter();
  const [pending, run] = useTransition();
  const [defs, setDefs] = useState<Defaults>({
    items: Object.fromEntries(KINDS.map((k) => [k.id, d.defaults?.items?.[k.id] ?? { mode: "default" }])),
    years: d.defaults?.years ?? { mode: "default" },
    limits: d.defaults?.limits ?? { year_per_day: 2, item_per_day: {} },
  });
  const [welcome, setWelcome] = useState<Welcome>({ on: false, hours: 24, ads_level: "low", extra_years: 2, ...(d.welcome ?? {}) });
  const adsYears = defs.years.ads_years ?? {};
  const setAdsYears = (exam: number, v: number[] | "all") =>
    setDefs((x) => ({ ...x, years: { ...x.years, ads_years: { ...(x.years.ads_years ?? {}), [String(exam)]: v } } }));
  const setLimit = (p: Partial<NonNullable<Defaults["limits"]>>) => setDefs((x) => ({ ...x, limits: { ...(x.limits ?? {}), ...p } }));
  const exams = d.exams ?? [];
  const [exam, setExam] = useState<number>(exams[0]?.id ?? 0);
  const yearsOf = (exams.find((e) => e.id === exam)?.years ?? []).slice().sort((a, b) => b - a);
  const [year, setYear] = useState<number>(yearsOf[0] ?? 0);
  const [yr, setYr] = useState<Rule>({ mode: "ads", ads: 1, hours: 1 });

  const save = () => run(async () => {
    const r = await saveDefaults(defs);
    if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
  });
  const saveY = (e: number, y: number, rule: Rule) => run(async () => {
    const r = await saveYear(e, y, rule);
    if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
  });

  return (
    <div className="space-y-8">
      <section className="space-y-4 rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Each kind of Study content</h2>
        {KINDS.map((k) => (
          <div key={k.id} className="flex flex-wrap items-center gap-4 border-t border-border pt-3">
            <span className="w-48 text-sm font-bold">{k.label}</span>
            <RuleEditor rule={defs.items[k.id]} onChange={(r) => setDefs((x) => ({ ...x, items: { ...x.items, [k.id]: r } }))} />
          </div>
        ))}
        <div className="flex flex-wrap items-center gap-4 border-t border-border pt-3">
          <span className="w-48 text-sm font-bold">Past-question years (CBT and study mode)</span>
          <RuleEditor rule={defs.years} defaultLabel="As in Free vs Premium (+ watch for 1 hour on Ads)" onChange={(r) => setDefs((x) => ({ ...x, years: r }))} />
        </div>
        <p className="text-xs text-muted-foreground">
          “Watch videos” uses rewarded video ads (Ads page: level not Off). Premium students always open “watch videos” items, and “pay” items too unless you tick “Premium students pay too”.
        </p>
        <Button onClick={save} disabled={pending}>{pending ? "Saving…" : "Save"}</Button>
      </section>

      <section className="space-y-4 rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">What free students can open by watching ads</h2>
        <p className="text-sm text-muted-foreground">
          Only the years you tick here can be opened by watching videos (a year with its own “watch videos” rule below also can). Every other locked
          year stays Premium. The pop-up after a test also offers only these years.
        </p>
        {exams.map((e) => {
          const v = adsYears[String(e.id)] ?? [];
          const all = v === "all";
          const list = all ? [] : (v as number[]);
          const ys = (e.years ?? []).slice().sort((a, b) => b - a);
          return (
            <div key={e.id} className="space-y-2 border-t border-border pt-3">
              <div className="flex flex-wrap items-center gap-3">
                <span className="w-20 font-bold">{e.code}</span>
                <label className="flex items-center gap-2 text-sm"><input type="radio" checked={!all && list.length === 0} onChange={() => setAdsYears(e.id, [])} /> None</label>
                <label className="flex items-center gap-2 text-sm"><input type="radio" checked={!all && list.length > 0} onChange={() => setAdsYears(e.id, ys.slice(-2))} /> Chosen years</label>
                <label className="flex items-center gap-2 text-sm"><input type="radio" checked={all} onChange={() => setAdsYears(e.id, "all")} /> All years</label>
              </div>
              {!all && list.length > 0 ? (
                <div className="flex flex-wrap gap-1.5">
                  {ys.map((y) => {
                    const on = list.includes(y);
                    return (
                      <button key={y} type="button" onClick={() => setAdsYears(e.id, on ? list.filter((x) => x !== y) : [...list, y])}
                        className={`rounded-lg border px-2.5 py-1 text-xs tabular-nums ${on ? "border-primary bg-info-soft font-bold" : "border-border hover:bg-sunken"}`}>{y}</button>
                    );
                  })}
                </div>
              ) : null}
            </div>
          );
        })}
        <div className="flex flex-wrap items-end gap-4 border-t border-border pt-3">
          <label className="text-sm">Years a student can open by watching, per day
            <input type="number" min={0} max={50} className={`${inputCls} mt-1 w-28`} value={defs.limits?.year_per_day ?? 2} onChange={(e) => setLimit({ year_per_day: Number(e.target.value) })} />
            <span className="block text-xs text-muted-foreground">0 = no limit</span>
          </label>
          {KINDS.map((k) => (
            <label key={k.id} className="text-sm">{k.label} per day
              <input type="number" min={0} max={50} className={`${inputCls} mt-1 w-24`} value={defs.limits?.item_per_day?.[k.id] ?? 0}
                onChange={(e) => setLimit({ item_per_day: { ...(defs.limits?.item_per_day ?? {}), [k.id]: Number(e.target.value) } })} />
            </label>
          ))}
        </div>
        <Button onClick={save} disabled={pending}>{pending ? "Saving…" : "Save"}</Button>
      </section>

      <section className="space-y-4 rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">First-day welcome</h2>
        <p className="text-sm text-muted-foreground">
          For the first hours after a student joins: a lighter ads level and a few more free years, so they enjoy the app first. Students are not told.
        </p>
        <div className="flex flex-wrap items-end gap-4">
          <label className="flex items-center gap-2 pb-2 text-sm"><input type="checkbox" className="size-4" checked={welcome.on} onChange={(e) => setWelcome({ ...welcome, on: e.target.checked })} /> On</label>
          <label className="text-sm">Hours after joining<input type="number" min={1} max={168} className={`${inputCls} mt-1 w-24`} value={welcome.hours} onChange={(e) => setWelcome({ ...welcome, hours: Number(e.target.value) })} /></label>
          <label className="text-sm">Ads level in that time
            <select className={`${inputCls} mt-1 w-40`} value={welcome.ads_level} onChange={(e) => setWelcome({ ...welcome, ads_level: e.target.value })}>
              {["off", "low", "medium", "high", "high_extra", "max", "ultra"].map((l) => <option key={l} value={l}>{l === "off" ? "No ads" : l.replace("_", " ")}</option>)}
            </select>
          </label>
          <label className="text-sm">Extra free years per exam<input type="number" min={0} max={20} className={`${inputCls} mt-1 w-24`} value={welcome.extra_years} onChange={(e) => setWelcome({ ...welcome, extra_years: Number(e.target.value) })} /></label>
          <Button disabled={pending} onClick={() => run(async () => { const r = await saveWelcome(welcome); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error); })}>Save welcome</Button>
        </div>
      </section>

      <section className="space-y-4 rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">A rule for one exam year</h2>
        <p className="text-sm text-muted-foreground">Overrides the rule above for that year, for every subject.</p>
        <div className="flex flex-wrap items-end gap-3">
          <select className={`${inputCls} w-32`} value={exam} onChange={(e) => { const id = Number(e.target.value); setExam(id); setYear((exams.find((x) => x.id === id)?.years ?? []).sort((a, b) => b - a)[0] ?? 0); }}>
            {exams.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
          </select>
          <select className={`${inputCls} w-28`} value={year} onChange={(e) => setYear(Number(e.target.value))}>
            {yearsOf.map((y) => <option key={y} value={y}>{y}</option>)}
          </select>
          <RuleEditor rule={yr} onChange={setYr} defaultLabel="Remove this year's rule" />
          <Button disabled={pending || !year} onClick={() => saveY(exam, year, yr)}>Save year</Button>
        </div>
        {d.years.length ? (
          <div className="space-y-2">
            {d.years.map((y) => (
              <div key={`${y.exam_id}-${y.year}`} className="flex flex-wrap items-center gap-3 rounded-xl bg-sunken px-3 py-2 text-sm">
                <span className="w-28 font-bold">{y.exam} {y.year}</span>
                <span className="flex-1">
                  {MODES.find((m) => m.id === y.access)?.label}
                  {y.access === "ads" ? ` · ${y.ad_count ?? 1} video(s) · ${y.ad_hours === 0 ? "for good" : `${y.ad_hours ?? 1} h`}` : ""}
                  {y.access === "pay" && y.price_kobo ? ` · ${naira(y.price_kobo)}${y.pay_premium ? " · Premium pays too" : ""}` : ""}
                </span>
                <Button size="sm" variant="ghost" disabled={pending} onClick={() => saveY(y.exam_id, y.year, { mode: "default" })}><Trash size={16} /> Remove</Button>
              </div>
            ))}
          </div>
        ) : <p className="text-sm text-muted-foreground">No year has its own rule.</p>}
      </section>

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Bought one by one</h2>
        {d.sales.length ? (
          <table className="mt-3 w-full text-sm">
            <thead><tr className="text-left text-muted-foreground"><th className="py-1">Item</th><th className="text-right">Sold</th><th className="text-right">Money</th></tr></thead>
            <tbody>
              {d.sales.map((s) => (
                <tr key={`${s.kind}-${s.ref}`} className="border-t border-border">
                  <td className="py-1">{s.kind === "year" ? `Year ${s.ref}` : <a className="underline" href={`/admin/study/${s.ref}`}>Study item</a>}</td>
                  <td className="text-right tabular-nums">{s.sold}</td><td className="text-right tabular-nums">{naira(s.kobo)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : <EmptyState title="Nothing bought one by one yet" />}
      </section>
    </div>
  );
}
