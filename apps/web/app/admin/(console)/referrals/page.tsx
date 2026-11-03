import { Suspense } from "react";
import type { Metadata } from "next";
import { Gift } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel, Pill, when } from "@/components/admin/ui";
import { RewardsList, RulesForm, type RewardRow } from "./ref-ui";
import type { RulesInput } from "./actions";

export const metadata: Metadata = { title: "Referrals" };

type Data = {
  settings: RulesInput;
  totals: { pending: number; counted: number; blocked: number; this_month: number };
  rewards: RewardRow[];
  top: { name: string | null; user_id: string; code: string | null; counted: number; pending: number; blocked: number }[];
  recent: { created_at: string; status: string; reason: string | null; referrer: string | null; friend: string | null; code: string | null }[];
};

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Referrals /></Suspense>;
}

async function Referrals() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_referrals");
  if (error) return <ErrorState message={error.message} />;
  const d = data as unknown as Data;
  const t = d.totals;
  return (
    <>
      <PageHeader title="Referrals" description="Students share their code. A friend counts only on their own phone, after the step you choose. Discounts are worked out by the server; cash rewards are paid by you after a check." />
      <div className="mb-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
        {[["Friends counted", t.counted], ["This month", t.this_month], ["Waiting", t.pending], ["Blocked", t.blocked]].map(([l, v]) => (
          <div key={String(l)} className="rounded-xl border bg-card p-3"><div className="text-xl font-bold tabular-nums">{v}</div><div className="text-xs text-muted-foreground">{l}</div></div>
        ))}
      </div>
      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="Rules"><RulesForm s={d.settings} /></Panel>
        <Panel title="Cash rewards" bodyClassName="p-0">
          {d.rewards.length ? <RewardsList rows={d.rewards} /> : <EmptyState icon={<Gift />} title="No cash rewards yet">When a student reaches the number of friends you set, the reward shows here.</EmptyState>}
        </Panel>
        <Panel title="Top referrers" bodyClassName="p-0">
          {d.top.length ? (
            <table className="w-full text-sm"><thead className="bg-surface-alt text-left text-xs text-muted-foreground"><tr><th className="px-3 py-2">Student</th><th>Code</th><th>Counted</th><th>Waiting</th><th className="pr-3">Blocked</th></tr></thead>
              <tbody>{d.top.map((r) => (
                <tr key={r.user_id} className="border-t"><td className="px-3 py-1.5">{r.name ?? "Student"}</td><td className="font-mono text-xs">{r.code}</td>
                  <td className="font-bold tabular-nums">{r.counted}</td><td className="tabular-nums">{r.pending}</td><td className={`pr-3 tabular-nums ${r.blocked ? "text-error" : ""}`}>{r.blocked}</td></tr>
              ))}</tbody></table>
          ) : <p className="p-4 text-sm text-muted-foreground">Nobody has invited a friend yet.</p>}
        </Panel>
        <Panel title="Latest friends" bodyClassName="p-0">
          {d.recent.length ? (
            <ul className="divide-y text-sm">{d.recent.map((r, i) => (
              <li key={i} className="flex flex-wrap items-center gap-2 px-4 py-2">
                <span><b>{r.friend ?? "A friend"}</b> <span className="text-muted-foreground">invited by</span> {r.referrer ?? "a student"}</span>
                <Pill tone={r.status === "counted" ? "ok" : r.status === "blocked" ? "error" : "neutral"}>{r.status === "counted" ? "Counted" : r.status === "blocked" ? "Blocked" : "Waiting"}</Pill>
                <span className="ml-auto text-xs text-muted-foreground">{when(r.created_at)}</span>
                {r.reason ? <span className="w-full text-xs text-muted-foreground">{r.reason}</span> : null}
              </li>
            ))}</ul>
          ) : <p className="p-4 text-sm text-muted-foreground">No friends yet.</p>}
        </Panel>
      </div>
    </>
  );
}
