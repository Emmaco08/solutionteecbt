"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { reviewMock, saveLeaderboard } from "./actions";

export type LbSettings = { on: boolean; past_seasons: number[]; min_mocks: number; names: "first-initial" | "first" };
export type Held = { attempt_id: string; user_id: string; name: string | null; state: string | null; score: number; time_s: number; submitted_at: string; held: string; review: "ok" | "rejected" | null };

export function SettingsForm({ settings, seasonNow }: { settings: LbSettings; seasonNow: number }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const past = [seasonNow - 1, seasonNow - 2, seasonNow - 3];
  return (
    <form className="space-y-4" action={(f) => start(async () => {
      const r = await saveLeaderboard(f);
      if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
    })}>
      <label className="flex items-start gap-3 text-sm"><input type="checkbox" name="on" defaultChecked={settings.on} className="mt-1" />
        <span><b>Show the leaderboard to students</b><span className="block text-muted-foreground">Off: students see “Leaderboards are switched off”. Scores still count in the background.</span></span></label>
      <div className="space-y-1.5"><Label>Past JAMB years to show (their best student)</Label>
        <div className="flex flex-wrap gap-4">{past.map((y) => (
          <label key={y} className="flex items-center gap-2 text-sm"><input type="checkbox" name="past" value={y} defaultChecked={settings.past_seasons.includes(y)} /> JAMB {y}</label>
        ))}</div></div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="lbMin">Full mocks needed to appear</Label>
          <input id="lbMin" name="min_mocks" type="number" min={1} max={20} defaultValue={settings.min_mocks} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="lbNames">Names shown</Label>
          <select id="lbNames" name="names" defaultValue={settings.names} className={inputCls}>
            <option value="first-initial">First name + initial (Chiamaka O.)</option><option value="first">First name only (Chiamaka)</option>
          </select></div>
      </div>
      <p className="text-xs text-muted-foreground">Full names are never shown, because many students are under 18. Students can hide themselves in the app (Me → Settings). Staff accounts never appear.</p>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button></div>
    </form>
  );
}

const mins = (s: number) => `${Math.floor(s / 60)} min`;

export function HeldList({ rows }: { rows: Held[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const decide = (id: string, d: "ok" | "rejected") => start(async () => {
    const r = await reviewMock(id, d);
    if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
  });
  return (
    <ul className="divide-y">
      {rows.map((r) => (
        <li key={r.attempt_id} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><b>{r.name || "No name"}</b>{r.state ? <span className="text-muted-foreground">{r.state}</span> : null}
              {r.review === "ok" ? <Pill tone="ok">Counts</Pill> : r.review === "rejected" ? <Pill tone="error">Kept off</Pill> : <Pill tone="warn">Waiting</Pill>}</div>
            <span className="text-muted-foreground"><b className="tabular-nums text-foreground">{r.score}</b>/400 in {mins(r.time_s)} · {when(r.submitted_at)}</span>
            <span className="block text-xs text-muted-foreground">{r.held}</span>
          </div>
          <Button size="sm" variant="outline" disabled={pending || r.review === "ok"} onClick={() => decide(r.attempt_id, "ok")}>Let it count</Button>
          <Button size="sm" variant="ghost" disabled={pending || r.review === "rejected"} onClick={() => decide(r.attempt_id, "rejected")}>Keep off</Button>
        </li>
      ))}
    </ul>
  );
}
