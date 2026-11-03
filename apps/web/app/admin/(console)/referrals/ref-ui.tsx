"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { markPaid, saveRules, type RulesInput } from "./actions";

export type RewardRow = {
  id: string; name: string | null; user_id: string; milestone: number; amount: number; status: string; bank: string | null;
  account_number: string | null; account_name: string | null; created_at: string; claimed_at: string | null; paid_at: string | null; phone_ok: boolean;
};

const naira = (n: number) => `₦${n.toLocaleString("en-NG")}`;

/** Rules with a live preview of what a student sees. */
export function RulesForm({ s }: { s: RulesInput }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [v, setV] = useState(s);
  const set = (k: keyof RulesInput) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setV({ ...v, [k]: e.target.type === "checkbox" ? (e.target as HTMLInputElement).checked : e.target.type === "number" ? Number(e.target.value) : e.target.value });
  const fullAt = v.pct_per_friend > 0 ? Math.ceil(Math.min(v.max_pct, 100) / v.pct_per_friend) : 0;
  return (
    <form className="space-y-4" action={(f) => start(async () => { const r = await saveRules(f); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error); })}>
      <label className="flex items-center gap-3 text-sm"><input type="checkbox" name="enabled" checked={v.enabled} onChange={set("enabled")} /> <b>Referrals are on</b></label>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="rPct">Discount per friend (%)</Label><input id="rPct" name="pct_per_friend" type="number" min={1} max={100} value={v.pct_per_friend} onChange={set("pct_per_friend")} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="rMax">Highest discount (%)</Label><input id="rMax" name="max_pct" type="number" min={0} max={100} value={v.max_pct} onChange={set("max_pct")} className={inputCls} /></div>
        <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="rOn">A friend counts when they</Label>
          <select id="rOn" name="count_on" value={v.count_on} onChange={set("count_on")} className={inputCls}>
            <option value="test">verify their email and finish one practice test on their own phone</option>
            <option value="premium">buy Premium (stricter, fewer fake accounts)</option>
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="rEvery">Cash reward every … friends (0 = no cash)</Label><input id="rEvery" name="cash_every" type="number" min={0} max={1000} value={v.cash_every} onChange={set("cash_every")} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="rCash">Cash amount (₦)</Label><input id="rCash" name="cash_naira" type="number" min={0} step={500} value={v.cash_naira} onChange={set("cash_naira")} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="rCap">Most friends that count per student per month</Label><input id="rCap" name="monthly_cap" type="number" min={1} max={1000} value={v.monthly_cap} onChange={set("monthly_cap")} className={inputCls} /></div>
      </div>
      <div className="rounded-xl bg-surface-alt p-3 text-sm">
        <b>What students see</b>
        <ul className="mt-1 list-disc space-y-0.5 pl-5 text-muted-foreground">
          <li>Each friend: {v.pct_per_friend}% off Premium (up to {Math.min(v.max_pct, 100)}%).{fullAt && Math.min(v.max_pct, 100) === 100 ? ` ${fullAt} friends = Premium free.` : ""}</li>
          <li>{v.cash_every > 0 && v.cash_naira > 0 ? `Every ${v.cash_every} friends in total: ${naira(v.cash_naira)} cash (paid by you after a check).` : "No cash rewards."}</li>
          <li>Up to {v.monthly_cap} friends count each month. Using a discount spends those friends; the cash count never resets.</li>
        </ul>
        {v.pct_per_friend * v.monthly_cap < Math.min(v.max_pct, 100) ? <p className="mt-1 text-xs text-warning">With this monthly limit, nobody can reach the highest discount in one month.</p> : null}
        <p className="mt-1 text-xs text-muted-foreground">Discounts work for Paystack payments (website and the direct APK). Google Play sets its own prices.</p>
      </div>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button></div>
    </form>
  );
}

export function RewardsList({ rows }: { rows: RewardRow[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <ul className="divide-y">{rows.map((r) => (
      <li key={r.id} className="space-y-1.5 p-4 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          <b>{r.name ?? "Student"}</b>
          <Pill tone={r.status === "claimed" ? "warn" : r.status === "paid" ? "ok" : r.status === "cancelled" ? "neutral" : "info"}>
            {r.status === "claimed" ? "Ready to pay" : r.status === "due" ? "Waiting for bank details" : r.status === "paid" ? "Paid" : "Cancelled"}</Pill>
          <span className="ml-auto font-bold tabular-nums">{naira(r.amount)}</span>
        </div>
        <p className="text-xs text-muted-foreground">{r.milestone} friends · earned {when(r.created_at)}{r.paid_at ? ` · paid ${when(r.paid_at)}` : ""}</p>
        {!r.phone_ok ? <p className="text-xs text-error">This student&apos;s phone was used by another account first. Check before paying.</p> : null}
        {r.status === "claimed" ? (
          <>
            <p className="rounded-lg bg-surface-alt p-2 text-xs">{r.bank} · <b className="tabular-nums">{r.account_number}</b> · {r.account_name}</p>
            <p className="text-xs text-muted-foreground">Check the account name matches the student before paying. Never ask for a PIN, card or password.</p>
            <form className="flex flex-wrap gap-2" action={(f) => {
              if (!confirm(`Mark ${naira(r.amount)} as paid to ${r.account_name}?`)) return;
              start(async () => { const x = await markPaid(r.id, String(f.get("note") ?? "")); if (x.ok) { toast.success(x.message ?? "Done"); router.refresh(); } else toast.error(x.error); });
            }}>
              <input name="note" maxLength={500} placeholder="Transfer reference (optional)" className={`${inputCls} flex-1`} />
              <Button type="submit" size="sm" disabled={pending}>Mark paid</Button>
            </form>
          </>
        ) : null}
      </li>
    ))}</ul>
  );
}
