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

export type LbSettings = {
  on: boolean; past_seasons: number[]; min_mocks: number; names: "first-initial" | "first";
  min_questions: number; fast_minutes: number; include_staff: boolean;
};
export type Recent = {
  attempt_id: string; name: string | null; state: string | null; score: number; questions: number; time_s: number;
  submitted_at: string; season: number; reason: string | null; held: boolean;
};

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
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="lbQ">Questions needed in a full mock</Label>
          <input id="lbQ" name="min_questions" type="number" min={4} max={400} defaultValue={settings.min_questions} className={inputCls} />
          <span className="text-xs text-muted-foreground">A real JAMB mock has 180.</span></div>
        <div className="space-y-1.5"><Label htmlFor="lbFast">Too fast: held if finished in under (minutes)</Label>
          <input id="lbFast" name="fast_minutes" type="number" min={0} max={120} defaultValue={settings.fast_minutes} className={inputCls} />
          <span className="text-xs text-muted-foreground">0 = no check. Held mocks wait for you below.</span></div>
        <div className="space-y-1.5"><Label htmlFor="lbMin">Full mocks needed to appear</Label>
          <input id="lbMin" name="min_mocks" type="number" min={1} max={20} defaultValue={settings.min_mocks} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="lbNames">Names shown</Label>
          <select id="lbNames" name="names" defaultValue={settings.names} className={inputCls}>
            <option value="first-initial">First name + initial (Chiamaka O.)</option><option value="first">First name only (Chiamaka)</option>
          </select></div>
      </div>
      <div className="space-y-1.5"><Label>Past JAMB years to show (their best student)</Label>
        <div className="flex flex-wrap gap-4">{past.map((y) => (
          <label key={y} className="flex items-center gap-2 text-sm"><input type="checkbox" name="past" value={y} defaultChecked={settings.past_seasons.includes(y)} /> JAMB {y}</label>
        ))}</div></div>
      <label className="flex items-start gap-3 text-sm"><input type="checkbox" name="include_staff" defaultChecked={settings.include_staff} className="mt-1" />
        <span><b>Include staff accounts (for testing)</b><span className="block text-muted-foreground">Lets your own admin account appear. Turn it off before launch.</span></span></label>
      <p className="text-xs text-muted-foreground">Full names are never shown, because many students are under 18. Students can hide themselves in the app (Me → Settings).</p>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button></div>
    </form>
  );
}

const mins = (s: number) => (s < 60 ? `${s} sec` : `${Math.round(s / 60)} min`);

export function RecentList({ rows }: { rows: Recent[] }) {
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
              {r.reason ? <Pill tone={r.held ? "warn" : "neutral"}>{r.held ? "Waiting for you" : "Does not count"}</Pill> : <Pill tone="ok">Counts</Pill>}</div>
            <span className="text-muted-foreground"><b className="tabular-nums text-foreground">{r.score}</b>/400 · {r.questions} questions · {mins(r.time_s)} · {when(r.submitted_at)}</span>
            {r.reason ? <span className="block text-xs text-muted-foreground">{r.reason}</span> : null}
          </div>
          {r.held ? (
            <>
              <Button size="sm" variant="outline" disabled={pending} onClick={() => decide(r.attempt_id, "ok")}>Let it count</Button>
              <Button size="sm" variant="ghost" disabled={pending} onClick={() => decide(r.attempt_id, "rejected")}>Keep off</Button>
            </>
          ) : null}
        </li>
      ))}
    </ul>
  );
}
