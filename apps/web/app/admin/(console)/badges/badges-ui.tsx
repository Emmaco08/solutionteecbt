"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { inputCls } from "@/components/admin/row-form";
import { Panel, Pill } from "@/components/admin/ui";
import { deleteBadge, saveBadge, setBadgeActive, setBadgesOn } from "./actions";
import { ICONS, LEVELS, METRICS, type Level } from "./meta";

type Reward = { xp?: number; days?: number };
export type Badge = { id: number; key: string; name: string; description: string; icon: string; metric: string; targets: Record<Level, number>; rewards: Partial<Record<Level, Reward>>; active: boolean; sort: number };

const COLORS: Record<Level, string> = { bronze: "#CD7F32", silver: "#9AA6B2", gold: "#F2B233", diamond: "#38BDF8" };
const cap = (s: string) => s[0].toUpperCase() + s.slice(1);

function Editor({ badge, nextSort, onDone }: { badge?: Badge; nextSort: number; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState(() => ({
    key: badge?.key ?? "", name: badge?.name ?? "", description: badge?.description ?? "", icon: badge?.icon ?? "medal", metric: badge?.metric ?? "tests",
    sort: String(badge?.sort ?? nextSort), active: badge?.active ?? true,
    targets: Object.fromEntries(LEVELS.map((l) => [l, String(badge?.targets?.[l] ?? "")])) as Record<Level, string>,
    xp: Object.fromEntries(LEVELS.map((l) => [l, String(badge?.rewards?.[l]?.xp ?? 0)])) as Record<Level, string>,
    days: Object.fromEntries(LEVELS.map((l) => [l, String(badge?.rewards?.[l]?.days ?? 0)])) as Record<Level, string>,
  }));
  const id = badge?.id ?? "new";
  const submit = () => start(async () => {
    const r = await saveBadge({
      id: badge?.id, key: f.key, name: f.name, description: f.description, icon: f.icon, metric: f.metric, sort: f.sort, active: f.active,
      targets: f.targets, rewards: Object.fromEntries(LEVELS.map((l) => [l, { xp: f.xp[l], days: f.days[l] }])),
    });
    if (!r.ok) return void toast.error(r.error);
    toast.success(r.message);
    onDone();
    router.refresh();
  });
  const cell = "h-9 w-full rounded-lg border border-input bg-card px-2 text-sm tabular-nums";
  return (
    <div className="grid gap-4">
      <div className="grid gap-3 md:grid-cols-[1fr_1fr_160px_90px]">
        <div><Label htmlFor={`n-${id}`}>Name</Label><input id={`n-${id}`} className={inputCls} value={f.name} maxLength={40} onChange={(e) => setF({ ...f, name: e.target.value })} /></div>
        <div><Label htmlFor={`k-${id}`}>Short code</Label><input id={`k-${id}`} className={inputCls} value={f.key} maxLength={40} disabled={Boolean(badge)} placeholder="night_owl" onChange={(e) => setF({ ...f, key: e.target.value })} /></div>
        <div><Label htmlFor={`i-${id}`}>Icon</Label><select id={`i-${id}`} className={inputCls} value={f.icon} onChange={(e) => setF({ ...f, icon: e.target.value })}>{ICONS.map((i) => <option key={i} value={i}>{i}</option>)}</select></div>
        <div><Label htmlFor={`s-${id}`}>Order</Label><input id={`s-${id}`} type="number" className={inputCls} value={f.sort} onChange={(e) => setF({ ...f, sort: e.target.value })} /></div>
      </div>
      <div className="grid gap-3 md:grid-cols-[1fr_280px]">
        <div><Label htmlFor={`d-${id}`}>How to win it</Label><input id={`d-${id}`} className={inputCls} value={f.description} maxLength={160} onChange={(e) => setF({ ...f, description: e.target.value })} /></div>
        <div><Label htmlFor={`m-${id}`}>What it counts</Label><select id={`m-${id}`} className={inputCls} value={f.metric} onChange={(e) => setF({ ...f, metric: e.target.value })}>{Object.entries(METRICS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select></div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] text-sm">
          <thead><tr className="text-left text-xs text-muted-foreground"><th className="py-1">Level</th><th>Needs</th><th>XP reward</th><th>Free Premium days</th></tr></thead>
          <tbody>
            {LEVELS.map((l) => (
              <tr key={l}>
                <td className="py-1 pr-3 font-bold" style={{ color: COLORS[l] }}>{cap(l)}</td>
                <td className="pr-2"><input aria-label={`${l} needs`} type="number" min={1} className={cell} value={f.targets[l]} onChange={(e) => setF({ ...f, targets: { ...f.targets, [l]: e.target.value } })} /></td>
                <td className="pr-2"><input aria-label={`${l} XP`} type="number" min={0} max={5000} className={cell} value={f.xp[l]} onChange={(e) => setF({ ...f, xp: { ...f.xp, [l]: e.target.value } })} /></td>
                <td><input aria-label={`${l} Premium days`} type="number" min={0} max={90} className={cell} value={f.days[l]} onChange={(e) => setF({ ...f, days: { ...f.days, [l]: e.target.value } })} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="mt-2 text-xs text-muted-foreground">Cash rewards for badges are not available while cash prizes wait for approval (D-110). XP is not limited by the daily XP cap for badges.</p>
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.active} onChange={(e) => setF({ ...f, active: e.target.checked })} /> Show in the app</label>
        <div className="ml-auto flex gap-2"><Button variant="ghost" onClick={onDone}>Cancel</Button><Button onClick={submit} disabled={pending}>{badge ? "Save" : "Add badge"}</Button></div>
      </div>
    </div>
  );
}

export function BadgeList({ badges, holders, on }: { badges: Badge[]; holders: Record<string, number>; on: boolean }) {
  const router = useRouter();
  const [editing, setEditing] = useState<number | "new" | null>(null);
  const [pending, start] = useTransition();
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) => start(async () => {
    const r = await fn();
    if (!r.ok) toast.error(r.error ?? "Could not save");
    else { toast.success(r.message ?? "Done"); router.refresh(); }
  });
  const nextSort = (badges.at(-1)?.sort ?? 0) + 10;
  return (
    <>
      <Panel className="mb-4">
        <div className="flex flex-wrap items-center gap-4">
          <label className="flex items-center gap-3 text-sm font-bold"><Switch checked={on} disabled={pending} onCheckedChange={(v) => act(() => setBadgesOn(v))} aria-label="Badges on" /> Badges {on ? "on" : "off"}</label>
          <span className="text-sm text-muted-foreground">{badges.filter((b) => b.active).length} of {badges.length} shown</span>
          <Button className="ml-auto" onClick={() => setEditing("new")} disabled={editing === "new"}><Plus size={18} weight="bold" /> Add badge</Button>
        </div>
      </Panel>
      {editing === "new" ? <Panel title="New badge" className="mb-4"><Editor nextSort={nextSort} onDone={() => setEditing(null)} /></Panel> : null}
      <Panel title="All badges" bodyClassName="p-0">
        <ul className="divide-y">
          {badges.map((b) => (
            <li key={b.id} className="p-4">
              {editing === b.id ? <Editor badge={b} nextSort={nextSort} onDone={() => setEditing(null)} /> : (
                <div className="flex flex-wrap items-start gap-3">
                  <div className={`min-w-0 flex-1 ${b.active ? "" : "opacity-50"}`}>
                    <p className="font-bold">{b.name} <span className="text-xs font-normal text-muted-foreground">· {b.icon} · {METRICS[b.metric] ?? b.metric}</span></p>
                    <p className="text-sm text-muted-foreground">{b.description}</p>
                    <div className="mt-2 flex flex-wrap gap-2 text-xs">
                      {LEVELS.map((l) => (
                        <span key={l} className="rounded-lg border px-2 py-1">
                          <b style={{ color: COLORS[l] }}>{cap(l)}</b> {b.targets[l]} · {b.rewards[l]?.xp ?? 0} XP{b.rewards[l]?.days ? ` + ${b.rewards[l]?.days} days` : ""} · <span className="text-muted-foreground">{holders[`${b.id}:${LEVELS.indexOf(l) + 1}`] ?? 0} students</span>
                        </span>
                      ))}
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    {!b.active ? <Pill>Paused</Pill> : null}
                    <Button size="sm" variant="outline" disabled={pending} onClick={() => setEditing(b.id)}>Edit</Button>
                    <Button size="sm" variant="outline" disabled={pending} onClick={() => act(() => setBadgeActive(b.id, !b.active))}>{b.active ? "Pause" : "Show"}</Button>
                    <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm(`Delete ${b.name}? Students lose its levels.`)) act(() => deleteBadge(b.id)); }}>Delete</Button>
                  </div>
                </div>
              )}
            </li>
          ))}
        </ul>
      </Panel>
    </>
  );
}
