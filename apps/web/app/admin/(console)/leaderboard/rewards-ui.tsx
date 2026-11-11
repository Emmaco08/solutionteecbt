"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { saveLbRewards } from "./actions";

type Place = { xp: number; days: number };
export type LbRewards = { on: boolean; boards: { jamb: boolean; challenges: boolean }; week: Place[]; month: Place[] };
export type Winner = { board: string; period: string; label: string; rank: number; name: string; score: number; xp_given: number; days_given: number };

const fill = (a: Partial<Place>[] | undefined) => Array.from({ length: 10 }, (_, i) => ({ xp: Number(a?.[i]?.xp ?? 0), days: Number(a?.[i]?.days ?? 0) }));
export const normalise = (r: Partial<LbRewards> | undefined): LbRewards => ({
  on: r?.on === true, boards: { jamb: r?.boards?.jamb !== false, challenges: r?.boards?.challenges !== false }, week: fill(r?.week), month: fill(r?.month),
});

export function RewardsForm({ initial }: { initial: LbRewards }) {
  const router = useRouter();
  const [f, setF] = useState(initial);
  const [pending, start] = useTransition();
  const set = (period: "week" | "month", i: number, k: keyof Place, v: string) =>
    setF({ ...f, [period]: f[period].map((p, j) => (j === i ? { ...p, [k]: Number(v) || 0 } : p)) });
  const cell = "h-9 w-full rounded-lg border border-input bg-card px-2 text-sm tabular-nums";
  return (
    <div className="space-y-4 text-sm">
      <div className="flex flex-wrap items-center gap-5">
        <label className="flex items-center gap-2 font-bold"><Switch checked={f.on} onCheckedChange={(on) => setF({ ...f, on })} aria-label="Rewards on" /> Rewards {f.on ? "on" : "off"}</label>
        <label className="flex items-center gap-2"><input type="checkbox" checked={f.boards.jamb} onChange={(e) => setF({ ...f, boards: { ...f.boards, jamb: e.target.checked } })} /> JAMB board</label>
        <label className="flex items-center gap-2"><input type="checkbox" checked={f.boards.challenges} onChange={(e) => setF({ ...f, boards: { ...f.boards, challenges: e.target.checked } })} /> Challenges board</label>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[460px]">
          <thead><tr className="text-left text-xs text-muted-foreground"><th className="py-1">Place</th><th>Week XP</th><th>Week Premium days</th><th>Month XP</th><th>Month Premium days</th></tr></thead>
          <tbody>
            {f.week.map((_, i) => (
              <tr key={i}>
                <td className="py-1 pr-2 font-bold">#{i + 1}</td>
                <td className="pr-2"><input aria-label={`Week #${i + 1} XP`} type="number" min={0} className={cell} value={f.week[i].xp} onChange={(e) => set("week", i, "xp", e.target.value)} /></td>
                <td className="pr-2"><input aria-label={`Week #${i + 1} days`} type="number" min={0} max={90} className={cell} value={f.week[i].days} onChange={(e) => set("week", i, "days", e.target.value)} /></td>
                <td className="pr-2"><input aria-label={`Month #${i + 1} XP`} type="number" min={0} className={cell} value={f.month[i].xp} onChange={(e) => set("month", i, "xp", e.target.value)} /></td>
                <td><input aria-label={`Month #${i + 1} days`} type="number" min={0} max={90} className={cell} value={f.month[i].days} onChange={(e) => set("month", i, "days", e.target.value)} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground">Paid by the server two days after each week (Monday to Sunday) and month ends, so held mocks can be reviewed first. Each place is paid once and the winner gets a notification. Cash is not offered while cash prizes wait for approval.</p>
      <Button disabled={pending} onClick={() => start(async () => {
        const r = await saveLbRewards(f);
        if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
      })}>Save rewards</Button>
    </div>
  );
}

export function WinnersList({ rows }: { rows: Winner[] }) {
  if (!rows.length) return <p className="text-sm text-muted-foreground">No rewards paid yet.</p>;
  return (
    <ul className="divide-y text-sm">
      {rows.map((w) => (
        <li key={`${w.board}${w.period}${w.label}${w.rank}`} className="flex items-center gap-3 py-2">
          <span className="w-8 font-bold">#{w.rank}</span>
          <span className="min-w-0 flex-1 truncate"><b>{w.name}</b> <span className="text-muted-foreground">· {w.board === "jamb" ? "JAMB" : "Challenges"} · {w.label}</span></span>
          <span className="tabular-nums text-muted-foreground">{w.score} pts</span>
          <span className="tabular-nums">{w.xp_given} XP{w.days_given ? ` + ${w.days_given} days` : ""}</span>
        </li>
      ))}
    </ul>
  );
}
