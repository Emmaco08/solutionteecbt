"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { EmptyState, Pill, when } from "@/components/admin/ui";
import { clearStudent, runSafetyNow, saveSafety } from "./actions";

const LABELS: Record<string, string> = {
  shared_phone: "Shared phone", many_accounts: "3+ accounts on a phone", second_account: "Second account tried", phone_banned: "Phone blocked",
  fair_play: "Unfair test (risk 70+)", challenge_dq: "Challenge disqualified", referral_abuse: "Invite blocked", payment_abuse: "Refund after Premium",
  reports: "Comment hidden", ai_strike: "AI rule broken",
};
const DEFAULTS: Record<string, number> = { shared_phone: 20, many_accounts: 30, second_account: 15, phone_banned: 40, fair_play: 15, challenge_dq: 20, referral_abuse: 15, payment_abuse: 25, reports: 5, ai_strike: 10 };

export type SafetySettings = { on: boolean; alerts: boolean; warn: number; ban: number; points: Record<string, number> };
export type Row = { user_id: string; name: string; score: number; kinds: number; warned_at: string | null; banned_at: string | null; auto_banned: string | null; events: { kind: string; points: number; detail: string | null; at: string }[] };

export function SafetyForm({ initial }: { initial: SafetySettings }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({ ...initial, points: { ...DEFAULTS, ...initial.points } });
  const input = "h-9 w-20 rounded-lg border border-input bg-card px-2 text-right text-sm tabular-nums";
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) => start(async () => {
    const r = await fn();
    if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error ?? "Could not save");
  });
  return (
    <div className="space-y-4 text-sm">
      <label className="flex items-center justify-between gap-3"><span><b>Automatic warnings and bans</b><span className="block text-xs text-muted-foreground">Off: points are still counted so you can see them.</span></span><Switch checked={f.on} onCheckedChange={(on) => setF({ ...f, on })} aria-label="Automatic bans" /></label>
      <label className="flex items-center justify-between gap-3"><span><b>Daily admin alert email</b><span className="block text-xs text-muted-foreground">Bans, second accounts, stuck payments, payouts and appeals waiting.</span></span><Switch checked={f.alerts} onCheckedChange={(alerts) => setF({ ...f, alerts })} aria-label="Admin alerts" /></label>
      <div className="grid grid-cols-2 gap-3">
        <label className="space-y-1"><span className="text-muted-foreground">Warning at (points)</span><input type="number" min={1} className={`${input} w-full`} value={f.warn} onChange={(e) => setF({ ...f, warn: Number(e.target.value) })} /></label>
        <label className="space-y-1"><span className="text-muted-foreground">Ban at (points)</span><input type="number" min={2} className={`${input} w-full`} value={f.ban} onChange={(e) => setF({ ...f, ban: Number(e.target.value) })} /></label>
      </div>
      <div>
        <b>Points for each flag</b>
        <div className="mt-2 space-y-1.5">
          {Object.keys(DEFAULTS).map((k) => (
            <label key={k} className="flex items-center justify-between gap-3"><span>{LABELS[k]}</span>
              <input aria-label={`${LABELS[k]} points`} type="number" min={0} max={100} className={input} value={f.points[k] ?? 0} onChange={(e) => setF({ ...f, points: { ...f.points, [k]: Number(e.target.value) } })} /></label>
          ))}
        </div>
        <p className="mt-2 text-xs text-muted-foreground">New points apply to new flags. Staff can always clear a student&apos;s points.</p>
      </div>
      <div className="flex gap-2">
        <Button disabled={pending} onClick={() => act(() => saveSafety(f))}>Save</Button>
        <Button variant="outline" disabled={pending} onClick={() => act(runSafetyNow)}>Check now</Button>
      </div>
    </div>
  );
}

export function SafetyList({ rows, warn, ban }: { rows: Row[]; warn: number; ban: number }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  if (!rows.length) return <EmptyState title="No student has points">Press Check now to count the latest flags.</EmptyState>;
  return (
    <ul className="divide-y">
      {rows.map((r) => (
        <li key={r.user_id} className="p-4">
          <div className="flex flex-wrap items-center gap-2">
            <b className="mr-auto">{r.name}</b>
            <Pill tone={r.score >= ban ? "error" : r.score >= warn ? "warn" : "neutral"}>{r.score} points · {r.kinds} kind{r.kinds === 1 ? "" : "s"}</Pill>
            {r.warned_at ? <Pill tone="warn">Warned {when(r.warned_at)}</Pill> : null}
            {r.banned_at ? <Pill tone="error">{r.auto_banned ? "Auto-banned" : "Banned"}</Pill> : null}
            <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm(`Clear ${r.name}'s points? Do this when you checked and the student is fine.`)) start(async () => { const x = await clearStudent(r.user_id); if (x.ok) { toast.success(x.message); router.refresh(); } else toast.error(x.error); }); }}>Clear points</Button>
          </div>
          <ul className="mt-2 space-y-0.5 text-xs text-muted-foreground">
            {r.events.map((e, i) => <li key={i}><b className="text-foreground">+{e.points}</b> {LABELS[e.kind] ?? e.kind}{e.detail ? ` · ${e.detail}` : ""} · {when(e.at)}</li>)}
          </ul>
        </li>
      ))}
    </ul>
  );
}
