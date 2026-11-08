import { Suspense } from "react";
import type { Metadata } from "next";
import { Trophy } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel, Pill, when } from "@/components/admin/ui";
import { ClaimsList, WallList, type ClaimRow, type WallRow } from "./winners-ui";

export const metadata: Metadata = { title: "Winners & payouts" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Winners /></Suspense>;
}

async function Winners() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [claims, wall, flag, minors] = await Promise.all([
    supabase.rpc("admin_prize_claims"),
    supabase.from("winners_wall").select("id, challenge_title, name, state, place, amount, receipt_path, note, published, created_at").order("created_at", { ascending: false }).limit(50),
    supabase.from("feature_flags").select("enabled").eq("key", "paystack_payouts").maybeSingle(),
    supabase.rpc("admin_minor_win_notices"),
  ]);
  type Notice = { kind: string; ref_id: string; amount: number; title: string | null; created_at: string; sent_at: string | null; error: string | null; has_guardian: boolean };
  const notices = ((minors.data ?? []) as unknown as Notice[]).slice(0, 30);
  const payouts = flag.data?.enabled === true; // D-090: off until the business is registered with Paystack
  if (claims.error) return <ErrorState message={claims.error.message} />;
  const rows = (claims.data ?? []) as unknown as ClaimRow[];
  return (
    <>
      <PageHeader title="Winners & payouts" description="Winners send their account details in the app within 7 days. Pay by bank transfer, then mark it paid here and post the receipt on the Winners wall (hide the account number and balance first). Never ask for a PIN, card or password." />
      {!payouts ? <p className="mb-4 rounded-xl border bg-card p-3 text-sm text-muted-foreground">Paying with Paystack (Check account → Send) is off. Turn on <b>paystack_payouts</b> in Flags &amp; settings after Paystack registers your business, transfer OTP is off and your balance is topped up (SETUP §18).</p> : null}
      <div className="grid gap-4 xl:grid-cols-[1.4fr_1fr]">
        <Panel title="Winners to pay" bodyClassName="p-0">
          {rows.length ? <ClaimsList rows={rows} payouts={payouts} /> : <EmptyState icon={<Trophy />} title="No winners yet">When a cash challenge closes, its winners show here.</EmptyState>}
        </Panel>
        <div className="space-y-4">
          <Panel title="Winners wall posts" bodyClassName="p-0"><WallList rows={(wall.data ?? []) as WallRow[]} /></Panel>
          {notices.length ? (
            <Panel title="Parents told (winners aged 13 to 17)" bodyClassName="p-0">
              <ul className="divide-y text-sm">
                {notices.map((n) => (
                  <li key={n.kind + n.ref_id} className="flex flex-wrap items-center gap-2 px-5 py-2.5">
                    <span className="min-w-0 flex-1 truncate">{n.title ?? n.kind} · ₦{n.amount.toLocaleString("en-NG")}</span>
                    {n.sent_at ? <Pill tone="ok">Emailed {when(n.sent_at)}</Pill> : !n.has_guardian ? <Pill tone="error">No parent email</Pill> : n.error ? <Pill tone="error">Failed: {n.error}</Pill> : <Pill tone="warn">Sending…</Pill>}
                  </li>
                ))}
              </ul>
              <p className="px-5 pb-3 text-xs text-muted-foreground">A teen&apos;s prize can only be claimed after their parent has been emailed. Wait 7 days for a reply before paying.</p>
            </Panel>
          ) : null}
        </div>
      </div>
    </>
  );
}
