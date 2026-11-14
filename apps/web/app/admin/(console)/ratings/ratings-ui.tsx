"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel } from "@/components/admin/ui";
import { loadRatings, saveEngagement, type EngagementSettings, type RatingsData } from "./actions";

const stars = (n: number) => "★★★★★".slice(0, n) + "☆☆☆☆☆".slice(0, 5 - n);

export function RatingsList({ initial }: { initial: RatingsData }) {
  const [d, setD] = useState(initial);
  const [filter, setFilter] = useState<number | null>(null);
  const [offset, setOffset] = useState(0);
  const [pending, start] = useTransition();
  const total = Math.max(1, Object.values(initial.by_stars ?? {}).reduce((a, b) => a + Number(b), 0));
  const go = (f: number | null, o: number) => start(async () => {
    const r = await loadRatings(f, o);
    if (!r.ok || !r.data) return void toast.error(r.ok ? "Could not load" : r.error);
    setD(r.data);
    setFilter(f);
    setOffset(o);
  });
  return (
    <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
      <Panel title="Stars">
        <div className="grid gap-2 p-1">
          {[5, 4, 3, 2, 1].map((s) => {
            const n = Number(initial.by_stars?.[String(s)] ?? 0);
            return (
              <button key={s} type="button" onClick={() => go(filter === s ? null : s, 0)}
                className={`grid grid-cols-[52px_1fr_44px] items-center gap-2 rounded-lg p-1 text-left text-sm ${filter === s ? "bg-muted" : ""}`}>
                <span className="font-bold text-amber-500">{s} ★</span>
                <span className="h-2.5 overflow-hidden rounded-full bg-muted"><span className="block h-full rounded-full bg-amber-400" style={{ width: `${(100 * n) / total}%` }} /></span>
                <span className="text-right tabular-nums text-muted-foreground">{n}</span>
              </button>
            );
          })}
          <p className="text-xs text-muted-foreground">Tap a row to see only those ratings.</p>
        </div>
      </Panel>
      <Panel title={filter ? `${filter}-star ratings` : "Latest ratings"}>
        {d.rows.length ? (
          <ul className="divide-y">
            {d.rows.map((r) => (
              <li key={r.id} className="grid gap-1 p-3">
                <div className="flex flex-wrap items-center gap-2 text-sm">
                  <span className="font-bold text-amber-500">{stars(r.stars)}</span>
                  <span className="font-bold">{r.name}</span>
                  <span className="text-xs text-muted-foreground">{r.email ?? ""}</span>
                  <span className="ml-auto text-xs text-muted-foreground">{new Date(r.at).toLocaleString("en-NG", { dateStyle: "medium", timeStyle: "short" })}{r.version ? ` · app ${r.version}` : ""}</span>
                </div>
                {r.comment ? <p className="whitespace-pre-line text-sm">{r.comment}</p> : <p className="text-xs text-muted-foreground">No comment.</p>}
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title="No ratings yet">The rating card shows in the app after a few days of use (settings below).</EmptyState>
        )}
        <div className="flex justify-end gap-2 p-2">
          <Button size="sm" variant="outline" disabled={pending || offset === 0} onClick={() => go(filter, Math.max(0, offset - 50))}>Newer</Button>
          <Button size="sm" variant="outline" disabled={pending || d.rows.length < 50} onClick={() => go(filter, offset + 50)}>Older</Button>
        </div>
      </Panel>
    </div>
  );
}

export function EngagementForm({ initial }: { initial: EngagementSettings }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState(initial);
  const num = <K extends keyof EngagementSettings>(sec: K, key: keyof EngagementSettings[K], label: string) => (
    <div>
      <Label htmlFor={`${sec}-${String(key)}`}>{label}</Label>
      <input id={`${sec}-${String(key)}`} type="number" className={inputCls} value={Number(f[sec][key])}
        onChange={(e) => setF({ ...f, [sec]: { ...f[sec], [key]: Number(e.target.value) } })} />
    </div>
  );
  const tick = <K extends keyof EngagementSettings>(sec: K, key: keyof EngagementSettings[K], label: string) => (
    <label className="flex items-center gap-2 text-sm font-bold">
      <input type="checkbox" checked={Boolean(f[sec][key])} onChange={(e) => setF({ ...f, [sec]: { ...f[sec], [key]: e.target.checked } })} /> {label}
    </label>
  );
  return (
    <div className="grid gap-5">
      <div className="grid gap-2">
        {tick("rating", "on", "Show our rating card (stars + comment)")}
        <div className="grid gap-3 md:grid-cols-3">
          {num("rating", "after_days", "First after this many days")}
          {num("rating", "after_opens", "…and this many app opens")}
          {num("rating", "every_days", "Then every (days)")}
        </div>
        <p className="text-xs text-muted-foreground">A student who taps &quot;Not now&quot; is asked again in 14 days.</p>
      </div>
      <div className="grid gap-2">
        {tick("review", "on", "Ask for a Play Store review at happy moments (a score of 60% or more, a game win)")}
        <div className="grid gap-3 md:grid-cols-2">
          {num("review", "after_days", "Not before this many days")}
          {num("review", "every_days", "At most every (days)")}
        </div>
        <p className="text-xs text-muted-foreground">Google decides whether its box really appears (it limits how often). It only works in the app installed from the Play Store, not the website APK.</p>
      </div>
      <div className="grid gap-2">
        {tick("nudges", "on", "Suggest features now and then")}
        <div className="flex flex-wrap gap-4">{tick("nudges", "games", "Game Zone")}{tick("nudges", "community", "Community")}{tick("nudges", "tutor", "Request a tutor")}</div>
        <div className="grid gap-3 md:grid-cols-2">
          {num("nudges", "after_days", "First after this many days")}
          {num("nudges", "every_days", "Then every (days)")}
        </div>
        <p className="text-xs text-muted-foreground">One suggestion at a time, never on top of the countdown, a badge or the daily XP; a feature the student opened in the last 7 days is skipped.</p>
      </div>
      <div className="flex justify-end">
        <Button disabled={pending} onClick={() => start(async () => {
          const r = await saveEngagement(f);
          if (!r.ok) return void toast.error(r.error);
          toast.success(r.message);
          router.refresh();
        })}>Save</Button>
      </div>
    </div>
  );
}
