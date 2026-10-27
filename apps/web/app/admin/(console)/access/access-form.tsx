"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Crown } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { RULES, type RuleDef } from "./rules";
import { saveAccessRules } from "./actions";

export function AccessForm({ free, premium }: { free: Record<string, unknown>; premium: Record<string, unknown> }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const groups = [...new Set(RULES.map((r) => r.group))];
  return (
    <form action={(f) => start(async () => { const r = await saveAccessRules(f); if (r.ok) { toast.success("Rules saved. Students get them on their next request."); router.refresh(); } else toast.error(r.error); })}>
      <div className="overflow-hidden rounded-2xl border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
            <tr><th className="px-5 py-3">Feature</th><th className="w-[200px] px-3 py-3">Free</th><th className="w-[200px] px-3 py-3"><span className="inline-flex items-center gap-1"><Crown size={13} weight="fill" className="text-gold" /> Premium</span></th></tr>
          </thead>
          <tbody>
            {groups.map((g) => (
              <Group key={g} label={g} rows={RULES.filter((r) => r.group === g)} free={free} premium={premium} />
            ))}
          </tbody>
        </table>
      </div>
      <div className="sticky bottom-4 mt-4 flex justify-end">
        <Button type="submit" disabled={pending} className="h-11 px-6 shadow-[var(--shadow-3)]">Save rules</Button>
      </div>
    </form>
  );
}

function Group({ label, rows, free, premium }: { label: string; rows: RuleDef[]; free: Record<string, unknown>; premium: Record<string, unknown> }) {
  return (
    <>
      <tr><td colSpan={3} className="bg-surface-alt px-5 pb-1.5 pt-4 text-[11px] font-bold uppercase tracking-[0.6px] text-subtle">{label}</td></tr>
      {rows.map((r) => (
        <tr key={r.key} className="border-t">
          <td className="px-5 py-3"><b>{r.label}</b>{r.help ? <p className="text-xs text-muted-foreground">{r.help}</p> : null}</td>
          <td className="px-3 py-3"><Cell tier="free" rule={r} value={free[r.key]} /></td>
          <td className="px-3 py-3"><Cell tier="premium" rule={r} value={premium[r.key]} /></td>
        </tr>
      ))}
    </>
  );
}

function Cell({ tier, rule, value }: { tier: string; rule: RuleDef; value: unknown }) {
  const name = `${tier}.${rule.key}`;
  const cls = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm";
  if (rule.kind === "bool") return <Switch name={name} defaultChecked={value === true} aria-label={`${rule.label} (${tier})`} />;
  if (rule.kind === "which")
    return <select name={name} defaultValue={value === "newest" ? "newest" : "oldest"} className={cls} aria-label={`${rule.label} (${tier})`}><option value="oldest">Oldest first</option><option value="newest">Newest first</option></select>;
  if (rule.kind === "count") return <input name={name} type="number" min={0} max={1000} defaultValue={Number(value ?? 0)} className={cls} aria-label={`${rule.label} (${tier})`} />;
  // years: a number or "all"
  return (
    <select name={name} defaultValue={value === "all" ? "all" : String(Number(value ?? 0))} className={cls} aria-label={`${rule.label} (${tier})`}>
      <option value="0">Locked (0)</option>
      {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => <option key={n} value={n}>{n} year{n === 1 ? "" : "s"}</option>)}
      {[15, 20, 30].map((n) => <option key={n} value={n}>{n} years</option>)}
      <option value="all">All</option>
    </select>
  );
}
