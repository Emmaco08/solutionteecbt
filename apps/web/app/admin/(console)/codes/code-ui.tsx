"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { DownloadSimple, Pause, Play, Shuffle, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { inputCls } from "@/components/admin/row-form";
import { Pill, naira } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { batchCodes, createCodes, pauseCodes } from "./actions";

export type CodeRow = {
  id: string; batch_id: string | null; codes: number; code: string; kind: "pct" | "amt" | "days"; value: number; plan_ids: number[];
  used: number; max_uses: number | null; new_only: boolean; starts_at: string; ends_at: string | null; paused: boolean; note: string | null;
  created_at: string; created_by: string | null;
};
type Plan = { id: number; name: string };

const ALPHA = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const rand = (n: number) => Array.from(crypto.getRandomValues(new Uint32Array(n)), (x) => ALPHA[x % ALPHA.length]).join("");
const valueText = (r: { kind: string; value: number }) => r.kind === "pct" ? `${r.value}% off` : r.kind === "amt" ? `${naira(r.value)} off` : `${r.value} free Premium days`;
const day = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "Africa/Lagos" }) : "No end date");

function Seg<T extends string>({ value, options, onChange, label }: { value: T; options: [T, string][]; onChange: (v: T) => void; label: string }) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex rounded-xl bg-sunken p-1">
      {options.map(([v, l]) => (
        <button key={v} type="button" role="radio" aria-checked={value === v} onClick={() => onChange(v)}
          className={cn("h-9 rounded-lg px-3 text-sm font-bold", value === v ? "bg-card shadow-[var(--shadow-1)]" : "text-muted-foreground")}>{l}</button>
      ))}
    </div>
  );
}

export function CodeForm({ plans }: { plans: Plan[] }) {
  const router = useRouter();
  const [kind, setKind] = useState<"pct" | "amt" | "days">("pct");
  const [style, setStyle] = useState<"shared" | "unique">("shared");
  const [picked, setPicked] = useState<number[]>(plans.map((p) => p.id));
  const [code, setCode] = useState("");
  const [made, setMade] = useState<string[] | null>(null);
  const [pending, start] = useTransition();

  return (
    <form className="space-y-4" action={(f) => start(async () => {
      f.set("kind", kind); f.set("style", style); f.set("plan_ids", picked.join(","));
      const r = await createCodes(f);
      if (r.ok) { toast.success(r.message ?? "Created"); setMade(r.data?.codes ?? []); setCode(""); router.refresh(); } else toast.error(r.error);
    })}>
      <div className="space-y-1.5"><Label>The code gives</Label>
        <Seg label="The code gives" value={kind} onChange={setKind} options={[["pct", "% off"], ["amt", "₦ off"], ["days", "Free Premium days"]]} /></div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="cVal">{kind === "pct" ? "Percentage off" : kind === "amt" ? "Naira off" : "Free days"}</Label>
          <input id="cVal" name="value" type="number" min={1} max={kind === "pct" ? 100 : kind === "days" ? 366 : 1_000_000} defaultValue={kind === "days" ? 7 : 20} key={kind} required className={inputCls} /></div>
        {kind !== "days" ? (
          <div className="space-y-1.5"><Label>Works on plans</Label>
            <div className="flex flex-wrap gap-2">{plans.map((p) => {
              const on = picked.includes(p.id);
              return <button key={p.id} type="button" aria-pressed={on} onClick={() => setPicked(on ? picked.filter((x) => x !== p.id) : [...picked, p.id])}
                className={cn("h-9 rounded-full border px-3 text-sm font-bold", on ? "border-primary bg-primary-soft text-foreground" : "text-muted-foreground")}>{p.name}</button>;
            })}</div>
            {!picked.length ? <span className="text-xs text-muted-foreground">None picked: works on every plan.</span> : null}
          </div>
        ) : null}
      </div>
      <div className="space-y-1.5"><Label>Code style</Label>
        <Seg label="Code style" value={style} onChange={setStyle} options={[["shared", "One shared code"], ["unique", "Unique codes (one per student)"]]} />
        <p className="text-xs text-muted-foreground">{style === "shared" ? "One code many students can use, for example a school or a WhatsApp group. Each student can use it once." : "A batch of codes that each work once. Download them as a CSV after creating."}</p>
      </div>
      {style === "shared" ? (
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-1.5"><Label htmlFor="cCode">Code</Label>
            <div className="flex gap-2">
              <input id="cCode" name="code" value={code} onChange={(e) => setCode(e.target.value.toUpperCase().replace(/[^A-Z0-9-]/g, ""))} maxLength={24} placeholder="e.g. LOYOLA20" required autoComplete="off" className={cn(inputCls, "font-mono uppercase")} />
              <Button type="button" variant="outline" size="icon" aria-label="Random code" onClick={() => setCode(rand(8))}><Shuffle size={18} /></Button>
            </div>
            <span className="text-xs text-muted-foreground">Letters, numbers and dashes, 4 to 24. Not case sensitive.</span></div>
          <div className="space-y-1.5"><Label htmlFor="cMax">Total uses allowed</Label><input id="cMax" name="max_uses" type="number" min={1} placeholder="No limit" className={inputCls} /></div>
          <input type="hidden" name="prefix" value="" /><input type="hidden" name="count" value="" />
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-1.5"><Label htmlFor="cPre">Prefix</Label><input id="cPre" name="prefix" defaultValue="STEE" maxLength={8} required className={cn(inputCls, "font-mono uppercase")} />
            <span className="text-xs text-muted-foreground">Codes look like STEE-7K3P-Q9XD.</span></div>
          <div className="space-y-1.5"><Label htmlFor="cCount">How many codes</Label><input id="cCount" name="count" type="number" min={1} max={1000} defaultValue={50} required className={inputCls} /></div>
          <input type="hidden" name="code" value="" /><input type="hidden" name="max_uses" value="" />
        </div>
      )}
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="cFrom">Starts</Label><input id="cFrom" name="starts" type="date" className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="cTo">Ends</Label><input id="cTo" name="ends" type="date" className={inputCls} /></div>
      </div>
      <label className="flex items-center justify-between gap-3 text-sm"><span>Only for students who have never paid</span><Switch name="new_only" /></label>
      <div className="space-y-1.5"><Label htmlFor="cNote">Note (only staff see it)</Label><input id="cNote" name="note" maxLength={200} placeholder="e.g. Loyola College partnership" className={inputCls} /></div>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Create</Button></div>
      {made?.length ? (
        <div className="rounded-xl bg-success-soft p-3 text-sm text-on-success-soft">
          <b>{made.length === 1 ? "Code created:" : `${made.length} codes created.`}</b> {made.length === 1 ? <span className="font-mono">{made[0]}</span> : null}
          {made.length > 1 ? <Button type="button" variant="outline" size="sm" className="ml-2" onClick={() => download(made.map((c) => ({ code: c, used: 0 })), "solutiontee-codes.csv")}><DownloadSimple size={16} /> Download CSV</Button> : null}
        </div>
      ) : null}
    </form>
  );
}

function download(rows: { code: string; used: number }[], name: string) {
  const csv = "code,used\n" + rows.map((r) => `${r.code},${r.used}`).join("\n") + "\n";
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
  a.download = name;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function CodeRows({ rows, plans }: { rows: CodeRow[]; plans: Plan[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const planNames = (ids: number[]) => (ids?.length ? ids.map((id) => plans.find((p) => p.id === id)?.name ?? "?").join(", ") : "All plans");
  const state = (r: CodeRow): [string, "ok" | "warn" | "neutral"] => {
    if (r.paused) return ["Paused", "warn"];
    if (r.ends_at && new Date(r.ends_at) < new Date()) return ["Ended", "neutral"];
    if (r.max_uses !== null && r.used >= r.max_uses) return ["Used up", "neutral"];
    if (new Date(r.starts_at) > new Date()) return ["Not started", "warn"];
    return ["Active", "ok"];
  };
  return (
    <ul className="divide-y">
      {rows.map((r) => {
        const [label, tone] = state(r);
        return (
          <li key={r.id} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2"><b className="font-mono">{r.code}</b><Pill tone={tone}>{label}</Pill>{r.new_only ? <Pill tone="info">New students</Pill> : null}</div>
              <span className="block text-muted-foreground">{valueText(r)}{r.kind !== "days" ? ` · ${planNames(r.plan_ids)}` : ""} · {r.used}{r.max_uses !== null ? ` of ${r.max_uses}` : ""} used{r.batch_id ? ` · ${r.codes} codes` : ""}</span>
              <span className="block text-xs text-muted-foreground">{day(r.starts_at)} to {day(r.ends_at)}{r.note ? ` · ${r.note}` : ""}</span>
            </div>
            <div className="flex gap-1">
              {r.batch_id ? (
                <Button variant="ghost" size="icon" aria-label="Download codes" disabled={pending} onClick={() => start(async () => {
                  const res = await batchCodes(r.batch_id!);
                  if (res.ok) download(res.data ?? [], `${r.code.split("-")[0]}-codes.csv`); else toast.error(res.error);
                })}><DownloadSimple size={18} /></Button>
              ) : null}
              <Button variant="ghost" size="icon" aria-label={r.paused ? "Turn on" : "Pause"} disabled={pending} onClick={() => start(async () => {
                const res = await pauseCodes(r.id, !r.paused);
                if (res.ok) { toast.success(res.message ?? "Saved"); router.refresh(); } else toast.error(res.error);
              })}>{r.paused ? <Play size={18} /> : <Pause size={18} />}</Button>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
